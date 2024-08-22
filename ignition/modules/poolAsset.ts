import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import poolModule from "./pool";

const moduleId = "poolAsset";

const module = buildModule(moduleId, (m) => {
  const initAssetType = m.getParameter<number>("initAssetType");
  const initAssetAddresses = m.getParameter<Hex[]>("initAssetAddresses");

  const { poolProxy } = m.useModule(poolModule);
  const pool = m.contractAt("Pool", poolProxy);

  // const owner = m.staticCall(pool, "owner", []);
  const owner = m.getAccount(0);
  m.call(pool, "addAssets", [initAssetType, initAssetAddresses], {
    from: owner,
  });

  return {};
});

export default module;
