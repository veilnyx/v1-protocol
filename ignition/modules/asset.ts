import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const libraryName = "AssetLogic";
const moduleId = camelCase(libraryName);

const module = buildModule(moduleId, (m) => {
  const asset = m.library(libraryName);
  return { asset };
});

export default module;
