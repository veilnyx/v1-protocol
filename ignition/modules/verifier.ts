import hre from "hardhat";
import { toFunctionSelector } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import verifierTransactModule from "./verifierTransact";
import verifierRegisterModule from "./verifierRegister";
import verifierTreeUpdateModule from "./verifierTreeUpdate";
import { camelCase } from "../utils";

const transactVerifierIds = [21, 22];
const transactVerifierContractNames = transactVerifierIds.map(
  (id) => `VerifierTransact${id}`
);

const artifacts = transactVerifierContractNames.map((name) =>
  hre.artifacts.readArtifactSync(name)
);
const transactVerifierFunctionSelectors = artifacts.map((a) => {
  const input = a.abi.find(
    (t) => t.type === "function" && t.name === "verifyProof"
  );

  if (!input) {
    throw new Error("Function not found");
  }

  return toFunctionSelector(input);
});

const contractName = "Verifier";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const verifiersTransact = m.useModule(verifierTransactModule);
  const { verifierRegister } = m.useModule(verifierRegisterModule);
  const { verifierTreeUpdate } = m.useModule(verifierTreeUpdateModule);

  const transactVerifierInfos = transactVerifierIds.map((id, i) => {
    return {
      id,
      selector: transactVerifierFunctionSelectors[i],
      address: verifiersTransact["VerifierTransact21"],
    };
  });
  const verifier = m.contract(contractName, [
    // [],
    transactVerifierInfos,
    verifierRegister,
    verifierTreeUpdate,
  ]);

  return { verifier };
});

export default module;
