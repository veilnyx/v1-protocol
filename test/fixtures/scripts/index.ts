import { genAddressRegistrations, genAddrRegWithOutsourceProofVerification } from "./genTestAddressRegistration";
import { genTestDeposits, genTestDeposits4x2, reqsReentrant } from "./genTestDeposits";
import { genTestWithdrawals, genTestWithdrawalsFromReentrantTokenDeposit } from "./genTestWithdrawals";
import { genTestTransfers, genTestTransfersWith4Input2OutputNotes, genTestTransfersWith4Input4OutputNotes, genTestTransfersWithOutsourceProofVerification, genTransferPackedUserOp, genTransferPackedUserOpPreVerified } from "./genTestTransfers";
import { genTestCallAdaptors, genMorphoSupplyAdaptorTx, genMorphoWithdrawAdaptorTx } from './genTestCallAdaptor';

import { generateTestTransactions } from "./fixture";
import { getSDKInstance } from "./sdk";
import {
	genTreeUpdateData,
	genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

/// Generators that can be run by name, e.g.
///   FIXTURE_CIRCUITS=<prod circuits dir> pnpm test:prepare treeUpdate transfers
/// Deposit fixtures are spent by later fixtures (their notes are decrypted from the deposit
/// fixture), so regenerate a deposit only together with everything that spends it.
const named: Record<string, (sdk: any, nebraClient: any) => Promise<void>> = {
	treeUpdate: async (sdk) => {
		await genTreeUpdateData(sdk);
		await genTreeUpdateDataWithPartialQueue(sdk);
	},
	transfers: genTestTransfers, // spends deposit_pre_tx
	packedUserOp: genTransferPackedUserOp, // spends deposit_weth_tx
	deposits4x2: genTestDeposits4x2,
	transfers4x2: genTestTransfersWith4Input2OutputNotes, // spends deposits4x2
	transfers4x4: genTestTransfersWith4Input4OutputNotes, // spends deposits4x2
	reentrantDeposit: (sdk) => generateTestTransactions(reqsReentrant, sdk),
	reentrantWithdraw: genTestWithdrawalsFromReentrantTokenDeposit, // spends reentrantDeposit
};

const main = async () => {
	const { sdk, nebraClient } = await getSDKInstance();
	const picked = process.argv.slice(2);
	if (picked.length) {
		for (const name of picked) {
			if (!named[name]) throw new Error(`unknown generator ${name}; one of: ${Object.keys(named).join(", ")}`);
			console.log(`== ${name}`);
			await named[name](sdk, nebraClient);
		}
		return;
	}

	// @dev Deposit notes are reused across tests (transfer, withdrawal, adaptor). Only regenerate when new assets are needed, as overriding existing notes will break dependent tests fixtures. Commit hash containing the deposit tx fixtures on which followup tx fixtures depend: fe9cfaa37bb522f0221f6e86f043ec6b6cf6ea8f
	// await genTestDeposits(sdk); // already generated; transact21 wasm not compiled - only regenerate if assets change
	// await genMorphoSupplyAdaptorTx(sdk);
	// await genMorphoWithdrawAdaptorTx(sdk);
	// await genTestDepositsWithOutsourceProofVerification(sdk, nebraClient);
	// await genTestTransfers(sdk);
	// await genTestDeposits4x2(sdk);
	// await genTestTransfersWith4Input2OutputNotes(sdk);
	// await genTestTransfersWith4Input4OutputNotes(sdk);
	// await genTestTransfersWithOutsourceProofVerification(sdk, nebraClient);
	// await genTransferPackedUserOp(sdk, nebraClient);
	// await genAddressRegistrations(sdk);
	// await genTestDepositsWithOutsourceProofVerification(sdk, nebraClient);
	// await genTestTransfersWithOutsourceProofVerification(sdk, nebraClient);
	await genTestWithdrawals(sdk);
	// await genTestWithdrawalsFromPreTxDeposit(sdk);
	// await genTestWithdrawalsFromReentrantTokenDeposit(sdk);
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
