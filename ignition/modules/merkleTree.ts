import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const libraryName = "MerkleTreeLogic";
const moduleId = camelCase(libraryName);

const module = buildModule(moduleId, (m) => {
  const merkleTree = m.library(libraryName);
  return { merkleTree };
});

export default module;
