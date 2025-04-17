import { readFileSync, writeFileSync } from "fs";
import path from "path";
import {
  bytesToBigInt,
  Hex,
  concatHex,
  padHex,
  hexToBytes,
  keccak256,
  parseEther,
  size,
  sliceHex,
  stringToHex,
  stringToBytes,
  encodeFunctionData, encodeAbiParameters, parseAbiParameters,
  bytesToHex,
  getAddress,
  toHex
} from "viem";
import {
  UserOperation,
  getPackedUserOperation
} from "permissionless";
import { ShieldedAccount } from "@zkfi-tech/account";
import { Fp, Point, poseidonDecrypt } from "@zkfi-tech/babyjubjub";
import { randomBigInt, randomBytes, randomHex } from "@zkfi-tech/utils";
import {
  TransactionOptions,
  TransactionRequest,
} from "@zkfi-tech/shared-types";
import { Core } from "@zkfi-tech/core";
import { ZTransaction, PreVerification, PreVerificationDetails } from "@zkfi-tech/zk-prover";
import { Note, SIZE_ENCRYPTED_DECRYPTION_KEY, SIZE_FULLY_ENCRYPTED_NOTE_DATA } from "@zkfi-tech/transaction";
import config from "../config.json";
import { register } from "module";

const senderSeed = BigInt(config.sender.seed);
const receiverSeed = BigInt(config.receiver.seed);
const senderAccount = ShieldedAccount.generate(senderSeed);
const receiverAccount = ShieldedAccount.generate(receiverSeed);
const senderPubAddress = config.sender.pubAddress;
const receiverPubAddress = config.receiver.pubAddress;
const addressTreeDepth = Number(config.addressTreeDepth);
const commitmentTreeDepth = Number(config.commitmentTreeDepth);
const commitmentTreeQueueSize = Number(config.commitmentTreeQueueSize);
const qmtBatchSize = Number(config.qmtBatchSize);
const assets = {
  weth: config.assets.weth,
  usdc: config.assets.usdc,
  reentrantToken: config.assets.reentrantToken,
  testnetWeth: config.assets.testnetWeth,
  testnetUsdc: config.assets.testnetUsdc,
  morphoVaultToken: config.assets.morphoVaultToken,
};

const revokerPublicKey = Point.fromArray([
  BigInt(config.revokerPublicKey[0]),
  BigInt(config.revokerPublicKey[1]),
]);
const encryptionPublicKey = Point.fromArray([
  BigInt(config.encryptionPublicKey[0]),
  BigInt(config.encryptionPublicKey[1]),
]);

export const dirFixtureData = path.resolve(__dirname, "../data");

// Makes fixed pre-deposit notes of value 100000 ether each
export const preDepositedNotes = Array.from({
  length: commitmentTreeQueueSize,
}).map((_, i) => {
  return new Note({
    assetId: 0x010001 + i,
    value: parseEther("100000"),
    rootAddress: senderAccount.rootAddress,
    revoker: revokerPublicKey,
    blinding: BigInt(0),
    leafIndex: i,
  });
});

export const fixture = {
  sender: { account: senderAccount, pubAddress: senderPubAddress },
  receiver: { account: receiverAccount, pubAddress: receiverPubAddress },
  addressTreeDepth,
  commitmentTreeDepth,
  commitmentTreeQueueSize,
  qmtBatchSize,
  revokerPublicKey,
  encryptionPublicKey,
  assets,
  zeroLeaf: config.zeroLeaf,
  leavesQueue1: config.leavesQueue1.map((leaf: string) => BigInt(leaf)),
  leavesQueue2: config.leavesQueue2.map((leaf: string) => BigInt(leaf)),
  leavesQueuePartial: config.leavesQueuePartial.map((leaf: string) =>
    BigInt(leaf)
  ),
  preDepositedNotesCommitments: config.preDepositedNotesCommitments.map(
    (commitment: string) => BigInt(commitment)
  ),
};

