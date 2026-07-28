import path from "path";
import { readFileSync } from "fs";
import hre from "hardhat";
import { toFunctionSelector } from "viem";
import { transferOwnershipToOwner } from "./utils/ownership";

export const deployVerifier = async (
    deployConfig,
    verifierManager: `0x${string}`,
    owner: `0x${string}`
) => {
    const verifier21Abi = hre.artifacts.readArtifactSync("VerifierTransact21").abi;
    const verifier22Abi = hre.artifacts.readArtifactSync("VerifierTransact22").abi;
    const verifier23Abi = hre.artifacts.readArtifactSync("VerifierTransact23").abi;
    const verifier42Abi = hre.artifacts.readArtifactSync("VerifierTransact42").abi;
    const verifier44Abi = hre.artifacts.readArtifactSync("VerifierTransact44").abi;

    const verifierRegister = await hre.viem.deployContract("VerifierRegister", [], deployConfig);
    console.log("VerifierRegister deployed:", verifierRegister.address);

    const verifierTreeUpdate = await hre.viem.deployContract("VerifierTreeUpdate", [], deployConfig);
    console.log("VerifierTreeUpdate deployed:", verifierTreeUpdate.address);

    // Tx Verifiers
    const verifierTransact21 = await hre.viem.deployContract("VerifierTransact21", [], deployConfig);
    console.log("VerifierTransact21 deployed:", verifierTransact21.address);

    const verifierTransact22 = await hre.viem.deployContract("VerifierTransact22", [], deployConfig);
    console.log("VerifierTransact22 deployed:", verifierTransact22.address);

    const verifierTransact23 = await hre.viem.deployContract("VerifierTransact23", [], deployConfig);
    console.log("VerifierTransact23 deployed:", verifierTransact23.address);

    const verifierTransact42 = await hre.viem.deployContract("VerifierTransact42", [], deployConfig);
    console.log("VerifierTransact42 deployed:", verifierTransact42.address);

    const verifierTransact44 = await hre.viem.deployContract("VerifierTransact44", [], deployConfig);
    console.log("VerifierTransact44 deployed:", verifierTransact44.address);

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
        },
        {
            id: 23,
            selector: toFunctionSelector(verifier23Abi[0]),
            addr: verifierTransact23.address
        },
        {
            id: 42,
            selector: toFunctionSelector(verifier42Abi[0]),
            addr: verifierTransact42.address
        },
        {
            id: 44,
            selector: toFunctionSelector(verifier44Abi[0]),
            addr: verifierTransact44.address
        }
    ];

    const verifier = await hre.viem.deployContract("Verifier", [
        txVerifierInfos,
        verifierRegister.address,
        verifierTreeUpdate.address,
        verifierManager
    ],
        deployConfig
    );
    console.log("Verifier deployed:", verifier.address);

    // Verifier's constructor sets the deployer as owner, transfer it to the intended owner
    // (e.g. hardware wallet / multisig). No-op when the deployer is already the owner.
    await transferOwnershipToOwner(
        [{ contract: "Verifier", address: verifier.address }],
        owner,
        deployConfig
    );

    return verifier.address;
}