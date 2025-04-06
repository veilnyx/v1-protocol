import { Core } from "@zkfi-tech/core";
import { generateTestAddressRegistrations, generateTestAddrRegWithOutsourceProofVerifications } from "./fixture";

const reqs = {
  register_sender: {},
};

export const genAddressRegistrations = async (sdk: Core) => {
  await generateTestAddressRegistrations(reqs, sdk);
};

export const genAddrRegWithOutsourceProofVerification = async (sdk: Core, nebraClient: any, registerCircuitId: string) => {
  await generateTestAddrRegWithOutsourceProofVerifications(reqs, sdk, nebraClient, registerCircuitId);
};
