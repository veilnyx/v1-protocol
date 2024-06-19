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
import { getReceiverSDKInstance, getSDKInstance } from "./helpers/sdk";
import { inspect } from 'util';

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
  /**
  deposit_1000_weth_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  },
  deposit_1000_weth_usdc_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId, usdcAssetId],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  },
  deposit_1000_weth_usdc_with_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId, usdcAssetId],
    values: [parseEther("1000"), parseUnits("1000", 6)],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: true,
    paymaster: paymasterAddress,
  },
   */
  deposit_1_weth_without_fee: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  }
};

const withdrawReqs = {
  /**
  withdraw_500_weth_without_fee_to_mock_attacker: {
    type: TransactionType.WITHDRAW,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: "0xbE5c5b64F8Fd981d7A896ECA561220062317Faa9",
    viaBundler: false,
    paymaster: zeroAddress,
  },
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
  }, */
  withdraw_1_weth_without_fee: {
    type: TransactionType.WITHDRAW,
    assetIds: [wethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: withdrawAddress,
    viaBundler: false,
    paymaster: zeroAddress,
  }
};

const transferReqs = {
  /**
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
  */
  transfer_1_weth_without_fee: {
    type: TransactionType.TRANSFER,
    assetIds: [wethAssetId],
    values: [parseEther("1")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
  }
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

let depositNotes;
async function mockDepositNotes(depositName: string, zkfi: Core) {
  const encoded = readFileSync(
    `${dirFixtures}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;

  depositNotes = ztx.outMemos.map((m: Hex) => {
    return Note.fromMemo(m, zkfi.account)
  });
  console.log(`OUT Notes created for ${depositName}: ${depositNotes}`);
  depositNotes.forEach((n, i) => (n.leafIndex = i));

  //@ts-ignore
  zkfi.notesSource.mockNotes(depositNotes[0].assetId, [depositNotes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(depositNotes[1].assetId, [depositNotes[1]]);
  //@ts-ignore
  depositNotes.forEach((n) => zkfi.treeSource.insert(n.commitment));
}

async function mockTransferNotes(transferName: string, senderZkFi: Core, receiverZkFi: Core) {

  // let calculatedleafIndex = receiverZkFi.treeSource.indexOf(depositNotes[depositNotes.length - 1].commitment);

  const encoded = readFileSync(
    `${dirFixtures}/${transferName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;

  {
  const receiverOutMemo = ztx.outMemos[0];
  let receiverNote = Note.fromMemo(receiverOutMemo, receiverZkFi.account);

  // @ts-ignore
  receiverNote.leafIndex = 2;
  // @ts-ignore
  receiverZkFi.notesSource.mockNotes(receiverNote.assetId, [receiverNote]);
  // @ts-ignore
  senderZkFi.notesSource.mockNotes(receiverNote.assetId, [receiverNote]);

  // adding receiver note to treeSource
  //@ts-ignore
  receiverZkFi.treeSource.insert(receiverNote.commitment);
  console.log("receiver note added to tree source");
  }

  // Sender Note
  {
  const senderOutMemo = ztx.outMemos[1];
  console.log("sender out memo:", senderOutMemo);

  let senderNote = Note.fromMemo(senderOutMemo, senderZkFi.account);
  console.log("Second transfer Note:", inspect(senderNote));
  // @ts-ignore
  senderNote.leafIndex = 3;

  // mocking note in both SDKs 
  // @ts-ignore
  receiverZkFi.notesSource.mockNotes(senderNote.assetId, [senderNote]);
  // @ts-ignore
  senderZkFi.notesSource.mockNotes(senderNote.assetId, [senderNote]);

  // adding sender note to treeSource of both SDKs
  // @ts-ignore
  receiverZkFi.treeSource.insert(senderNote.commitment);

  // @ts-ignore
  senderZkFi.treeSource.insert(receiverNote.commitment);
  //@ts-ignore
  senderZkFi.treeSource.insert(senderNote.commitment);
  }
}


async function main() {
  const zkfi = getSDKInstance();
  const receiverZkFi = getReceiverSDKInstance();

  // Pre-deposit 1000 token of assets - 0x010001 and 0x010002
  let depositName = "deposit_1_weth_without_fee";
  await createMockZTx(depositName, depositReqs[depositName], zkfi);
  await mockDepositNotes(depositName, zkfi);

  //@ts-ignore
  receiverZkFi.notesSource.mockNotes(depositNotes[0].assetId, [depositNotes[0]]);
  //@ts-ignore
  receiverZkFi.notesSource.mockNotes(depositNotes[1].assetId, [depositNotes[1]]);
  //@ts-ignore
  depositNotes.forEach((n) => receiverZkFi.treeSource.insert(n.commitment));

  let transferName = "transfer_1_weth_without_fee";
  await createMockZTx(transferName, transferReqs[transferName], zkfi);
  await mockTransferNotes(transferName, zkfi, receiverZkFi);

  let withdrawName = "withdraw_1_weth_without_fee";
  await createMockZTx(withdrawName, withdrawReqs[withdrawName], receiverZkFi);

  // const reqs = {
  //   ...transferReqs
  // };
  // for (const [name, req] of Object.entries(reqs)) {
  //   await createMockZTx(name, req as any, zkfi);
  // }

  // let balances = await zkfi.getBalances();
  // console.log(balances);
  // console.log(balances[65537]);
  // writeFileSync(`../fixtures/balances.txt`, balances[65537].toString());
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
