import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import poolModule from "./pool";
import { camelCase } from "../utils";

const contractName = "Paymaster";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const entryPoint = m.getParameter<Hex>("entryPoint");
  const { poolProxy } = m.useModule(poolModule);
  const paymaster = m.contract(contractName, [entryPoint, poolProxy]);
  return { paymaster };
});

export default module;
