import { ShieldedAccount } from "@zkfi-tech/account";
import config from "../../../fixtures/config.json";
import { Point } from "@zkfi-tech/babyjubjub";

const senderSeed = BigInt(config.senderAccount.seed);
const receiverSeed = BigInt(config.receiverAccount.seed);
const senderAccount = ShieldedAccount.generate(senderSeed);
const receiverAccount = ShieldedAccount.generate(receiverSeed);

const addressTreeDepth = Number(config.addressTreeDepth);
const commitmentTreeDepth = Number(config.commitmentTreeDepth);

const revokerPubKey = [
  BigInt(config.revokerPublicKey[0]),
  BigInt(config.revokerPublicKey[1]),
];
const encryptionPubKey = [
  BigInt(config.encryptionPublicKey[0]),
  BigInt(config.encryptionPublicKey[1]),
];

export const fixture = {
  senderAccount,
  receiverAccount,
  addressTreeDepth,
  commitmentTreeDepth,
  revokerPublicKey: Point.fromArray(revokerPubKey),
  encryptionPublicKey: Point.fromArray(encryptionPubKey),
};
