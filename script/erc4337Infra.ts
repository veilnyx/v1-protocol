import hre from "hardhat";
import { parseEther, parseUnits } from "viem";

const PAYMASTER_FUNDING_AMT = parseEther("0.5");

export const deployErc4337Infra = async (chainParams, poolAddress, deployConfig) => {
    // ERC4337 infra setup
    const gateway = await hre.viem.deployContract("Gateway", [
        chainParams.entryPoint,
        chainParams.wToken,
        poolAddress,
    ], deployConfig);
    console.log("Gateway deployed:", gateway.address);

    const paymaster = await hre.viem.deployContract("Paymaster", [
        chainParams.entryPoint,
        gateway.address,
        poolAddress
    ], deployConfig);
    console.log("Paymaster deployed:", paymaster.address);

    // Set up Chainlink feeds for paymaster (sequential to avoid nonce conflicts)
    for (let index = 0; index < chainParams.initAssetIdsVeilnyx.length; index++) {
        const assetId = chainParams.initAssetIdsVeilnyx[index];
        await setAssetChainlinkFeedInPaymaster(paymaster.address, assetId, chainParams.initNativeGasTokenToAssetChainlinkFeeds[index], deployConfig.client.wallet, deployConfig.client.public);
    }

    await fundPaymaster(paymaster.address, deployConfig.client.wallet, deployConfig.client.public);

    return {
        paymaster: paymaster.address,
        gateway: gateway.address,
    };
}

const fundPaymaster = async (paymaster, wallet, client) => {
    const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
    let rct;
    try {
        const hash = await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "depositToEntryPoint",
            args: [],
            value: PAYMASTER_FUNDING_AMT,
        });

        rct = await client.waitForTransactionReceipt({ hash });
        console.log("rct:paymasterFunded", rct.status);
    } catch (error) {
        console.log("Error funding paymaster");
        console.log(error.message);
        console.log("rct:error:", rct);
    }
}

const setAssetChainlinkFeedInPaymaster = async (paymaster, assetId, chainlinkFeed, wallet, client) => {
    const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
    let rct;
    try {
        console.log(`Setting Chainlink feed for asset ${assetId}...`);
        const hash = await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setChainlinkFeed",
            args: [assetId, chainlinkFeed]
        });

        rct = await client.waitForTransactionReceipt({ hash });
        console.log(`✅ Chainlink feed set for asset ${assetId}, status:`, rct.status);
    } catch (error) {
        console.log(`❌ Error setting chainlink feed for asset ${assetId}`);
        console.log("Error message:", error.message);
        if (rct) {
            console.log("Error rct:", rct);
        }
        throw error; // Re-throw to stop execution on failure
    }
}