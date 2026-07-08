import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import poolModule from "./pool";
import { camelCase } from "../utils";

const contractName = "Gateway";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const entryPoint = m.getParameter<Hex>("entryPoint");
  const wToken = m.getParameter<Hex>("wToken");

  const { poolProxy } = m.useModule(poolModule);

  const gateway = m.contract(contractName, [entryPoint, wToken, poolProxy]);

  return { gateway };
});

export default module;
