import { readFileSync, writeFileSync } from "fs";
import path from "path";
import {
  bytesToBigInt,
  Hex,
  hexToBigInt,
  hexToBytes,
  keccak256,
  parseEther,
  size,
  sliceHex,
  stringToHex,
  stringToBytes,
} from "viem";
import { ShieldedAccount } from "@zkfi-tech/account";
import { Fp, Point, poseidonDecrypt } from "@zkfi-tech/babyjubjub";
import {
  TransactionOptions,
  TransactionRequest,
} from "@zkfi-tech/shared-types";
import { Core } from "@zkfi-tech/core";
import { ZTransaction } from "@zkfi-tech/zk-prover";
import { Note, SIZE_ENCRYPTED_DECRYPTION_KEY, SIZE_FULLY_ENCRYPTED_NOTE_DATA } from "@zkfi-tech/transaction";
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
const qmtBatchSize = Number(config.qmtBatchSize);
const assets = {
  weth: config.assets.weth,
  usdc: config.assets.usdc,
  reentrantToken: config.assets.reentrantToken,
  testnetWeth: config.assets.testnetWeth,
  testnetUsdc: config.assets.testnetUsdc
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
  const signedTx = await sdk.signTransaction(tx);
  const ztx = await sdk.proveTransaction(signedTx);
  console.log("ZTX:", ztx);
  const encoded = ztx.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
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

export const generateTestAddressRegistration = async (
  name: string,
  sdk: Core
) => {
  const zaddrReg = await sdk.proveAddress("0x");
  const encoded = zaddrReg.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
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
    //@ts-ignore
    sdk.commitmentTreeSource.insert(notes[i].commitment);
  }
}
