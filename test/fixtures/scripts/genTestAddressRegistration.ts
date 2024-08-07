import { Core } from "@zkfi-tech/core";
import { generateTestAddressRegistrations } from "./fixture";

const reqs = {
  register_sender: {},
};

export const genAddressRegistrations = async (sdk: Core) => {
  await generateTestAddressRegistrations(reqs, sdk);
};
