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
const withdrawAddress = "0x19d10A59420fd2587a73EB65266E57eb6b6157f9";

const wethAssetId = 0x010001;

const dirFixtures = "../fixtures/ztx";

const depositReqs = {
  deposit_1000_weth_for_seq_ztx: {
    type: TransactionType.DEPOSIT,
    assetIds: [wethAssetId],
    values: [parseEther("1000")],
    feeAssetId: 0,
    to: senderAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0
  }
};

const withdrawReqs = {
  withdraw_500_weth_for_seq_ztx: {
    type: TransactionType.WITHDRAW,
    assetIds: [wethAssetId],
    values: [parseEther("500")],
    feeAssetId: 0,
    to: withdrawAddress,
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0
  }
};

const transferReqs = {
  transfer_200_weth_for_seq_ztx: {
    type: TransactionType.TRANSFER,
    assetIds: [wethAssetId],
    values: [parseEther("200")],
    feeAssetId: 0,
    to: receiverAccount.shieldedAddress.pack(),
    viaBundler: false,
    paymaster: zeroAddress,
    revokerId: 0
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
    revokerId: 0,
    payload:
      "0x000000000000000000000000000000000000000000000000000000000001000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", // beneficiary: pool address (address(0))
  }
};

const createMockZTx = async (
  name: string,
  req: TransactionRequest & TransactionOptions,
  zkfi: Core
) => {
  const opts = { viaBundler: req.viaBundler, paymaster: req.paymaster, revokerId: req.revokerId };
  const tx = await zkfi.createTransaction(req as any, opts);

  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);
  const encoded = ztx.encode();
  writeFileSync(`${dirFixtures}/${name}.txt`, encoded);
};

async function mockDepositNotes(depositName: string, zkfi: Core) {
  const encoded = readFileSync(
    `${dirFixtures}/${depositName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  const revokerData = await zkfi.getRevokerData(0);
  const revokerPublicKey = revokerData.revokerPublicKey;

  const notes = ztx.noteMemos.map((m: Hex) => Note.fromMemo(m, zkfi.account, revokerPublicKey));
  notes.forEach((n, i) => (n.leafIndex = i));

  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[1].assetId, [notes[1]]);
  //@ts-ignore
  notes.forEach((n) => zkfi.commitmentTreeSource.insert(n.commitment));
}

async function mockWithdrawNotes(withdrawName: string, zkfi: Core) {
  const encoded = readFileSync(
    `${dirFixtures}/${withdrawName}.txt`,
    "utf-8"
  ) as Hex;
  const ztx = ZTransaction.decode(encoded) as any;
  const revokerData = await zkfi.getRevokerData(0);
  const revokerPublicKey = revokerData.revokerPublicKey;

  const notes = ztx.noteMemos.map((m: Hex) => Note.fromMemo(m, zkfi.account, revokerPublicKey));
  notes.forEach((n, i) => (n.leafIndex = i + 2)); // considering 2 notes of deposit already exists

  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[1].assetId, [notes[1]]);
  //@ts-ignore
  notes.forEach((n) => zkfi.commitmentTreeSource.insert(n.commitment));
}

async function main() {
  const zkfi = getSDKInstance();

  /// @dev Order of ZTx creation and note mocking is crucial here. This is because for any followup ztx creation, the outMemos and notes created by the previous tx are needed. Hence to carry out 3 txns in a sequence, after deposit, withdraw tx should be created and it's notes mocked. This is cuz in case of Withdraw tx, the same zkFi instance will still be able to decrypt the outMemos(and own both the notes gen. by the withdraw tx) apart from the value withdrawn. This is important for mocking notes and making them available for next tx. Then we can finally create the transfer tx.
  let depositName = "deposit_1000_weth_for_seq_ztx";
  await createMockZTx(depositName, depositReqs[depositName], zkfi);
  await mockDepositNotes(depositName, zkfi);

  let withdrawName = "withdraw_500_weth_for_seq_ztx";
  await createMockZTx(withdrawName, withdrawReqs[withdrawName], zkfi);
  await mockWithdrawNotes(withdrawName, zkfi);

  let transferName = "transfer_200_weth_for_seq_ztx";
  await createMockZTx(transferName, transferReqs[transferName], zkfi);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
