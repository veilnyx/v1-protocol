import { encodeAbiParameters, parseAbiParameter } from "viem";
import { ShieldedAccount } from "@zkfi-tech/account";

async function main() {
  const arg = process.argv[2];
  const seed = BigInt(arg);
  const account = ShieldedAccount.generate(seed);
  const abiParam = parseAbiParameter([
    "ZAccount acc",
    "struct ZAccount { uint256 seed; uint256 rootAddress; uint256 signPublicKey; uint256 viewPublicKey; }",
  ]);
  const data = encodeAbiParameters(
    [abiParam],
    [
      {
        seed,
        rootAddress: BigInt(account.rootAddress),
        signPublicKey: BigInt(account.signer.publicKey.pack()),
        viewPublicKey: BigInt(account.viewer.publicKey.pack()),
      },
    ]
  );
  process.stdout.write(data);
}

main().catch((e) => {
  throw new Error(e);
});
