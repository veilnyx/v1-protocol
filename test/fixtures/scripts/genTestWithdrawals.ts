import { parseEther, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
  assets: { weth, usdc },
  sender: { account: senderAccount, pubAddress: senderPubAddress },
} = fixture;

export const reqs = {
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
  withdraw_10_weth_with_weth_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("1")],
    feeAssetId: weth,
    to: senderPubAddress,
    viaBundler: true,
    paymaster:
      `0x${"03E98aE18908eBc2Fe82e646E4DFB628963383c1"}` as `0x${string}`,
    revokerId: 0,
  },
};

export const genTestWithdrawals = async (sdk: Core) => {
  console.log("sdk.root", sdk.commitmentTreeSource.root);
  await mockNotes("deposit_1000_weth_usdc_without_fee", sdk);
  console.log("sdk.root", sdk.commitmentTreeSource.root);
  await generateTestTransactions(reqs, sdk);
};
