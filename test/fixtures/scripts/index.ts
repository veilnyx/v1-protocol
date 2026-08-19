import { genAddressRegistrations, genAddrRegWithOutsourceProofVerification } from "./genTestAddressRegistration";
import { genTestDeposits, genTestDeposits4x2 } from "./genTestDeposits";
import { genTestWithdrawals, genTestWithdrawalsFromReentrantTokenDeposit } from "./genTestWithdrawals";
import { genTestTransfers, genTestTransfersWith4Input2OutputNotes, genTestTransfersWith4Input4OutputNotes, genTestTransfersWithOutsourceProofVerification, genTransferPackedUserOp, genTransferPackedUserOpPreVerified } from "./genTestTransfers";
import { genTestCallAdaptors, genMorphoSupplyAdaptorTx, genMorphoWithdrawAdaptorTx } from './genTestCallAdaptor';

import { getSDKInstance } from "./sdk";
import { genHyperEvmTreeUpdate } from "./genHyperEvmTreeUpdate";
import {
	genTreeUpdateData,
	genTreeUpdateDataWithPartialQueue,
} from "./genTreeUpdateData";

const main = async () => {
	// getNebraClient is a function, not a value: only the *WithOutsourceProofVerification
	// generators need it, and resolving it reaches Sepolia. Destructuring a resolved
	// client here would make every generator depend on that RPC.
	const { sdk, getNebraClient } = await getSDKInstance();
	// @dev Deposit notes are reused across tests (transfer, withdrawal, adaptor). Only regenerate when new assets are needed, as overriding existing notes will break dependent tests fixtures. Commit hash containing the deposit tx fixtures on which followup tx fixtures depend: fe9cfaa37bb522f0221f6e86f043ec6b6cf6ea8f
	// HyperEVM testnet branch: the four generators the end-to-end script needs,
	// enabled in dependency order. Deposits must precede withdrawals because the
	// withdrawal spends the deposit's notes, and the tree update must come last
	// because it proves insertion of the commitments the deposit queues.
	// transact21 wasm is now compiled, so the original blocker is gone.
	await genAddressRegistrations(sdk);
	await genTestDeposits(sdk);
	// await genMorphoSupplyAdaptorTx(sdk);
	// await genMorphoWithdrawAdaptorTx(sdk);
	// await genTestDepositsWithOutsourceProofVerification(sdk, await getNebraClient());
	// await genTestTransfers(sdk);
	// await genTestDeposits4x2(sdk);
	// await genTestTransfersWith4Input2OutputNotes(sdk);
	// await genTestTransfersWith4Input4OutputNotes(sdk);
	// await genTestTransfersWithOutsourceProofVerification(sdk, await getNebraClient());
	// await genTransferPackedUserOp(sdk, await getNebraClient());
	// await genAddressRegistrations(sdk);
	// await genTestDepositsWithOutsourceProofVerification(sdk, await getNebraClient());
	// await genTestTransfersWithOutsourceProofVerification(sdk, await getNebraClient());
	await genTestWithdrawals(sdk);
	// await genTestWithdrawalsFromPreTxDeposit(sdk);
	// await genTestWithdrawalsFromReentrantTokenDeposit(sdk);
	// await genTestCallAdaptors(sdk);
	await genTreeUpdateData(sdk);
	await genHyperEvmTreeUpdate(sdk);
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
