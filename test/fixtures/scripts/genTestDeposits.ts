import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions } from "./fixture";

const {
  assets: { weth, usdc, reentrantToken, testnetWeth },
  sender: { account: senderAccount },
} = fixture;

export const reqs = {
  /**
  deposit_pre_tx: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth, usdc],
    values: [parseEther("10000"), parseUnits("10000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1000_weth_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1000_weth_usdc_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth, usdc],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1000_reentrantToken_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [reentrantToken],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
      */
  deposit_2_testnet_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [testnetWeth],
    values: [parseEther("2")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }

};

export const genTestDeposits = async (sdk: Core) => {
  console.log("depositing asset:", testnetWeth);
  await generateTestTransactions(reqs, sdk);
};
