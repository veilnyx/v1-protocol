import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const contractName = "Pool";
const moduleId = camelCase(contractName);

const module = buildModule(moduleId, (m) => {
  const initData = m.getParameter<Hex>("initializeData");

  const poolImpl = m.contract("Pool");
  const poolProxy = m.contract("ERC1967Proxy", [poolImpl, initData]);

  return { poolImpl, poolProxy };
});

export default module;
