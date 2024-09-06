import path from "path";
import { readFileSync } from "fs";
import hre from "hardhat";
import { Hex } from "viem";

const poseidonBasePath = path.resolve(__dirname, "../src/poseidon");

const poseidonT3Path = path.resolve(poseidonBasePath, "t3.txt");
const poseidonT4Path = path.resolve(poseidonBasePath, "t4.txt");

const poseidonT3Code = readFileSync(poseidonT3Path, "utf-8") as Hex;
const poseidonT4Code = readFileSync(poseidonT4Path, "utf-8") as Hex;

export const deployHasher = async (wallet, client) => {
  // const client = await hre.viem.getPublicClient();
  // const wallets = await hre.viem.getWalletClients();
  // const wallet = wallets[0];
  const [address] = await wallet.getAddresses();

  const bytecodes = [poseidonT3Code, poseidonT4Code];

  const hashPoseidonT3 = await wallet.deployContract({
    bytecode: poseidonT3Code,
    abi: [],
    account: address
  });

  const receiptPT3 = await client.waitForTransactionReceipt({ hash: hashPoseidonT3 });

  const hashPoseidonT4 = await wallet.deployContract({
    bytecode: poseidonT4Code,
    abi: [],
    account: address
  });
  const receiptPT4 = await client.waitForTransactionReceipt({ hash: hashPoseidonT4 });

  const poseidonT3 = receiptPT3.contractAddress;
  console.log("PoseidonT3 deployed:", poseidonT3);
  const poseidonT4 = receiptPT4.contractAddress;
  console.log("PoseidonT4 deployed:", poseidonT4);

  const hasher = await hre.viem.deployContract("Hasher", [
    poseidonT3,
    poseidonT4,
  ]);

  return { hasher: hasher.address, poseidonT3, poseidonT4 };
};
