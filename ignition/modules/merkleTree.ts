import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const libraryName = "MerkleTree";
const moduleId = capitalize(libraryName);

const module = buildModule(moduleId, (m) => {
  const merkleTree = m.library(libraryName);
  return { merkleTree };
});

export default module;
