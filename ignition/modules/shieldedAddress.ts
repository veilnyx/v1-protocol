import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import merkleTreeModule from "./merkleTree";
import { camelCase } from "../utils";

const libraryName = "ShieldedAddressLogic";
const moduleId = camelCase(libraryName);

const module = buildModule(moduleId, (m) => {
  const { merkleTree } = m.useModule(merkleTreeModule);

  const shieldedAddress = m.library(libraryName, {
    libraries: { MerkleTreeLogic: merkleTree },
  });

  return { shieldedAddress };
});

export default module;
