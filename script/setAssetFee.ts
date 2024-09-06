import hre from "hardhat";

const main = async () => {
    const client = await hre.viem.getPublicClient();
    const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
    const wallets = await hre.viem.getWalletClients();
    const wallet = wallets[0];
    const paymaster = "0x0a4e7527001e9970cec651b2e2ace9f65bd6e98b";
    try {
        //@ts-ignore
        // WETH
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [Number(65539), BigInt(10000000000000)],
        });

        //@ts-ignore
        // USDC
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [Number(65538), BigInt(1000000)],
        });

        //@ts-ignore
        // static aave WETH
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [Number(65539), BigInt(10000000000000)],
        });

        //@ts-ignore
        // static aave USDC
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [Number(65540), BigInt(1000000)],
        });

        //@ts-ignore
        // wstETH Lido
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [Number(65541), BigInt(10000000000000)],
        });

        console.log("Asset fees set in Paymaster");
    } catch {
        console.log("Error setting asset fee");
    }
}

main();

