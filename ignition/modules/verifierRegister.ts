import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const contractName = "VerifierRegister";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const verifierRegister = m.contract(contractName);
  return { verifierRegister };
});

export default module;
