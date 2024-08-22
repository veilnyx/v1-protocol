import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import assetModule from "./asset";
import merkleTreeModule from "./merkleTree";
import queuedMerkleTreeModule from "./queuedMerkleTree";
import { camelCase } from "../utils";

const libraryName = "ShieldedTransactionLogic";
const moduleId = camelCase(libraryName);

const module = buildModule(moduleId, (m) => {
  const { asset } = m.useModule(assetModule);
  const { merkleTree } = m.useModule(merkleTreeModule);
  const { queuedMerkleTree } = m.useModule(queuedMerkleTreeModule);

  const shieldedTransaction = m.library(libraryName, {
    libraries: {
      AssetLogic: asset,
      MerkleTreeLogic: merkleTree,
      QueuedMerkleTreeLogic: queuedMerkleTree,
    },
  });

  return { shieldedTransaction };
});

export default module;
