import { genAddressRegistrations, genAddrRegWithOutsourceProofVerification } from "./genTestAddressRegistration";
import { genTestDeposits, genTestDepositsWithOutsourceProofVerification } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers, genTransferPackedUserOp } from "./genTestTransfers";
import { genTestCallAdaptors } from './genTestCallAdaptor';

import { getSDKInstance } from "./sdk";
import { Point, poseidonHash } from "@zkfi-tech/babyjubjub";
import { randomBigInt } from "@zkfi-tech/utils";
import {
	genTreeUpdateData,
	genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

const main = async () => {
	const { sdk, nebraClient, circuitIds } = await getSDKInstance();
	// await genTestDeposits(sdk);
	// await genTestTransfers(sdk);
	// await genTransferPackedUserOp(sdk, nebraClient, circuitIds);
	// await genAddressRegistrations(sdk);
	// await genAddrRegWithOutsourceProofVerification(sdk, nebraClient, circuitIds.register);
	await genTestDepositsWithOutsourceProofVerification(sdk, nebraClient, circuitIds.transact21);
	// await genTestWithdrawals(sdk);
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
