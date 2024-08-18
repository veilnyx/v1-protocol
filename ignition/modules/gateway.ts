import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const contractName = "Gateway";
const moduleId = capitalize(contractName);

const module = buildModule(moduleId, (m) => {
  const entryPoint = m.getParameter<Hex>("entryPoint");
  const wToken = m.getParameter<Hex>("wToken");
  const pool = "0x";

  const gateway = m.contract(contractName, [entryPoint, wToken, pool]);
  return { gateway };
});
