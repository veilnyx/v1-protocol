import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const libraryName = "Asset";
const moduleId = capitalize(libraryName);

const module = buildModule(moduleId, (m) => {
  const asset = m.library(libraryName);
  return { asset };
});

export default module;
