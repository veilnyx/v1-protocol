import { genAddressRegistrations, genAddrRegWithOutsourceProofVerification } from "./genTestAddressRegistration";
import { genTestDeposits, genTestDepositsWithOutsourceProofVerification } from "./genTestDeposits";
import { genTestWithdrawals } from "./genTestWithdrawals";
import { genTestTransfers, genTestTransfersWithOutsourceProofVerification, genTransferPackedUserOp, genTransferPackedUserOpPreVerified } from "./genTestTransfers";
import { genTestCallAdaptors } from './genTestCallAdaptor';

import { getSDKInstance } from "./sdk";
import {
	genTreeUpdateData,
	genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

const main = async () => {
	const { sdk, nebraClient } = await getSDKInstance();
	// @dev Deposit notes are reused across tests (transfer, withdrawal, adaptor). Only regenerate when new assets are needed, as overriding existing notes will break dependent tests fixtures. Commit hash containing the deposit tx fixtures on which followup tx fixtures depend: fe9cfaa37bb522f0221f6e86f043ec6b6cf6ea8f
	// await genTestDeposits(sdk);
	// await genTestDepositsWithOutsourceProofVerification(sdk, nebraClient);
	// await genTestTransfers(sdk);
	// await genTestTransfersWithOutsourceProofVerification(sdk, nebraClient);
	// await genTransferPackedUserOp(sdk, nebraClient);
	// await genAddressRegistrations(sdk);
	// await genAddrRegWithOutsourceProofVerification(sdk, nebraClient);
	// await genTestDepositsWithOutsourceProofVerification(sdk, nebraClient);
	// await genTestTransfersWithOutsourceProofVerification(sdk, nebraClient);
	await genTestWithdrawals(sdk);
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
