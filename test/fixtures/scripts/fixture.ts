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
  getPackedUserOperation,
} from "permissionless";
import { ShieldedAccount } from "@veilnyx-sdk/account";
import { Point, poseidonDecrypt, PointType } from "@veilnyx-sdk/babyjubjub";
import { randomBigInt, randomBytes, randomHex } from "@veilnyx-sdk/utils";
import {
  TransactionOptions,
  TransactionRequest,
} from "@veilnyx-sdk/shared-types";
import { Core, quoteUserOpGasCost } from "@veilnyx-sdk/core";
import { ZTransaction } from "@veilnyx-sdk/zk-prover";
import { Note, SIZE_ENCRYPTED_DECRYPTION_KEY, SIZE_FULLY_ENCRYPTED_NOTE_DATA } from "@veilnyx-sdk/transaction";
import config from "../config.json";

const senderSeed = BigInt(config.sender.seed);
const receiverSeed = BigInt(config.receiver.seed);
const senderAccount = ShieldedAccount.generate(senderSeed);
const receiverAccount = ShieldedAccount.generate(receiverSeed);
const senderPubAddress = config.sender.pubAddress;
const receiverPubAddress = config.receiver.pubAddress;
const addressTreeDepth = Number(config.addressTreeDepth);
const commitmentTreeDepth = Number(config.commitmentTreeDepth);
const commitmentTreeQueueSize = Number(config.commitmentTreeQueueSize);
const qmtQueueSize = Number(config.qmtQueueSize);

export const USER_OP_CALL_GAS_LIMIT = BigInt(9_00_000);
export const USER_OP_VERIFICATION_GAS_LIMIT = BigInt(75_000);
export const USER_OP_PRE_VERIFICATION_GAS = BigInt(75_000);
export const USER_OP_MAX_FEE_PER_GAS = BigInt(43484312091);
export const USER_OP_MAX_PRIORITY_FEE_PER_GAS = BigInt(1155000000);
export const USER_OP_PAYMASTER_VERIFICATION_GAS = BigInt(50_000);
export const PAYMASTER_ADDR_FIXTURE = config.paymaster;
export const GATEWAY_ADDR_FIXTURE = config.gateway;

// Dedicated deterministic account used ONLY for shielded address registration.
//
// The register proof binds the registrant's public address as a public input, so it must
// equal the address the Pool recovers from the EIP-712 registration signature
// (see ShieldedAddressLogic.register). That means it has to be a real EOA with a known
// private key -- `config.sender.pubAddress` cannot serve here, as it is derived from the
// shielded rootAddress (a Poseidon output) and has no secp256k1 key. It is also already
// load-bearing as the withdrawal recipient, so it is left untouched.
//
// `config.registrant` is the single source of truth: Solidity reads the same entry via
// FixtureLib so the signer and the proof's public input can never drift apart.
// Key is keccak256("veilnyx.fixture.registrant"); test-only, never used outside fixtures.
export const REGISTER_SIGNER_ADDRESS = getAddress(config.registrant.address);

const assets = {
  weth: config.assets.weth,
  usdc: config.assets.usdc,
  reentrantToken: config.assets.reentrantToken,
  testnetWeth: config.assets.testnetWeth,
  testnetUsdc: config.assets.testnetUsdc,
  morphoVaultToken: config.assets.morphoVaultToken
};

const revokerPublicKey = Point.fromAffine({
  x: BigInt(config.revokerPublicKey[0]),
  y: BigInt(config.revokerPublicKey[1]),
}) as PointType;
const encryptionPublicKey = Point.fromAffine({
  x: BigInt(config.encryptionPublicKey[0]),
  y: BigInt(config.encryptionPublicKey[1]),
}) as PointType;

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
  qmtQueueSize,
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
    userOpFeeQuoteEth: parseEther("0.00025")
  };
  const tx = await sdk.createTransaction(req, opts);
  // console.log("TX: ", tx);

  const signedTx = await sdk.signTransaction(tx);

  const ztx = await sdk.proveTransaction(signedTx);
  console.log("ZTX:", ztx);

  const encoded = ztx.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
};

export const generateTestTxsWithOutsourcedProofVerification = async (
  reqs: Record<string, TransactionRequest & TransactionOptions>,
  sdk: Core,
  nebraClient: any
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestTransactionWithOutsourcedProofVerification(name, req, sdk, nebraClient);
  }
};

