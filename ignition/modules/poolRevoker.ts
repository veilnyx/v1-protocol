import { Hex } from "viem";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import poolModule from "./pool";

const moduleId = "poolRevoker";

const module = buildModule(moduleId, (m) => {
  const revokerPublicKey = m.getParameter<bigint[][]>("revokerPublicKey");
  const encryptionPublicKey = m.getParameter<bigint[][]>("encryptionPublicKey");
  const metadata = m.getParameter<Hex>("metadata");

  const { poolProxy } = m.useModule(poolModule);
  const pool = m.contractAt("Pool", poolProxy);

  m.call(pool, "registerRevoker", [
    revokerPublicKey,
    encryptionPublicKey,
    metadata,
  ]);

  return {};
});

export default module;
