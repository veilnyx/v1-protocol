import { genAddressRegistrations } from "./genTestAddressRegistration";
import { genTestDeposits } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers } from "./genTestTransfers";
import { getSDKInstance } from "./sdk";
import { Point, poseidonHash } from "@zkfi-tech/babyjubjub";
import { randomBigInt } from "@zkfi-tech/utils";
import { genTreeUpdateData, genTreeUpdateDataWhenQueueShort } from "./genTreeUpdateData";

const main = async () => {
  const sdk = getSDKInstance();
  await genAddressRegistrations(sdk);
  await genTestDeposits(sdk);
  // await genTestWithdrawals(sdk);
  // await genTestTransfers(sdk);
  // await genTreeUpdateData(sdk);
  // await genTreeUpdateDataWhenQueueShort(sdk);
  // const n = 10;
  // const leaves1 = Array.from({ length: n }, (_, i) =>
  //   poseidonHash([BigInt(i)])
  // ).map((v) => v.toString());
  // const leaves2 = Array.from({ length: n }, (_, i) =>
  //   poseidonHash([BigInt(i + 1)])
  // ).map((v) => v.toString());

  // console.log("leaves1", leaves1);
  // console.log("leaves2", leaves2);
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