export const generateTestTransactionWithOutsourcedProofVerification = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  sdk: Core,
  nebraClient: any
) => {
  const opts = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
    userOpFeeQuoteEth: parseEther("0.00025")
  };
  const tx = await sdk.createTransaction(req, opts);
  // console.log("TX: ", tx);
  const signedTx = await sdk.signTransaction(tx);
  const { ztx: preVerifiedTx, preVerification, nebraProofSubmissionObj } = await sdk.proveOutsourcedVerificationTx(signedTx, nebraClient);

  console.log("ZTX:", preVerifiedTx);
  const encoded = preVerifiedTx.encode();
  console.log("ZTX Encoded");
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);

  // const encodedPreVerification = preVerification.encode();
  // writeFileSync(`${dirFixtureData}/${name}_preVerificationEncodedStruct.txt`, encodedPreVerification);
};

export const generateTestAddressRegistrations = async (
  reqs: Record<string, {}>,
  sdk: Core,
  publicAddress: Hex = REGISTER_SIGNER_ADDRESS
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestAddressRegistration(name, sdk, publicAddress);
  }
};

export const generateTestAddrRegWithOutsourceProofVerifications = async (
  reqs: Record<string, {}>,
  sdk: Core,
  nebraClient: any,
  publicAddress: Hex = REGISTER_SIGNER_ADDRESS
) => {
  const reqArr = Object.entries(reqs);
  for (const [name, req] of reqArr) {
    await generateTestAddrRegWithOutsourcedProofVerification(name, sdk, nebraClient, publicAddress);
  }
};

const generateTestAddressRegistration = async (
  name: string,
  sdk: Core,
  publicAddress: Hex
) => {
  // signature will be generated inside the protocol test setup `_getRegisterAddressSignature` function, so passing dummy data here.
  // `publicAddress` however is a public input of the proof and must match the signer the Pool recovers.
  const zaddrReg = await sdk.proveAddress("0x", publicAddress);
  const encoded = zaddrReg.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
};

const generateTestAddrRegWithOutsourcedProofVerification = async (
  name: string,
  sdk: Core,
  nebraClient: any,
  publicAddress: Hex
) => {
  const zaddrReg = await sdk.proveAddressAndOutsourceVerification("0x", nebraClient, publicAddress);
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
  const revokerPublicKey: PointType = revokerData.revokerPublicKey;
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
      console.log("Note Nullifier: ", n.getNullifier(senderAccount.viewer));
      notes.push(n);
    }
  }
  console.log("Fixture::Notes decrypted: ", notes);

  for (let i = 0; i < notes.length; i++) {
    //@ts-ignore
    sdk.notesSource.mockNotes(notes[i].assetId, [notes[i]]);
    // @ts-ignore
    sdk.commitmentTreeSource.insert(notes[i].commitment);
  }
  console.log("commit tree root after Mock Notes", sdk.commitmentTreeSource.root);
}

