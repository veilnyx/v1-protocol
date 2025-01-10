import path from "path";
import { readFileSync } from "fs";
import hre from "hardhat";
import { toFunctionSelector } from "viem";

export const deployVerifier = async (tenderlyDeployConfig) => {
    const verifier21Abi = hre.artifacts.readArtifactSync("VerifierTransact21").abi;
    const verifier22Abi = hre.artifacts.readArtifactSync("VerifierTransact22").abi;

    const verifierRegister = await hre.viem.deployContract("VerifierRegister", [], tenderlyDeployConfig);
    console.log("VerifierRegister deployed:", verifierRegister.address);

    const verifierTreeUpdate = await hre.viem.deployContract("VerifierTreeUpdate", [], tenderlyDeployConfig);
    console.log("VerifierTreeUpdate deployed:", verifierTreeUpdate.address);

    // Tx Verifiers
    const verifierTransact21 = await hre.viem.deployContract("VerifierTransact21", [], tenderlyDeployConfig);
    console.log("VerifierTransact21 deployed:", verifierTransact21.address);

    const verifierTransact22 = await hre.viem.deployContract("VerifierTransact22", [], tenderlyDeployConfig);
    console.log("VerifierTransact22 deployed:", verifierTransact22.address);

    // Prepare the TransactionVerifierInfo array
    const txVerifierInfos = [
        {
            id: 21,
            selector: toFunctionSelector(verifier21Abi[0]),
            addr: verifierTransact21.address
        },
        {
            id: 22,
            selector: toFunctionSelector(verifier22Abi[0]),
            addr: verifierTransact22.address
        }
        // Add more TransactionVerifierInfo structs as needed
    ];

    const verifier = await hre.viem.deployContract("Verifier", [
        txVerifierInfos,
        verifierRegister.address,
        verifierTreeUpdate.address,
    ],
        tenderlyDeployConfig
    );
    console.log("Verifier deployed:", verifier.address);

    return verifier.address;
}