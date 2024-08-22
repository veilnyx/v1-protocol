import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import hasherModule from "./hasher";
import verifierModule from "./verifier";
import screenerModule from "./screener";
import adaptorHandlerModule from "./adaptorHandler";
import assetModule from "./asset";
import merkleTreeModule from "./merkleTree";
import queuedMerkleTreeModule from "./queuedMerkleTree";
import eip712Module from "./eip712";
import shieldedAddressModule from "./shieldedAddress";
import shieldedTransactionModule from "./shieldedTransaction";
import { camelCase } from "../utils";

const contractName = "Pool";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const addressTreeDepth = m.getParameter<number>("addressTreeDepth");
  const commitmentTreeDepth = m.getParameter<number>("commitmentTreeDepth");
  const commitmentTreeQueueSize = m.getParameter<number>(
    "commitmentTreeQueueSize"
  );
  const withdrawFeeBps = m.getParameter<number>("withdrawFeeBps");

  // Dependencies
  const { hasher } = m.useModule(hasherModule);
  const { verifier } = m.useModule(verifierModule);
  const { screener } = m.useModule(screenerModule);
  const { adaptorHandler } = m.useModule(adaptorHandlerModule);

  // Libraries
  const { asset } = m.useModule(assetModule);
  const { merkleTree } = m.useModule(merkleTreeModule);
  const { shieldedTransaction } = m.useModule(shieldedTransactionModule);
  const { shieldedAddress } = m.useModule(shieldedAddressModule);
  const { queuedMerkleTree } = m.useModule(queuedMerkleTreeModule);
  const { eip712 } = m.useModule(eip712Module);

  const poolImpl = m.contract("Pool", [], {
    libraries: {
      AssetLogic: asset,
      MerkleTreeLogic: merkleTree,
      QueuedMerkleTreeLogic: queuedMerkleTree,
      ShieldedAddressLogic: shieldedAddress,
      ShieldedTransactionLogic: shieldedTransaction,
      EIP712: eip712,
    },
  });

  // return { poolImpl };

  const initData = m.encodeFunctionCall(poolImpl, "initialize", [
    addressTreeDepth,
    commitmentTreeDepth,
    commitmentTreeQueueSize,
    verifier,
    adaptorHandler,
    screener,
    hasher,
    withdrawFeeBps,
  ]);

  const poolProxy = m.contract("PoolProxy", [poolImpl, initData]);

  return { poolImpl, poolProxy };
});

export default module;
