import { readFileSync } from "fs";
//@ts-ignore
import * as snarkJs from "snarkjs";
import { CircuitPath, ZTransaction } from "@zkfi-tech/zk-prover";

export const getCircuitPath = (id: number) => {
  return {
    zKey: `../v1-circuits/artifacts/${id}/keys.zkey`,
    wasm: `../v1-circuits/artifacts/${id}/circuit.wasm`,
    vKey: `../v1-circuits/artifacts/${id}/vKey.json`,
  };
};

export const circuits: Record<string, CircuitPath> = {
  22: getCircuitPath(22),
};

export const verifyZTx = async (ztx: ZTransaction) => {
  const nIns = ztx.nullifiers.length;
  const nOuts = ztx.commitments.length;
  const id = nIns * 10 + nOuts;
  const circuitPath = getCircuitPath(id);

  const vInp = ztx.toSnarkJsVerifierInput();
  const vKey = JSON.parse(readFileSync(circuitPath.vKey, "utf-8"));

  const res = await snarkJs.groth16.verify(
    vKey,
    vInp.publicSignals,
    vInp.proof
  );
  return res === true;
};
