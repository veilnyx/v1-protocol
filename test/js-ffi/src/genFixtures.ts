import { readFileSync, writeFileSync } from "fs";
import {
  Hex,
  keccak256,
  parseEther,
  parseUnits,
  sliceHex,
  stringToBytes,
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

const senderAccount = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("sender"))).val
);
const receiverAccount = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("receiver"))).val
);
const withdrawAddress = sliceHex(keccak256(stringToBytes("withdraw")), 0, 20);
const paymasterAddress = sliceHex(keccak256(stringToBytes("paymaster")), 0, 20);

const wethAssetId = 0x010001;
const usdcAssetId = 0x010002;

const dirFixtures = "../fixtures/ztx";

const depositReqs = {
  deposit_1000_weth_usdc: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId, usdcAssetId],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  }
  /** deposit_1000_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  },
  deposit_1_weth: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  }
   */
};

const withdrawReqs = {
  withdraw_500_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: withdrawAddress,
    viaBundler: false,
    paymaster: zeroAddress,
  },
  withdraw_500_weth_with_weth_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: wethAssetId,
    to: withdrawAddress,
    viaBundler: true,
    paymaster: paymasterAddress,
  },
};

const transferReqs = {
  transfer_500_weth_without_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  },
  transfer_500_weth_with_weth_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: wethAssetId,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: true,
    paymaster: paymasterAddress,
  },
};

const convertReqs = {
  swap_1e16_weth_to_usdc: {
    type: TransactionType.CONVERT,
    assetIds: [wethAssetId],
    values: [parseEther("0.01")],
    feeAssetId: wethAssetId,
    to: "0x67aD37B223C2EA3357456b6160199b98D9478799",  // adaptor to which the ZkFi Convertor will call to execute swap
    viaBundler: false,
    paymaster: zeroAddress,
    payload:
      "0x000000000000000000000000000000000000000000000000000000000001000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // beneficiary: pool address (address(0))
  }, swap_1e16_weth_to_usdc_via_bundler: {
    type: TransactionType.CONVERT,
    assetIds: [wethAssetId],
    values: [parseEther("0.01")],
    feeAssetId: wethAssetId,
    to: "0x67aD37B223C2EA3357456b6160199b98D9478799",  // adaptor to which the ZkFi Convertor will call to execute swap
    viaBundler: true,
    paymaster: "0xE45c40643af3aa4146E1B1C95051c23f7439ed75", // paymaster address on Sepolia
    payload:
      "0x000000000000000000000000000000000000000000000000000000000001000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // beneficiary: pool address (address(0))
  }
};

const createMockZTx = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  zkfi: Core
) => {
  const opts = { viaBundler: req.viaBundler, paymaster: req.paymaster };
  const tx = await zkfi.createTransaction(req as any, opts);

  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);
  const encoded = ztx.encode();
  writeFileSync(`${dirFixtures}/${name}.txt`, encoded);
};

async function mockNotes(depositName: string, zkfi: Core) {
  const encoded = readFileSync(
    `${dirFixtures}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;

  const notes = ztx.outMemos.map((m: Hex) => Note.fromMemo(m, zkfi.account));
  notes.forEach((n, i) => (n.leafIndex = i));

  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[1].assetId, [notes[1]]);
  //@ts-ignore
  notes.forEach((n) => zkfi.treeSource.insert(n.commitment));
}

async function main() {
  const zkfi = getSDKInstance();
  // Pre-deposit 1000 token of assets - 0x010001 and 0x010002
  const depositName = "deposit_1000_weth_usdc";
  // const depositName = "deposit_1_weth";
  await createMockZTx(depositName, depositReqs[depositName], zkfi);
  await mockNotes(depositName, zkfi);
  const reqs = {
    ...withdrawReqs,
    ...transferReqs
   };
  for (const [name, req] of Object.entries(reqs)) {
    await createMockZTx(name, req as any, zkfi);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
