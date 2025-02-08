import path from "path";
import { readFileSync } from "fs";
import hre from "hardhat";
import { Hex } from "viem";
import { createCode, generateABI } from "../node_modules/circomlibjs/src/poseidon_gencontract.js";

const poseidonBasePath = path.resolve(__dirname, "../src/poseidon");

const poseidonT3Path = path.resolve(poseidonBasePath, "t3.txt");
const poseidonT4Path = path.resolve(poseidonBasePath, "t4.txt");
const poseidonT5Path = path.resolve(poseidonBasePath, "t5.json");

const poseidonT3Code = readFileSync(poseidonT3Path, "utf-8") as Hex;
const poseidonT4Code = readFileSync(poseidonT4Path, "utf-8") as Hex;

async function deployPoseidon(inputs: number, wallet, client) {
  const [address] = await wallet.getAddresses();
  const poseidonT5Data = JSON.parse(readFileSync(poseidonT5Path, "utf-8"));
  const bytecode = poseidonT5Data.bytecode as Hex;

  const deployTxHash = await wallet.deployContract({
    bytecode,
    abi: [],
    account: address
  });

  const receipt = await client.waitForTransactionReceipt({ hash: deployTxHash });
  const poseidonT5 = receipt.contractAddress;
  console.log("PoseidonT5 deployed:", poseidonT5);
}

export const deployHasher = async (wallet, client, tenderlyDeployConfig) => {
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
  ], tenderlyDeployConfig);

  return { hasher: hasher.address, poseidonT3, poseidonT4 };
};
