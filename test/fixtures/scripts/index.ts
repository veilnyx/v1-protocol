import { genAddressRegistrations } from "./genTestAddressRegistration";
import { genTestDeposits } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { getSDKInstance } from "./sdk";

const main = async () => {
  const sdk = getSDKInstance();
  // await genAddressRegistrations(sdk);
  // await genTestDeposits(sdk);
  await genTestWithdrawals(sdk);
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
