import { concatHex, padHex, toHex } from "viem";
import { Account } from "@zkfi-tech/account";
import { getSDKInstance } from "./helpers/sdk";
import { encodeZTransaction, parseTransactionRequest } from "./helpers/tx";

async function main() {
  const account = Account.random();
  const zkfi = getSDKInstance({ account });

  const req = parseTransactionRequest();
  const tx = await zkfi.createTransaction(req, { viaBundler: false });
  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);

  const encoded = encodeZTransaction(ztx.toSolidityInput());
  const payload = concatHex([padHex(toHex(ztx.hash), { size: 32 }), encoded]);

  process.stdout.write(payload);
}

main().then(() => process.exit(0));
