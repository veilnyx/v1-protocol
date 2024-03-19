import { readFileSync } from "fs";
import { keccak256, stringToBytes } from "viem";
import { ShieldedAccount } from "@zkfi-tech/account";
import { Fr } from "@zkfi-tech/babyjubjub";
import { HexString } from "@zkfi-tech/shared-types";
import { Core } from "@zkfi-tech/core";
import { Note } from "@zkfi-tech/transaction";
import { getSDKInstance } from "./helpers/sdk";
import {
  decodeZTransaction,
  encodeZTransaction,
  parseTransactionRequest,
} from "./helpers/tx";

async function mockDeposit(zkfi: Core) {
  const encoded = readFileSync("../fixtures/deps.txt", "utf-8") as HexString;

  const ztx = decodeZTransaction(encoded) as any;

  const notes = ztx.memos.map((m: HexString) => Note.fromMemo(m, zkfi.account));
  notes.forEach((n, i) => (n.leafIndex = i));

  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[0].assetId, [notes[0]]);
  //@ts-ignore
  zkfi.notesSource.mockNotes(notes[1].assetId, [notes[1]]);
  //@ts-ignore
  notes.forEach((n) => zkfi.treeSource.insert(n.commitment));
}

async function main() {
  const account = ShieldedAccount.generate(
    Fr.from(keccak256(stringToBytes("sender"))).val
  );
  const zkfi = getSDKInstance({ account });
  // Pre-deposit 10000 token of assets - 0x010001 and 0x010002
  mockDeposit(zkfi);

  const req = parseTransactionRequest();
  const opts = { viaBundler: false };

  const tx = await zkfi.createTransaction(req, opts);
  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);
  const inp = ztx.toSolidityInput();

  const encoded = encodeZTransaction(inp);

  process.stdout.write(encoded);
}

main().then(() => process.exit(0));
