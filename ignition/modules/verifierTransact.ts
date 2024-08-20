import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const transactVerifierIds = [21, 22];
const transactVerifierContractNames = transactVerifierIds.map(
  (id) => `VerifierTransact${id}`
);

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
