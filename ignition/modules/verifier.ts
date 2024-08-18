import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const transactVerifierIds = [21, 22];
const contractNames = transactVerifierIds.map((id) => `VerifierTransact${id}`);
const moduleId = "verifier";

const module = buildModule(moduleId, (m) => {
  const verifiers = contractNames.map((contractName) =>
    m.contract(contractName)
  );

  const modules = verifiers.reduce((v, acc, i) => {
    return (acc[verifiers[i].contractName] = v);
  }, {});

  return modules;
});

export default module;
