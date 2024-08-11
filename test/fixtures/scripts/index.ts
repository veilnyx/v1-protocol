import { genAddressRegistrations } from "./genTestAddressRegistration";
import { genTestDeposits } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers } from "./genTestTransfers";
import { getSDKInstance } from "./sdk";

const main = async () => {
  const sdk = getSDKInstance();
  await genAddressRegistrations(sdk);
  await genTestDeposits(sdk);
  await genTestWithdrawals(sdk);
  // await genTestTransfers(sdk);
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
