import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const contractName = "Screener";
const moduleId = contractName.toLowerCase();

const module = buildModule(moduleId, (m) => {
  const sanctionsList = m.getParameter<Hex>("sanctionsList");
  const screener = m.contract(contractName, [sanctionsList]);
  return { screener };
});

export default module;
