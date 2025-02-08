// generatePoseidonBytecode.mts
import path from "path";
import fs from "fs";

async function main() {
    // Dynamic import for ESM module
    const { poseidonContract } = await import("circomlibjs");
    const poseidonBasePath = path.resolve(__dirname, "../src/poseidon");

    const contractName = "t5";
    const code = poseidonContract.createCode(4);
    const abi = poseidonContract.generateABI(4);

    // Write files
    if (!fs.existsSync(poseidonBasePath)) {
        fs.mkdirSync(poseidonBasePath, { recursive: true });
    }

    fs.writeFileSync(
        path.join(poseidonBasePath, `${contractName}.txt`),
        code
    );
}

main().catch(console.error);