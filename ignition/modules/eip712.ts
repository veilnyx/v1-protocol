import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { camelCase } from "../utils";

const libraryName = "EIP712";
const moduleId = (libraryName);

const module = buildModule(moduleId, (m) => {
    const eip712 = m.library(libraryName);
    return { eip712 };
});

export default module;
