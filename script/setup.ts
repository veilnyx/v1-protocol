import hre from "hardhat";
import { encodeAbiParameters, parseAbiParameters } from "viem";
import poolAssetModule from "../ignition/modules/poolAsset";
import poolRevokerModule from "../ignition/modules/poolRevoker";
import { loadConfigs, ChainParams, CommonParams } from "./configs";

const chainId = hre.network.config.chainId;

const config = loadConfigs();

const commonParams = config.common as CommonParams;
const chainParams = config[chainId] as ChainParams;

const main = async () => {
  const parameters = {
    pool: { ...commonParams },
    hasher: {
      poseidonT3: chainParams.poseidonT3,
      poseidonT4: chainParams.poseidonT4,
    },
    screener: {
      sanctionsList: chainParams.sanctionsList,
    },
    poolAsset: {
      initAssetType: chainParams.initAssetType,
      initAssetAddresses: chainParams.initAssetAddresses,
    },
    poolRevoker: {
      revokerPublicKey: [],
      encryptionPublicKey: [],
      metadata: "0x",
    },
  };

  await hre.ignition.deploy(poolAssetModule, {
    parameters,
  });

  for (let i = 0; i < commonParams.revokers.length; i++) {
    const revokerName = commonParams.revokers[i].name;
    const revokerDescription = commonParams.revokers[i].description;

    parameters.poolRevoker.revokerPublicKey =
      commonParams.revokers[i].revokerPublicKey;
    parameters.poolRevoker.encryptionPublicKey =
      commonParams.revokers[i].encryptionPublicKey;
    parameters.poolRevoker.metadata = encodeAbiParameters(
      parseAbiParameters("string name, string description"),
      [revokerName, revokerDescription]
    );

    await hre.ignition.deploy(poolRevokerModule, {
      parameters,
    });
  }
};

main().catch(console.error);
