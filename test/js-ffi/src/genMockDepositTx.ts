import { writeFileSync } from "fs";
import { keccak256, parseEther, stringToBytes } from "viem";
import { Fr } from "@zkfi-tech/babyjubjub";
import { ShieldedAccount } from "@zkfi-tech/account";
import { TransactionRequest, TransactionType } from "@zkfi-tech/shared-types";
import { getSDKInstance } from "./helpers/sdk";

async function main() {
  const account = ShieldedAccount.generate(
    Fr.from(keccak256(stringToBytes("sender"))).val
  );
  const zkfi = getSDKInstance();

  const assetIds = [0x010001, 0x010002];
  const values = [parseEther("10000"), parseEther("10000")];

  const req: TransactionRequest = {
    type: TransactionType.DEPOSIT,
    assetIds,
    values,
    feeAssetId: 0,
    to: account.shieldedAddress.pack(),
  };

  const opts = { viaBundler: false };
  const tx = await zkfi.createTransaction(req, opts);
  const signedTx = await zkfi.signTransaction(tx);
  const ztx = await zkfi.proveTransaction(signedTx);
  const encoded = ztx.encode();
  writeFileSync("../mocks/deposit.txt", encoded);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
