import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import verifierTransactModule, {
  transactVerifierIds,
} from "./verifierTransact";
import verifierRegisterModule from "./verifierRegister";
import verifierTreeUpdateModule from "./verifierTreeUpdate";
import { camelCase } from "../utils";

const contractName = "Verifier";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const verifierManager = m.getAccount(0);
  const verifiersTransact = m.useModule(verifierTransactModule);
  const { verifierRegister } = m.useModule(verifierRegisterModule);
  const { verifierTreeUpdate } = m.useModule(verifierTreeUpdateModule);

  const transactVerifierInfos = Object.keys(verifiersTransact).map((k, i) => {
    return {
      id: transactVerifierIds[i],
      addr: verifiersTransact[k],
    };
  });

  const verifier = m.contract(contractName, [
    transactVerifierInfos,
    verifierRegister,
    verifierTreeUpdate,
    verifierManager,
  ]);

  return { verifier };
});

export default module;
