import hre from "hardhat";
import { Hex } from "viem";
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { assertRevokerMetadata, encodeRevokerMetadata } from "./utils/revokerMetadata";

const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;

export const addInitialAssets = async (poolAddress: Hex) => {
  const client = await hre.viem.getPublicClient();
  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const chainId = await client.getChainId();
  const chainParams = config[chainId] as ChainParams;

  const assetType = chainParams.initAssetType;
  const assetAddresses = chainParams.initAssetAddresses;
  const assetsPrecision = chainParams.initAssetsPrecision;

  console.log(`Adding ${assetAddresses.length} assets to pool...`);

  //@ts-ignore
  const hash = await wallet.writeContract({
    address: poolAddress,
    abi: poolAbi,
    functionName: "addAssets",
    args: [assetType, assetAddresses, assetsPrecision],
  });

  const receipt = await client.waitForTransactionReceipt({ hash });
  console.log("Receipt status:", receipt.status);
  console.log("Done!");
};

export const registerRevokers = async (poolAddress: Hex) => {
  const client = await hre.viem.getPublicClient();
  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const commonParams = config.common as CommonParams;

  // Metadata is write-once per keypair, so validate every CID before sending the first one.
  assertRevokerMetadata(commonParams.revokers);

  for (let i = 0; i < commonParams.revokers.length; i++) {
    const revokerName = commonParams.revokers[i].name;

    const revokerPublicKey = commonParams.revokers[i].revokerPublicKey;
    const encryptionPublicKey = commonParams.revokers[i].encryptionPublicKey;

    const metadata = encodeRevokerMetadata(commonParams.revokers[i].pinataCID);

    console.log(`Registering revoker no. ${i}: ${revokerName}...`);

    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolAddress,
      abi: poolAbi,
      functionName: "registerRevoker",
      args: [revokerPublicKey, encryptionPublicKey, metadata],
    });

    const receipt = await client.waitForTransactionReceipt({ hash });
    console.log("Receipt status:", receipt.status);
    console.log("Done!");
  }
};
