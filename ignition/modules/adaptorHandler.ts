import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const contractName = "AdaptorHandler";
const moduleId = capitalize(contractName);

const module = buildModule(moduleId, (m) => {
  const adaptor = m.contract(contractName);
  return { adaptor };
});

export default module;
