import path from "path";
import { readFileSync } from "fs";
import hre from "hardhat";
import { Hex } from "viem";

const poseidonBasePath = path.resolve(__dirname, "../src/poseidon");

const poseidonT3Path = path.resolve(poseidonBasePath, "t3.txt");
const poseidonT4Path = path.resolve(poseidonBasePath, "t4.txt");

const poseidonT3Code = readFileSync(poseidonT3Path, "utf-8") as Hex;
const poseidonT4Code = readFileSync(poseidonT4Path, "utf-8") as Hex;

export const deployHasher = async () => {
  const client = await hre.viem.getPublicClient();
  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const [address] = await wallet.getAddresses();

  const bytecodes = [poseidonT3Code, poseidonT4Code];

  const hashes = await Promise.all(
    bytecodes.map((bytecode) => {
      //@ts-ignore
      return wallet.deployContract({
        bytecode,
        abi: [],
        account: address,
      });
    })
  );

  const receipts = await Promise.all(
    hashes.map((hash) => client.waitForTransactionReceipt({ hash }))
  );

  const poseidonT3 = receipts[0].contractAddress;
  const poseidonT4 = receipts[1].contractAddress;

  const hasher = await hre.viem.deployContract("Hasher", [
    poseidonT3,
    poseidonT4,
  ]);

  return { hasher: hasher.address, poseidonT3, poseidonT4 };
};
