import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@veilnyx-sdk/core";
import { TransactionType } from "@veilnyx-sdk/shared-types";
import { fixture, generateTestTransactions, generateTestTxsWithOutsourcedProofVerification, mockNotes, mockNotesWithOffset, generatePackedUserOps, PAYMASTER_ADDR_FIXTURE } from "./fixture";

const {
	assets: { weth, usdc },
	sender: { account: senderAccount, pubAddress: senderPubAddress },
	receiver: { account: receiverAccount },
} = fixture;

const transferReq = (values: bigint, feeAssetId: number) => ({
	type: TransactionType.TRANSFER,
	assetIds: [weth],
	values: [values],
	to: receiverAccount.shieldedAddress.pack(),
	viaBundler: feeAssetId !== 0,
	paymaster: (feeAssetId !== 0 ? PAYMASTER_ADDR_FIXTURE : zeroAddress) as `0x${string}`,
	feeAssetId,
	revokerId: 0,
});

// Spend the deposit_pre_tx notes (PoolTest setUp deposits that fixture first).
// Used by PoolTransfer, PoolGuardrails, TvlGuard and PoolAdaptor.
export const reqs = {
	transfer_20_weth_without_fee: transferReq(parseEther("20"), 0),
	transfer_500_weth_without_fee: transferReq(parseEther("500"), 0),
	transfer_500_weth_with_weth_fee: transferReq(parseEther("500"), weth),
	// partial WETH note with a USDC fee: USDC change + WETH change + WETH receiver = 3 outputs
	transfer_500_weth_with_usdc_fee: transferReq(parseEther("500"), usdc),
	transfer_1000_weth_with_usdc_fee: transferReq(parseEther("1000"), usdc),
};

// Spends the deposit_weth_tx notes (ERC4337.t.sol deposits that fixture). Written together
// with its packed UserOperation by genTransferPackedUserOp.
export const reqsPackedUserOp = {
	transfer_20_weth_with_weth_fee: transferReq(parseEther("20"), weth),
};

// 4-input 4-output transfer reusing the same 4x2 pre-deposits.
// Transfer amounts exceed the single-note value (1000 each) so the SDK must
// select BOTH notes per asset — 4 real inputs, 4 outputs, exercising transact44.
export const reqs4x4 = {
	transfer_4x4_weth_usdc_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth, usdc],
		values: [parseEther("1500"), parseUnits("1500", 6)],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	},
};

// 4-input 2-output transfer consuming all notes from both 4x2 pre-deposits.
// Transfers 2000 WETH + 2000 USDC to receiver with no fee, producing exactly
// 2 output notes — exercising the transact42 circuit.
export const reqs4x2 = {
	transfer_4x2_weth_usdc_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth, usdc],
		values: [parseEther("2000"), parseUnits("2000", 6)],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	},
};

export const genTestTransfersWith4Input4OutputNotes = async (sdk: Core) => {
	// Same two deposits as the 4x2 case: notes at leafIndex 0,1 and 2,3.
	await mockNotes("deposit_pre_tx_4x2_a", sdk);
	await mockNotesWithOffset("deposit_pre_tx_4x2_b", sdk, 2);
	await generateTestTransactions(reqs4x4, sdk);
};

export const genTestTransfersWith4Input2OutputNotes = async (sdk: Core) => {
	const { commitmentTreeQueueSize: queueSize, zeroLeaf } = fixture;
	const zeroLeafBigInt = BigInt(zeroLeaf);

	// First deposit: notes land at leafIndex 0, 1
	await mockNotes("deposit_pre_tx_4x2_a", sdk);

	// deposit_pre_tx_4x2_a contributes 2 real leaves
	// This keeps the SDK commitment tree root in sync with the on-chain root after _processCommitmentTreeQueue.
	// for (let i = 2; i < batchSize; i++) {
	// 	// @ts-ignore
	// 	sdk.commitmentTreeSource.insert(zeroLeafBigInt);
	// }

	// Second deposit: notes land at leafIndex batchSize (2) onwards.
	// mockNotesWithOffset appends to existing notes instead of replacing them.
	await mockNotesWithOffset("deposit_pre_tx_4x2_b", sdk, 2);
	await generateTestTransactions(reqs4x2, sdk);
};

export const genTestTransfers = async (sdk: Core) => {
	await mockNotes("deposit_pre_tx", sdk);
	await generateTestTransactions(reqs, sdk);
};

export const genTestTransfersWithOutsourceProofVerification = async (sdk: Core, nebraClient: any) => {
	await mockNotes("deposit_weth_tx", sdk);
	await generateTestTxsWithOutsourcedProofVerification(reqs, sdk, nebraClient);
}

export const genTransferPackedUserOp = async (sdk: Core, nebraClient: any) => {
	await mockNotes("deposit_weth_tx", sdk);
	const [name, req] = Object.entries(reqsPackedUserOp)[0];
	console.log("req to userop:", req);
	await generatePackedUserOps(name, req, sdk, false, nebraClient);
}

export const genTransferPackedUserOpPreVerified = async (sdk: Core, nebraClient: any) => {
	await mockNotes("deposit_weth_tx", sdk);
	const [name, req] = Object.entries(reqsPackedUserOp)[0];
	console.log("req to userop:", req);
	await generatePackedUserOps(name, req, sdk, true, nebraClient);
}