export const generateTestTransactions = async (
  reqs: Record<string, TransactionRequest & TransactionOptions>,
  sdk: Core
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestTransaction(name, req, sdk);
  }
};

export const generateTestTransaction = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  sdk: Core
) => {
  const opts = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
  };
  const tx = await sdk.createTransaction(req, opts);
  console.log("TX: ", tx);
  const signedTx = await sdk.signTransaction(tx);
  const ztx = await sdk.proveTransaction(signedTx);
  console.log("ZTX:", ztx);
  const encoded = ztx.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
};

export const generateTestTransactionsWithOutsourcedProofVerification = async (
  reqs: Record<string, TransactionRequest & TransactionOptions>,
  sdk: Core,
  nebraClient: any,
  transactCircuitId: `0x${string}`
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestTransactionWithOutsourcedProofVerification(name, req, sdk, nebraClient, transactCircuitId);
  }
};

export const generateTestTransactionWithOutsourcedProofVerification = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  sdk: Core,
  nebraClient: any,
  transactCircuitId: `0x${string}`
) => {
  const opts = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
    isPreVerified: true
  };
  const tx = await sdk.createTransaction(req, opts);
  console.log("TX: ", tx);
  const signedTx = await sdk.signTransaction(tx);
  const { provedTx, preVerification } = await sdk.proveTransactionAndOutsourceVerification(signedTx, nebraClient, transactCircuitId);

  console.log("ZTX:", provedTx);
  const encoded = provedTx.encode();
  console.log("ZTX Encoded:", encoded);
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);

  console.log("Pre-verification data:", preVerification);
  const encodedPreVerification = preVerification.encode();
  writeFileSync(`${dirFixtureData}/${name}_preVerificationEncodedStruct.txt`, encodedPreVerification);
};

export const generateTestAddressRegistrations = async (
  reqs: Record<string, {}>,
  sdk: Core
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestAddressRegistration(name, sdk);
  }
};

export const generateTestAddrRegWithOutsourceProofVerifications = async (
  reqs: Record<string, {}>,
  sdk: Core,
  nebraClient: any,
  registerCircuitId: `0x${string}`
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestAddrRegWithOutsourcedProofVerification(name, sdk, nebraClient, registerCircuitId);
  }
};

const generateTestAddressRegistration = async (
  name: string,
  sdk: Core
) => {
  const zaddrReg = await sdk.proveAddress("0x");
  const encoded = zaddrReg.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
};

const generateTestAddrRegWithOutsourcedProofVerification = async (
  name: string,
  sdk: Core,
  nebraClient: any,
  registerCircuitId: `0x${string}`
) => {
  const zaddrReg = await sdk.proveAddressAndOutsourceVerification("0x", nebraClient, registerCircuitId);
  console.log("zaddrReg obj returned after proof gen & submission to Nebra:", zaddrReg);
  console.log("Encoding to gen fixture");
  const encoded = zaddrReg.shieldedAddressRegistrationData.encode();
  writeFileSync(`${dirFixtureData}/${name}_proof_veri_outsourced.txt`, encoded);
};

export const splitToChunks = (data: Hex, chunkSize: number) => {
  const bytesSize = size(data);
  if (bytesSize % chunkSize !== 0) {
    throw new Error("Data size must be multiple of chunk size");
  }
  const numChunks = bytesSize / chunkSize;
  const chunks: Hex[] = [];
  for (let i = 0; i < numChunks; i++) {
    chunks.push(sliceHex(data, i * chunkSize, i * chunkSize + chunkSize));
  }

  return chunks;
};

