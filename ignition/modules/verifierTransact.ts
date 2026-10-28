import hre from "hardhat";
import { toFunctionSelector } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

export const transactVerifierIds = [21, 22];
export const transactVerifierContractNames = transactVerifierIds.map(
  (id) => `VerifierTransact${id}`
);
const artifacts = transactVerifierContractNames.map((name) =>
  hre.artifacts.readArtifactSync(name)
);
export const transactVerifierFunctionSelectors = artifacts.map((a) => {
  const input = a.abi.find(
    (t) => t.type === "function" && t.name === "verifyProof"
  );

  if (!input) {
    throw new Error("Function not found");
  }

  return toFunctionSelector(input);
});

const moduleId = "verifierTransact";

const module = buildModule(moduleId, (m) => {
  const transactVerifiers = transactVerifierContractNames.map((contractName) =>
    m.contract(contractName)
  );

  const modules = {};
  transactVerifiers.forEach((verifier, i) => {
    const key = camelCase(transactVerifierContractNames[i]);
    modules[key] = verifier;
  });

  return modules;
});

export default module;
