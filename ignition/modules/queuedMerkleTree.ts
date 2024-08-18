import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { capitalize } from "../utils";

const libraryName = "QueuedMerkleTree";
const moduleId = capitalize(libraryName);

const module = buildModule(moduleId, (m) => {
  const queuedMerkleTree = m.library(libraryName);
  return { queuedMerkleTree };
});

export default module;
