import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const contractName = "Screener";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const sanctionsList = m.getParameter<Hex>("sanctionsList");
  const screener = m.contract(contractName, [sanctionsList]);
  return { screener };
});

export default module;
