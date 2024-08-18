import { parseEther, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
  assets: { weth, usdc },
  sender: { account: senderAccount, pubAddress: senderPubAddress },
  receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
  transfer_500_weth_without_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [weth],
    values: [parseEther("200")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  transfer_500_weth_with_weth_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [weth],
    values: [parseEther("500")],
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: true,
    paymaster:
      `0x${"03E98aE18908eBc2Fe82e646E4DFB628963383c1"}` as `0x${string}`,
    feeAssetId: weth,
    revokerId: 0,
  },
};

export const genTestTransfers = async (sdk: Core) => {
  await mockNotes("deposit_pre_tx", sdk);
  await generateTestTransactions(reqs, sdk);
};
