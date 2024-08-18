import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const libraryName = "ShieldedAddress";
const moduleId = capitalize(libraryName);

const module = buildModule(moduleId, (m) => {
  const shieldedAddress = m.library(libraryName);
  return { shieldedAddress };
});

export default module;
