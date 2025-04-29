import { readFileSync } from "fs";
import path from "path";
//@ts-ignore
import * as snarkJs from "snarkjs";
import {
  CircuitPath,
  TreeUpdateData,
  ZTransaction,
} from "@labyrinthac/zk-prover";

const circuitPathBase = path.resolve(
  __dirname,
  "../../../../v1-circuits/artifacts/"
);

export const getCircuitPath = (name: string) => {
  return {
    zKey: `${circuitPathBase}/${name}/keys.zkey`,
    wasm: `${circuitPathBase}/${name}/circuit.wasm`,
    vKey: `${circuitPathBase}/${name}/vKey.json`,
  };
};

export const circuits: Record<string, CircuitPath> = {
  transact21: getCircuitPath("transact21"),
  transact22: getCircuitPath("transact22"),
  register: getCircuitPath("register"),
  treeUpdate: getCircuitPath("treeUpdate"),
};

export const verifyZTx = async (ztx: ZTransaction) => {
  const nIns = ztx.nullifiers.length;
  const nOuts = ztx.commitments.length;
  const id = nIns * 10 + nOuts;
  const circuitPath = getCircuitPath(`transact${id}`);

  const vInp = ztx.toSnarkJsVerifierInput();
  const vKey = JSON.parse(readFileSync(circuitPath.vKey, "utf-8"));

  const res = await snarkJs.groth16.verify(
    vKey,
    vInp.publicSignals,
    vInp.proof
  );
  return res === true;
};

export const verifyTreeUpdateData = async (data: TreeUpdateData) => {
  const circuitPath = getCircuitPath("treeUpdate");
  const vInp = data.toSnarkJsInput();
  const vKey = JSON.parse(readFileSync(circuitPath.vKey, "utf-8"));

  const res = await snarkJs.groth16.verify(
    vKey,
    vInp.publicSignals,
    vInp.proof
  );
  return res === true;
};
