import { readFileSync, writeFileSync } from "fs";
import {
  bytesToBigInt,
  Hex,
  hexToBigInt,
  hexToBytes,
  keccak256,
  size,
  sliceHex,
  stringToBytes,
} from "viem";
import { ShieldedAccount } from "@zkfi-tech/account";
import {
  Fp,
  Point,
  poseidonDecrypt,
  poseidonHash,
} from "@zkfi-tech/babyjubjub";
import {
  TransactionOptions,
  TransactionRequest,
} from "@zkfi-tech/shared-types";
import { Core } from "@zkfi-tech/core";
import { MerkleTreeState, ZTransaction } from "@zkfi-tech/zk-prover";
import { Note, SIZE_KEY_MEMO } from "@zkfi-tech/transaction";
import config from "../config.json";
import { getInitialTreeState } from "./genTreeUpdateData";
const path = require("path");

const senderSeed = BigInt(config.sender.seed);
const receiverSeed = BigInt(config.receiver.seed);
const senderAccount = ShieldedAccount.generate(senderSeed);
const receiverAccount = ShieldedAccount.generate(receiverSeed);
const senderPubAddress = config.sender.pubAddress;
const receiverPubAddress = config.receiver.pubAddress;
const addressTreeDepth = Number(config.addressTreeDepth);
const commitmentTreeDepth = Number(config.commitmentTreeDepth);
const assets = {
  weth: config.assets.weth,
  usdc: config.assets.usdc,
};

const revokerPubKey = [
  BigInt(config.revokerPublicKey[0]),
  BigInt(config.revokerPublicKey[1]),
];
const encryptionPubKey = [
  BigInt(config.encryptionPublicKey[0]),
  BigInt(config.encryptionPublicKey[1]),
];

export const fixture = {
  sender: { account: senderAccount, pubAddress: senderPubAddress },
  receiver: { account: receiverAccount, pubAddress: receiverPubAddress },
  addressTreeDepth,
  commitmentTreeDepth,
  revokerPublicKey: Point.fromArray(revokerPubKey),
  encryptionPublicKey: Point.fromArray(encryptionPubKey),
  assets,
  leavesQueue: config.leavesQueue.map((leaf: string) => BigInt(leaf)),
};

const dirFixtureData = path.resolve(__dirname, "../data");

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
  console.log("Inside generateTestAddressRegistration()");
  const zaddrReg = await sdk.proveAddress("0x");
  const encoded = zaddrReg.encode();
  writeFileSync(`${dirFixtureData}/${name}.txt`, encoded);
};

export const generateTestTreeUpdates = async (sdk: Core) => {
  let initialTreeState = getInitialTreeState();
  const subtreeUpdateData = await sdk.prover.proveSubtreeUpdate({
    lastTree: initialTreeState,
    leaves: fixture.leavesQueue,
  });
  const encoded = subtreeUpdateData.encode();
  writeFileSync(`${dirFixtureData}/subtree_update_data.txt`, encoded);
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
  const encoded = readFileSync(
    `${dirFixtureData}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  const revokerData = await sdk.getRevokerData(0);
  const revokerPublicKey = revokerData.revokerPublicKey;

  // Parse encrypted data
  const [encryptedRefundDataKey, ...encryptedNotesKeys] = splitToChunks(
    ztx.keysMemo,
    SIZE_KEY_MEMO
  );

  const encryptedNoteMemoChunks = splitToChunks(ztx.notesMemo, 32).map((v) =>
    hexToBigInt(v)
  );
  const encryptedKeySeed = encryptedNoteMemoChunks.slice(0, 3);
  const encryptedNotesDataArr = encryptedNoteMemoChunks.slice(3);
  const numNotesData = encryptedNotesDataArr.length / 4;
  const encryptedNotesData: bigint[][] = [];
  for (let i = 0; i < numNotesData; i++) {
    const start = i * 4;
    const end = start + 4;
    encryptedNotesData.push(encryptedNotesDataArr.slice(start, end));
  }
  const [encryptedRefundData, ...encryptedNotes] = encryptedNotesData;

  // Decrypt refund data
  const refundDataDecryptionKey = Point.generate(
    bytesToBigInt(senderAccount.decrypt(hexToBytes(encryptedRefundDataKey)))
  );
  const refundData = poseidonDecrypt(
    encryptedRefundData,
    refundDataDecryptionKey,
    BigInt(0),
    2
  );

  // Decrypt notes
  const notes = [];
  for (let i = 0; i < encryptedNotes.length; i++) {
    const n = Note.decrypt(encryptedNotesKeys[i], encryptedNotes[i], {
      account: senderAccount,
      revoker: revokerPublicKey,
      leafIndex: 1,
    });

    if (n) {
      notes.push(n);
    }
  }

  const z = Fp.from(BigInt(keccak256(stringToBytes("zero")))).val;

  //@ts-ignore
  sdk.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  //@ts-ignore
  sdk.commitmentTreeSource.insert(z);
  //@ts-ignore
  sdk.commitmentTreeSource.insert(notes[0].commitment);

  //@ts-ignore
  // sdk.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  // //@ts-ignore
  // // sdk.notesSource.mockNotes(depositNotes[1].assetId, [depositNotes[1]]);
  // //@ts-ignore
  // notes.forEach((n) => sdk.commitmentTreeSource.insert(n.commitment));
}
