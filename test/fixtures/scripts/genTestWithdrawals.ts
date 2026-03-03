import { parseEther, zeroAddress } from "viem";
import { Core } from "@labyrinthac/core";
import { TransactionType } from "@labyrinthac/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
  assets: { weth, usdc, reentrantToken },
  sender: { account: senderAccount, pubAddress: senderPubAddress },
} = fixture;

export const reqs = {
  withdraw_500_reentrantToken_to_attacker_contract: {
    type: TransactionType.WITHDRAW,
    assetIds: [reentrantToken],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: "0x8F2FbdFDa8BE4Da8B9454aE9F0301150932AE4b5",
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
  /**,
  withdraw_10_weth_with_usdc_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("10")],
    feeAssetId: usdc,
    to: senderPubAddress,
    viaBundler: true,
    paymaster:
      `0x${"6e1913f0B4118052AFAc74407B0C532659e6B198"}` as `0x${string}`,
    revokerId: 0,
  },
  withdraw_10_weth_with_weth_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("10")],
    feeAssetId: weth,
    to: senderPubAddress,
    viaBundler: true,
    paymaster:
      `0xF3d8f3B185d1448BD3f3762b6cCF7F129bC21fDB` as `0x${string}`,
    revokerId: 0
  },
  withdraw_100_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("100")],
    feeAssetId: 0,
    to: senderPubAddress,
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  withdraw_500_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: senderPubAddress,
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  */
};

export const genTestWithdrawals = async (sdk: Core) => {
  await mockNotes("deposit_1000_reentrantToken_without_fee", sdk);
  await generateTestTransactions(reqs, sdk);
};
