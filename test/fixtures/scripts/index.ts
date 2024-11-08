import { genAddressRegistrations } from "./genTestAddressRegistration";
import { genTestDeposits } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers } from "./genTestTransfers";
import { genTestCallAdaptors } from './genTestCallAdaptor';
import { getSDKInstance } from "./sdk";
import { Point, poseidonHash } from "@zkfi-tech/babyjubjub";
import { randomBigInt } from "@zkfi-tech/utils";
import {
  genTreeUpdateData,
  genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

const main = async () => {
  const sdk = getSDKInstance();
  await genAddressRegistrations(sdk);
  // await genTestDeposits(sdk);
  // await genTestWithdrawals(sdk);
  // await genTestTransfers(sdk);
  // await genTestCallAdaptors(sdk);
  // await genTreeUpdateData(sdk);
  // await genTreeUpdateDataWithPartialQueue(sdk);
};

main()
  .then(() => {
    console.log("Successfully generated test fixtures!");
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
