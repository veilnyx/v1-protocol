import hre from "hardhat";
import { encodeAbiParameters, Hex, parseAbiParameters } from "viem";
import { loadConfigs, ChainParams, CommonParams } from "./configs";

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

  console.log(`Adding ${assetAddresses.length} assets to pool...`);

  //@ts-ignore
  const hash = await wallet.writeContract({
    address: poolAddress,
    abi: poolAbi,
    functionName: "addAssets",
    args: [assetType, assetAddresses],
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

  for (let i = 0; i < commonParams.revokers.length; i++) {
    const revokerName = commonParams.revokers[i].name;
    const revokerDescription = commonParams.revokers[i].description;

    const revokerPublicKey = commonParams.revokers[i].revokerPublicKey;
    const encryptionPublicKey = commonParams.revokers[i].encryptionPublicKey;

    const metadata = encodeAbiParameters(
      parseAbiParameters("string name, string description"),
      [revokerName, revokerDescription]
    );

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
