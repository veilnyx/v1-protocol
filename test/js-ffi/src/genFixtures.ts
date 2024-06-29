import { readFileSync, writeFileSync } from "fs";
import {
  Hex,
  keccak256,
  parseEther,
  parseUnits,
  sliceHex,
  stringToBytes,
  toHex,
  zeroAddress,
} from "viem";
import { Fr } from "@zkfi-tech/babyjubjub";
import { ShieldedAccount } from "@zkfi-tech/account";
import {
  TransactionOptions,
  TransactionRequest,
  TransactionType,
} from "@zkfi-tech/shared-types";
import { Core } from "@zkfi-tech/core";
import { ZTransaction } from "@zkfi-tech/zk-prover";
import { Note } from "@zkfi-tech/transaction";
import { getSDKInstance } from "./helpers/sdk";
import { inspect } from "util";

const senderAccount = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("sender"))).val
);
const receiverAccount = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("receiver"))).val
);
const withdrawAddress = sliceHex(keccak256(stringToBytes("withdraw")), 0, 20);
const paymasterAddress = sliceHex(keccak256(stringToBytes("paymaster")), 0, 20);
console.log("Withdraw address:", withdrawAddress);
console.log("Paymaster address:", paymasterAddress);

const mockWethAssetId = 0x010001;
const mockUsdcAssetId = 0x010002;
const wethAssetId = 0x010003;

const dirFixtures = "../fixtures/ztx";

const depositReqs = {
  deposit_1000_weth_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [mockWethAssetId],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1000_weth_usdc_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [mockWethAssetId, mockUsdcAssetId],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1000_weth_usdc_with_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [mockWethAssetId, mockUsdcAssetId],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: true,
    paymaster: paymasterAddress,
    revokerId: 0,
  },
  deposit_1_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [mockWethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  deposit_1_original_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
};

const withdrawReqs = {
  /**
  withdraw_500_weth_without_fee_to_mock_attacker: {
    type: TransactionType.WITHDRAW,
    assetIds: [mockWethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: "0xbE5c5b64F8Fd981d7A896ECA561220062317Faa9",
    viaBundler: false,
    paymaster: zeroAddress,
  },
   withdraw_1_weth_with_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [mockWethAssetId],
    values: [parseEther("1")],
    feeAssetId: mockWethAssetId,
    to: withdrawAddress,
    viaBundler: true,
    paymaster: `0x${"F8Cde1763BE3fe82a0f8CDc9625985f56d4294b9"}` as `0x${string}`,
    revokerId: 0,
  },*/
  withdraw_500_weth_with_weth_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [mockWethAssetId],
    values: [parseEther("500")],
    feeAssetId: mockWethAssetId,
    to: withdrawAddress,
    viaBundler: true,
    paymaster: paymasterAddress,
    revokerId: 0,
  },
  withdraw_500_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [mockWethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: withdrawAddress,
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  }
};

const transferReqs = {
  transfer_500_weth_without_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [mockWethAssetId],
    values: [parseEther("200")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0,
  },
  transfer_500_weth_with_weth_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [mockWethAssetId],
    values: [parseEther("500")],
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: true,
    paymaster: paymasterAddress,
    feeAssetId: mockWethAssetId,
    revokerId: 0,
  },
  transfer_1_weth_without_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [mockWethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  },
};

const convertReqs = {
  swap_1e16_orig_weth_to_usdc: {
    type: TransactionType.CONVERT,
    assetIds: [wethAssetId],
    values: [parseEther("0.01")],
    feeAssetId: 0,
    to: "0xF8Cde1763BE3fe82a0f8CDc9625985f56d4294b9", // adaptor to which the ZkFi Convertor will call to execute swap
    revokerId: 0,
    viaBundler: false,
    paymaster: zeroAddress,
    payload:
      "0x000000000000000000000000000000000000000000000000000000000001000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // refund: pool address (address(0))
  }, swap_1e16_orig_weth_to_usdc_via_bundler: {
    type: TransactionType.CONVERT,
    assetIds: [wethAssetId],
    values: [parseEther("0.01")],
    to: "0xF8Cde1763BE3fe82a0f8CDc9625985f56d4294b9", // adaptor to which the ZkFi Convertor will call to execute swap
    revokerId: 0,
    feeAssetId: wethAssetId,
    viaBundler: true,
    paymaster: paymasterAddress,
    payload:
      "0x000000000000000000000000000000000000000000000000000000000001000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // refund: pool address (address(0))
  }
};

const createMockZTx = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  zkfi: Core
) => {
  const opts = {
    viaBundler: req.viaBundler,
    paymaster: req.paymaster,
    revokerId: req.revokerId,
  };
  const tx = await zkfi.createTransaction(req as any, opts);

  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);
  // console.log("rootAddr", zkfi.account.rootAddress);
  // console.log("ztx.root", ztx.addressTreeRoot.toString());

  const encoded = ztx.encode();
  writeFileSync(`${dirFixtures}/${name}.txt`, encoded);
};

async function mockNotes(depositName: string, zkfi: Core) {
  const encoded = readFileSync(
    `${dirFixtures}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  const revokerData = await zkfi.getRevokerData(0);
  const revokerPublicKey = revokerData.revokerPublicKey;

  const depositNotes = ztx.noteMemos.map((m: Hex) => {
    return Note.fromMemo(m, zkfi.account, revokerPublicKey);
  });

  depositNotes.forEach((n, i) => (n.leafIndex = i));
  // console.log("Note created:", inspect(depositNotes));;

  //@ts-ignore
  zkfi.notesSource.mockNotes(depositNotes[0].assetId, [depositNotes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(depositNotes[1].assetId, [depositNotes[1]]);
  //@ts-ignore
  depositNotes.forEach((n) => zkfi.commitmentTreeSource.insert(n.commitment));
}

async function main() {
  const zkfi = getSDKInstance();

  // Pre-deposit 1000 token of assets - 0x010001 and 0x010002
  const depositName = "deposit_1000_weth_usdc_without_fee";
  await createMockZTx(depositName, depositReqs[depositName], zkfi);
  await mockNotes(depositName, zkfi);

  // const reqs = {
  //   ...withdrawReqs,
  // };
  // for (const [name, req] of Object.entries(reqs)) {
  //   await createMockZTx(name, req as any, zkfi);
  // }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
