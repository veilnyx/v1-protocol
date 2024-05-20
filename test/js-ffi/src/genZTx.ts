import { readFileSync } from "fs";
import { Hex } from "viem";
import { Core } from "@zkfi-tech/core";
import { Note } from "@zkfi-tech/transaction";
import { ZTransaction } from "@zkfi-tech/zk-prover";
import { getSDKInstance } from "./helpers/sdk";
import { parseTransactionRequest } from "./helpers/tx";

async function mockDeposit(zkfi: Core) {
  const encoded = readFileSync("../mocks/deposit.txt", "utf-8") as Hex;
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

  // Pre-deposit 10000 token of assets - 0x010001 and 0x010002
  mockDeposit(zkfi);

  const req = parseTransactionRequest();
  const opts = { viaBundler: false };

  const tx = await zkfi.createTransaction(req, opts);
  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);

  const encoded = ztx.encode();
  // const inp = ztx.toSolidityInput();

  // const encoded = encodeZTransaction(inp);

  process.stdout.write(encoded);
}

main().then(() => process.exit(0));
