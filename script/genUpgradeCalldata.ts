/**
 * Outputs the calldata for setTvlPriceStalenessTreshold to be used in a Safe UI
 * upgradeToAndCall transaction.
 *
 * Usage:
 *   pnpm hardhat run script/genUpgradeCalldata.ts --network ethSepolia
 *
 * Copy the printed calldata into the Safe UI's "Data" field when crafting the
 * upgradeToAndCall(newImpl, calldata) transaction.
 */
import hre from "hardhat";
import { encodeFunctionData } from "viem";

const STALENESS_THRESHOLD = 86400n * 5n; // 5 days in seconds

const main = async () => {
    const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;

    const calldata = encodeFunctionData({
        abi: poolAbi,
        functionName: "setTvlPriceStalenessTreshold",
        args: [STALENESS_THRESHOLD],
    });

    console.log("\n=== Safe UI calldata ===");
    console.log("Function : setTvlPriceStalenessTreshold(uint256)");
    console.log("Threshold:", STALENESS_THRESHOLD.toString(), "seconds (", Number(STALENESS_THRESHOLD) / 86400, "days )");
    console.log("Calldata :", calldata);
    console.log("=======================\n");
};

main().catch(console.error);
