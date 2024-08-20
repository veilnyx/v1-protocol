import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const contractName = "AdaptorHandler";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const adaptor = m.contract(contractName);
  return { adaptor };
});

export default module;
