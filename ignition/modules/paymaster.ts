import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const contractName = "Paymaster";
const moduleId = capitalize(contractName);

const module = buildModule(moduleId, (m) => {
  const entryPoint = m.getParameter<Hex>("entryPoint");
  const pool = "0x";
  const paymaster = m.contract(contractName, [entryPoint, pool]);
  return { paymaster };
});

export default module;
