import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import hasherModule from "./hasher";
import verifierModule from "./verifier";
import screenerModule from "./screener";
import adaptorHandlerModule from "./adaptorHandler";
import assetModule from "./asset";
import merkleTreeModule from "./merkleTree";
import queuedMerkleTreeModule from "./queuedMerkleTree";
import shieldedAddressModule from "./shieldedAddress";
import shieldedTransactionModule from "./shieldedTransaction";
import { camelCase } from "../utils";

const contractName = "Pool";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const pauser = m.getParameter<string>("pauser");
  const withdrawFeeBps = m.getParameter<number>("withdrawFeeBps");
  const tvlLimitUsd = m.getParameter<bigint>("tvlLimitUsd");
  const minDepositUsd = m.getParameter<bigint>("minDepositUsd");
  const maxDepositUsd = m.getParameter<bigint>("maxDepositUsd");
  const priceFeedStalenessThreshold = m.getParameter<bigint>(
    "priceFeedStalenessThreshold"
  );
  const nativeWToken = m.getParameter<string>("nativeWToken");

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

  const poolImpl = m.contract("Pool", [], {
    libraries: {
      AssetLogic: asset,
      MerkleTreeLogic: merkleTree,
      QueuedMerkleTreeLogic: queuedMerkleTree,
      ShieldedAddressLogic: shieldedAddress,
      ShieldedTransactionLogic: shieldedTransaction,
    },
  });

  const initAddressParams = {
    verifier,
    adaptorHandler,
    screener,
    hasher,
    pauser,
  };

  const configParams = {
    withdrawFeeBps,
    tvlLimitUsd,
    minDepositUsd,
    maxDepositUsd,
    priceFeedStalenessThreshold,
    nativeWToken,
  };

  const initData = m.encodeFunctionCall(poolImpl, "initialize", [
    initAddressParams,
    configParams,
  ]);

  const poolProxy = m.contract("PoolProxy", [poolImpl, initData]);

  return { poolImpl, poolProxy };
});

export default module;
