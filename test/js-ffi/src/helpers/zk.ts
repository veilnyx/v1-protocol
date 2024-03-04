import { CircuitPath } from "@zkfi-tech/zk-prover";

export const getCircuitPath = (id: number) => {
  return {
    zKey: `../../../v1-circuits/artifacts/${id}/keys.zkey`,
    wasm: `../../../v1-circuits/artifacts/${id}/circuit.wasm`,
    vKey: `../../../v1-circuits/artifacts/${id}/vKey.json`,
  };
};

export const circuits: Record<string, CircuitPath> = {
  22: getCircuitPath(22),
};