export async function mockNotes(depositName: string, sdk: Core) {
  // const notes = preDepositedNotes;
  // const commitments = fixture.preDepositedNotesCommitments;

  // // Check for data integrity
  // if (notes.length !== commitments.length) {
  //   throw new Error(
  //     "Pre-deposited notes and commitments have different lengths"
  //   );
  // }
  // for (let i = 0; i < notes.length; i++) {
  //   if (notes[i].commitment !== commitments[i]) {
  //     throw new Error("Pre-deposited notes do not match commitments");
  //   }
  // }
  // for (let i = 0; i < notes.length; i++) {
  //   //@ts-ignore
  //   sdk.notesSource.mockNotes(notes[i].assetId, [notes[i]]);
  //   //@ts-ignore
  //   sdk.commitmentTreeSource.insert(commitments[i]);
  // }

  const encoded = readFileSync(
    `${dirFixtureData}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  // let notesMemo: Hex = stringToHex(ztx.notesMemo);
  const revokerData = await sdk.getRevokerData(0);
  const revokerPublicKey = revokerData.revokerPublicKey;
  // Parse encrypted data
  const [encryptedRefundDataKey, ...encryptedNotesKeys] = splitToChunks(
    ztx.keysMemo,
    SIZE_ENCRYPTED_DECRYPTION_KEY
  );

  // const encryptedNotesMemoChunks = splitToChunks(notesMemo, 32).map((v) =>
  //   hexToBigInt(v)
  // );
  // const encryptedKeySeed = encryptedNotesMemoChunks.slice(0, 3);
  // const encryptedRefundData = encryptedNotesMemoChunks.slice(3, 7);

  // // Decrypt refund data
  // const refundDataDecryptionKey = Point.generate(
  //   bytesToBigInt(senderAccount.decrypt(hexToBytes(encryptedRefundDataKey)))
  // );

  // const refundData = poseidonDecrypt(
  //   encryptedRefundData,
  //   refundDataDecryptionKey,
  //   BigInt(0),
  //   2
  // );

  // Decrypt notes
  // ignoring/slicing the first 3 (encrypted key seed) and 4 (encrypted refund data) chunks. The balance notesMemo are encrypted notes of (4 * 32) = 128 bytes each
  const encryptedNotesHex = sliceHex(ztx.notesMemo, 7 * 32);
  const encryptedNotes = splitToChunks(encryptedNotesHex, SIZE_FULLY_ENCRYPTED_NOTE_DATA); // 128 bytes = each note
  console.log("Encrypted notes length:", encryptedNotes.length);
  const notes = [];
  for (let i = 0; i < encryptedNotes.length; i++) {
    console.log("Encrypted note:", encryptedNotes[i]);
    const n = Note.decrypt(0, encryptedNotesKeys[i], encryptedNotes[i], {
      account: senderAccount,
      revoker: revokerPublicKey,
      leafIndex: i,
    });
    if (n) {
      notes.push(n);
    }
  }
  console.log("Fixture::Notes decrypted: ", notes);
  const z = Fp.from(BigInt(keccak256(stringToBytes("zero")))).val;
  for (let i = 0; i < notes.length; i++) {
    //@ts-ignore
    sdk.notesSource.mockNotes(notes[i].assetId, [notes[i]]);
    // @ts-ignore
    sdk.commitmentTreeSource.insert(notes[i].commitment);
  }
}

export const generatePackedUserOps = async (name: string, req: TransactionRequest & TransactionOptions, sdk: Core, isPreVerified: boolean, nebraClient, transactCircuitId) => {
  // Generating ztx
  const opts = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
    isPreVerified: isPreVerified
  };
  const tx = await sdk.createTransaction(req, opts);
  const signedTx = await sdk.signTransaction(tx);

  let ztx: ZTransaction;
  let preVerification: PreVerification;

  if (isPreVerified) {
    const { provedTx, preVerification: preVerification_ } = await sdk.proveTransactionAndOutsourceVerification(
      tx,
      nebraClient,
      transactCircuitId
    );
    ztx = provedTx;
    preVerification = preVerification_;
  } else {
    ztx = await sdk.proveTransaction(signedTx);

    // generating preVerificationDetails obj since required by Gateway contract
    const preVeriDetails: PreVerificationDetails = {
      isPreVerified: isPreVerified,
      circuitId: bytesToHex(randomBytes(32)),
      publicInputs: [BigInt(0), BigInt(0)],
      verifierAddr: bytesToHex(randomBytes(20)),
    };

    preVerification = new PreVerification(preVeriDetails);
  }

  console.log("ZTX:", ztx);
  const encodedZTx = ztx.encode();
  console.log("ZTX Encoded:", encodedZTx);
  writeFileSync(`${dirFixtureData}/${name}.txt`, encodedZTx);

  // Generating calldata
  const gatewayAbi = JSON.parse(readFileSync("out/Gateway.sol/Gateway.json", "utf-8")).abi;
  const calldata = encodeFunctionData({
    abi: gatewayAbi,
    functionName: "handleUserOp",
    args: [ztx.toSolidityInput(), preVerification]
  });

  const nonce = concatHex([
    padHex(randomHex(24), { size: 24 }),
    padHex("0x0", { size: 8 }),
  ]);

  // Generating user op
  const userOp: UserOperation<"v0.7"> = {
    sender: `0x${"575253F9690dB75D36Da99f56003aFd0Eb29Eead"}` as `0x${string}`, // make sure this matches the Gateway address from solidity test setup
    nonce: BigInt(nonce),
    factory: undefined,
    factoryData: "0x",
    callData: calldata,
    // callGasLimit: BigInt(25_00_000),
    callGasLimit: BigInt(25_000),
    verificationGasLimit: BigInt(75_000),
    preVerificationGas: BigInt(75_000),
    maxFeePerGas: BigInt(150_000_000),
    maxPriorityFeePerGas: BigInt(150_000_000),
    paymaster: `0x${"5925279112eBf453E534a22c261A6E83696AE1Bc"}` as `0x${string}`, // make sure this matches the Paymaster address from solidity test setup
    paymasterVerificationGasLimit: BigInt(25_000),
    paymasterPostOpGasLimit: BigInt(5),
    paymasterData: "0x",
    signature: "0x",
  };

  // Generating packed user op
  const packedUserOp = await getPackedUserOperation(userOp);
  console.log("Packed User Ops:", packedUserOp);

  // Encode Packed User Ops
  const solidityPackedUserOp = [
    { name: 'sender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'initCode', type: 'bytes' },
    { name: 'callData', type: 'bytes' },
    { name: 'accountGasLimits', type: 'bytes32' },
    { name: 'preVerificationGas', type: 'uint256' },
    { name: 'gasFees', type: 'bytes32' },
    { name: 'paymasterAndData', type: 'bytes' },
    { name: 'signature', type: 'bytes' }
  ] as const;

  // preparing PackedUserOps ABI
  const packedUserOpPropertiesArray = solidityPackedUserOp.map((t) => `${t.type} ${t.name}`);
  const packedUserOpPropertiesString = packedUserOpPropertiesArray.join(';');
  const packedUserOpAbi = parseAbiParameters([
    'PackedUserOperation userOp',
    `struct PackedUserOperation { ${packedUserOpPropertiesString} }`,
  ])

  // preparing PackedUserOps values
  const packedUserOpValues = [
    packedUserOp.sender,
    packedUserOp.nonce,
    packedUserOp.initCode,
    packedUserOp.callData,
    packedUserOp.accountGasLimits,
    packedUserOp.preVerificationGas,
    packedUserOp.gasFees,
    packedUserOp.paymasterAndData,
    packedUserOp.signature
  ]

  const packedUserOpValueObj: Record<string, any> = {};
  solidityPackedUserOp.forEach((t, i) => {
    packedUserOpValueObj[t.name] = packedUserOpValues[i];
  });

  console.log("Starting Encoding of Packed User Op");
  console.log("ABI: ", packedUserOpAbi);
  console.log("Packed User Op Values: ", packedUserOpValueObj);
  // @ts-ignore
  const encoded = encodeAbiParameters(packedUserOpAbi, [packedUserOpValueObj]);

  if (isPreVerified) {
    writeFileSync(`${dirFixtureData}/${name}_packed_userop_preVerified.txt`, encoded);
  } else {
    writeFileSync(`${dirFixtureData}/${name}_packed_userop.txt`, encoded);
  }
}
