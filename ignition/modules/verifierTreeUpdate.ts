import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const contractName = "VerifierTreeUpdate";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const verifierTreeUpdate = m.contract(contractName);
  return { verifierTreeUpdate };
});

export default module;
