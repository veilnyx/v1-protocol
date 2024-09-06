import hre from "hardhat";

const setAssetFee = async (wallet: any, paymaster: string, assetId: number, fee: bigint) => {
    const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
    try {
        //@ts-ignore
        await wallet.writeContract({
            address: paymaster,
            abi: paymasterAbi,
            functionName: "setAssetFee",
            args: [assetId, fee],
        });
    } catch {
        console.log("Error setting asset fee");
    }
};

const main = async () => {
    const wallets = await hre.viem.getWalletClients();
    const wallet = wallets[0];
    const paymaster = "0x0a4e7527001e9970cec651b2e2ace9f65bd6e98b";

    const assetFees = [
        { assetId: 65537, fee: BigInt(10000000000000) }, // WETH
        { assetId: 65538, fee: BigInt(1000000) }, // USDC
        { assetId: 65539, fee: BigInt(10000000000000) }, // static aave WETH
        { assetId: 65540, fee: BigInt(1000000) }, // static aave USDC
        { assetId: 65541, fee: BigInt(10000000000000) }, // wstETH Lido
    ];

    for (const { assetId, fee } of assetFees) {
        await setAssetFee(wallet, paymaster, assetId, fee);
    }

    console.log("Asset fees set in Paymaster");
};

main();
