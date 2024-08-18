import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const libraryName = "ShieldedTransaction";
const moduleId = capitalize(libraryName);

const module = buildModule(moduleId, (m) => {
  const shieldedTransaction = m.library(libraryName);
  return { shieldedTransaction };
});

export default module;