// Like mockNotes but:
//  1. Assigns leafIndex starting at `leafIndexOffset` (so the note's Merkle path is correct)
//  2. Appends to existing notes per assetId rather than replacing them
// Use this when mocking notes from a second (or later) deposit batch so that notes from
// earlier batches are not evicted from MockNotesSource.
export async function mockNotesWithOffset(depositName: string, sdk: Core, leafIndexOffset: number) {
  const encoded = readFileSync(
    `${dirFixtureData}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  const revokerData = await sdk.getRevokerData(0);
  const revokerPublicKey: PointType = revokerData.revokerPublicKey;

  const [, ...encryptedNotesKeys] = splitToChunks(
    ztx.keysMemo,
    SIZE_ENCRYPTED_DECRYPTION_KEY
  );
  const encryptedNotesHex = sliceHex(ztx.notesMemo, 7 * 32);
  const encryptedNotes = splitToChunks(encryptedNotesHex, SIZE_FULLY_ENCRYPTED_NOTE_DATA);
  console.log("Encrypted notes length:", encryptedNotes.length);

  for (let i = 0; i < encryptedNotes.length; i++) {
    const n = Note.decrypt(0, encryptedNotesKeys[i], encryptedNotes[i], {
      account: senderAccount,
      revoker: revokerPublicKey,
      leafIndex: leafIndexOffset + i,
    });
    if (n) {
      console.log("Note Nullifier: ", n.getNullifier(senderAccount.viewer));
      // @ts-ignore
      const existing = (await sdk.notesSource.getUnspent(n.assetId)) ?? [];
      // @ts-ignore
      sdk.notesSource.mockNotes(n.assetId, [...existing, n]);
      // @ts-ignore
      sdk.commitmentTreeSource.insert(n.commitment);
    }
  }
  console.log("commit tree root after mockNotesWithOffset", sdk.commitmentTreeSource.root);
}

export const generatePackedUserOps = async (name: string, req: TransactionRequest & TransactionOptions, sdk: Core, isPreVerified: boolean, nebraClient: any) => {
  return generatePackedUserOpsWithFeeQuote(name, req, sdk, isPreVerified, nebraClient, {
    baseFeePerGas: BigInt(0),
  });
}

type UserOpFeeQuoteOverrides = {
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
  baseFeePerGas: bigint;
  headroomBps?: number;
};

export const generatePackedUserOpsWithFeeQuote = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  sdk: Core,
  isPreVerified: boolean,
  nebraClient: any,
  feeQuote: UserOpFeeQuoteOverrides,
) => {

  const nonce = concatHex([
    padHex(randomHex(24), { size: 24 }),
    padHex("0x0", { size: 8 }),
  ]);

  // Generating user op
  const userOp: UserOperation<"v0.7"> = {
    sender: GATEWAY_ADDR_FIXTURE as `0x${string}`, // make sure this matches the Gateway address from solidity test setup
    nonce: BigInt(nonce),
    factory: undefined,
    factoryData: "0x",
    callData: "0x", // this will be replaced with the calldata generated below
    callGasLimit: USER_OP_CALL_GAS_LIMIT, // 30 M gas is block gas limit = 30_000_000 gas
    verificationGasLimit: USER_OP_VERIFICATION_GAS_LIMIT,
    preVerificationGas: USER_OP_PRE_VERIFICATION_GAS,
    maxFeePerGas: feeQuote.maxFeePerGas ?? USER_OP_MAX_FEE_PER_GAS,
    maxPriorityFeePerGas: feeQuote.maxPriorityFeePerGas ?? USER_OP_MAX_PRIORITY_FEE_PER_GAS,
    paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`, // make sure this matches the Paymaster address from solidity test setup
    paymasterVerificationGasLimit: USER_OP_PAYMASTER_VERIFICATION_GAS,
    paymasterPostOpGasLimit: BigInt(5),
    paymasterData: "0x",
    signature: "0x",
  };

  const requiredGas =
    userOp.callGasLimit +
    userOp.verificationGasLimit +
    userOp.preVerificationGas +
    (userOp.paymasterVerificationGasLimit ?? BigInt(0)) +
    (userOp.paymasterPostOpGasLimit ?? BigInt(0));
  const maxCost = requiredGas * userOp.maxFeePerGas;
  const userOpFeeQuoteEth = quoteUserOpGasCost({
    maxCost,
    maxFeePerGas: userOp.maxFeePerGas,
    maxPriorityFeePerGas: userOp.maxPriorityFeePerGas,
    baseFeePerGas: feeQuote.baseFeePerGas,
    headroomBps: feeQuote.headroomBps,
  });

  // Generating ztx (preparing userop calldata)
  const opts: TransactionOptions = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
    userOpFeeQuoteEth
  };

  const tx = await sdk.createTransaction(req, opts);
  console.log("TX: ", tx);
  const signedTx = await sdk.signTransaction(tx);

  let ztx: ZTransaction = await sdk.proveTransaction(signedTx);

  console.log("ZTX:", ztx);
  const encodedZTx = ztx.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encodedZTx);
  console.log("ZTX fixture created");

  // const encodedPreVerification = preVerification.encode();
  // writeFileSync(`${dirFixtureData}/${name}_preVerificationEncodedStruct.txt`, encodedPreVerification);

  // Generating & Updating calldata in UserOp
  const gatewayAbi = JSON.parse(readFileSync("artifacts/src/core/Gateway.sol/Gateway.json", "utf-8")).abi;
  userOp.callData = encodeFunctionData({
    abi: gatewayAbi,
    functionName: "handleUserOp",
    args: [ztx.toSolidityInput()]
  });

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
  console.log("Packed User Op Values: ", packedUserOpValueObj);
  // @ts-ignore
  const encoded = encodeAbiParameters(packedUserOpAbi, [packedUserOpValueObj]);

  if (isPreVerified) {
    writeFileSync(`${dirFixtureData}/${name}_packed_userop_preVerified.txt`, encoded);
  } else {
    writeFileSync(`${dirFixtureData}/${name}_packed_userop.txt`, encoded);
  }
}
