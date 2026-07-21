import { parseEther, zeroAddress } from "viem";
import { Core } from "@veilnyx-sdk/core";
import { TransactionType } from "@veilnyx-sdk/shared-types";
import { fixture, generateTestTransactions, mockNotes, PAYMASTER_ADDR_FIXTURE } from "./fixture";

const {
  assets: { weth, usdc, reentrantToken, testnetWeth },
  sender: { account: senderAccount, pubAddress: senderPubAddress },
} = fixture;

export const reqs = {
  withdraw_1_testnet_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [testnetWeth],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: senderPubAddress,
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
  /**
  withdraw_10_weth_with_usdc_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("10")],
    feeAssetId: usdc,
    to: senderPubAddress,
    viaBundler: true,
    paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
    revokerId: 0,
  },
  withdraw_500_reentrantToken_to_attacker_contract: {
    type: TransactionType.WITHDRAW,
    assetIds: [reentrantToken],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: "0x8F2FbdFDa8BE4Da8B9454aE9F0301150932AE4b5",
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  withdraw_10_weth_with_weth_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [weth],
    values: [parseEther("10")],
    feeAssetId: weth,
    to: senderPubAddress,
    viaBundler: true,
    paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
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
  await mockNotes("deposit_2_testnet_weth", sdk);
  await generateTestTransactions(reqs, sdk);
};
