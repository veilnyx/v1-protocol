import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const libraryName = "QueuedMerkleTreeLogic";
const moduleId = camelCase(libraryName);

const module = buildModule(moduleId, (m) => {
  const queuedMerkleTree = m.library(libraryName);
  return { queuedMerkleTree };
});

export default module;
