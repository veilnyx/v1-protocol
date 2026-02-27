import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@labyrinthac/core";
import { TransactionType } from "@labyrinthac/shared-types";
import { fixture, generateTestTransactions, generateTestTxsWithOutsourcedProofVerification } from "./fixture";

const {
  assets: { weth, usdc, testnetWeth, testnetUsdc, morphoVaultToken },
  sender: { account: senderAccount },
} = fixture;

export const reqs = {
  deposit_aaveWeth_testnetUsdc: {
    type: TransactionType.DEPOSIT,
    assetIds: [testnetWeth, testnetUsdc],
    values: [parseEther("2"), parseUnits("10", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
  /**,
   *  deposit_2_testnet_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [testnetWeth],
    values: [parseEther("2")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
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
  deposit_weth_tx: {
    type: TransactionType.DEPOSIT,
    assetIds: [weth],
    values: [parseEther("100")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_weth_tx: {
   type: TransactionType.DEPOSIT,
   assetIds: [weth],
   values: [parseEther("100")],
   feeAssetId: 0,
   to: senderAccount.shieldedAddress.pack(),
   viaBundler: false,
   paymaster: zeroAddress,
   revokerId: 0,
 },
deposit_aaveWeth_testnetUsdc: {
  type: TransactionType.DEPOSIT,
  assetIds: [testnetWeth, testnetUsdc],
  values: [parseEther("2"), parseUnits("10", 6)],
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
}
  */
};

export const genTestDeposits = async (sdk: Core) => {
  console.log("depositing assets...");
  await generateTestTransactions(reqs, sdk);
};

export const genTestDepositsWithOutsourceProofVerification = async (sdk: Core, nebraClient: any) => {
  await generateTestTxsWithOutsourcedProofVerification(reqs, sdk, nebraClient);
}
