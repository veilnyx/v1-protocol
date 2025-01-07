import { parseEther, parseUnits, zeroAddress, size } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions } from "./fixture";
import { parse } from 'path';

const {
  assets: { weth, usdc, testnetWeth: aaveWeth, testnetUsdc },
  sender: { account: senderAccount },
} = fixture;

export const reqs = {
  deposit_aaveWeth_testnetUsdc: {
    type: TransactionType.DEPOSIT,
    assetIds: [aaveWeth, testnetUsdc],
    values: [parseEther("2"), parseUnits("2", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
  /**,
  deposit_pre_tx: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth, usdc],
    values: [parseEther("500"), parseUnits("10000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_2_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth],
    values: [parseEther("2")],
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
  deposit_5_testnet_usdt_crvusd: {
    type: TransactionType.DEPOSIT,
    assetIds: [testnetUsdt, testnetCrvUsd],
    values: [parseUnits("5", 6), parseUnits("5", 18)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_2_wantLPToken: {
    type: TransactionType.DEPOSIT,
    assetIds: [beefyWantToken],
    values: [parseEther("2")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_2_mooLPToken: {
    type: TransactionType.DEPOSIT,
    assetIds: [beefyMooToken],
    values: [parseEther("2")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_2_morphoVaultToken: {
    type: TransactionType.DEPOSIT,
    assetIds: [morphoVaultToken],
    values: [parseEther("2")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
    */
};

export const genTestDeposits = async (sdk: Core) => {
  console.log("depositing assets...");
  await generateTestTransactions(reqs, sdk);
};
