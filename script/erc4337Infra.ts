import hre from "hardhat";
import { parseEther, parseUnits } from "viem";

/// @todo: Gas cost to be made dynamic
// Estimated values based on gas profiling and current gas prices of 2 gwei. Ref. the Labyrinth Fee Types sheet for working.
// const PAYMASTER_FEE_INSTANT_TX_ETH = parseEther("0.001467726");
// const PAYMASTER_FEE_INSTANT_TX_USDC = parseUnits("2.62", 6);
// const PAYMASTER_FEE_PREVERIFIED_TX_ETH = parseEther("0.001063");
// const PAYMASTER_FEE_PREVERIFIED_TX_USDC = parseUnits("1.89", 6);
const PAYMASTER_FUNDING_AMT = parseEther("0.005"); // 0.005 ETH

export const deployErc4337Infra = async (chainParams, poolAddress, mempoolAddress, deployConfig) => {
    // ERC4337 infra setup
    const gateway = await hre.viem.deployContract("Gateway", [
        chainParams.entryPoint,
        chainParams.wToken,
        poolAddress,
        mempoolAddress,
    ], deployConfig);
    console.log("Gateway deployed:", gateway.address);

    const paymaster = await hre.viem.deployContract("Paymaster", [
        chainParams.entryPoint,
        gateway.address,
    ], deployConfig);
    console.log("Paymaster deployed:", paymaster.address);

    await fundPaymaster(paymaster.address, deployConfig.client.wallet, deployConfig.client.public);

    /**
    // Assuming WETH and USDC are supported assets in the protocol
    const wethAssetId = 65537;
    const usdcAssetId = 65538;
    // Fee assets
    await setAssetFee(paymaster.address, wethAssetId, PAYMASTER_FEE_INSTANT_TX_ETH, deployConfig.client.wallet, deployConfig.client.public);
    
    await setAssetFeeForPreverifiedTx(paymaster.address, wethAssetId, PAYMASTER_FEE_PREVERIFIED_TX_ETH, deployConfig.client.wallet, deployConfig.client.public)
    await setAssetFee(paymaster.address, usdcAssetId, PAYMASTER_FEE_INSTANT_TX_USDC, deployConfig.client.wallet, deployConfig.client.public);
    
    await setAssetFeeForPreverifiedTx(paymaster.address, usdcAssetId, PAYMASTER_FEE_PREVERIFIED_TX_USDC, deployConfig.client.wallet, deployConfig.client.public);
     */

    return {
        paymaster: paymaster.address,
        gateway: gateway.address
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

const setAssetFee = async (paymaster, assetId, amount, wallet, client) => {
    const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
    let rct;
    try {

        const hash = await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [assetId, amount]
        });

        rct = await client.waitForTransactionReceipt({ hash });
        console.log("rct:assetIDFeeAdded", rct.status);
    } catch (error) {
        console.log("Error adding asset id");
        console.log(error.message);
        console.log("Error rct:", rct);
    }
}

/**
    const setAssetFeeForPreverifiedTx = async (paymaster, assetId, amount, wallet, client) => {
        const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
        let rct;
        try {

            const hash = await wallet.writeContract({
                address: paymaster,
                abi: paymasterAbi,
                functionName: "setAssetFeeForPreVerifiedTx",
                args: [assetId, amount]
            });

            rct = await client.waitForTransactionReceipt({ hash });
            console.log("rct:assetIDFeeAddedForPreverifiedTx", rct.status);
        } catch (error) {
            console.log("Error adding asset id");
            console.log(error.message);
            console.log("Error rct:", rct);
        }
    }
*/