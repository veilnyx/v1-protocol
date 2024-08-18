import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const contractName = "Hasher";
const moduleId = contractName.toLowerCase();

const module = buildModule(moduleId, (m) => {
  const poseidonT3 = m.getParameter<Hex>("poseidonT3");
  const poseidonT4 = m.getParameter<Hex>("poseidonT4");

  const hasher = m.contract(contractName, [poseidonT3, poseidonT4]);
  return { screener: hasher };
});

export default module;
