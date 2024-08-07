import { parseEther, parseUnits, zeroAddress } from "viem";
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
};

export const genTestWithdrawals = async (sdk: Core) => {
  await mockNotes("deposit_1000_weth_without_fee", sdk);
  await generateTestTransactions(reqs, sdk);
};
