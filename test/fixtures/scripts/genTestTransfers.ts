import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@labyrinthac/core";
import { TransactionType } from "@labyrinthac/shared-types";
import { fixture, generateTestTransactions, generateTestTxsWithOutsourcedProofVerification, mockNotes, mockNotesWithOffset, generatePackedUserOps, PAYMASTER_ADDR_FIXTURE } from "./fixture";

const {
	assets: { weth, usdc },
	sender: { account: senderAccount, pubAddress: senderPubAddress },
	receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
	transfer_20_weth_with_weth_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("20")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: weth,
		revokerId: 0
	}
	/**
	transfer_20_weth_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("20")],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	}
	/**,
	transfer_1000_weth_with_usdc_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("1000")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: usdc,
		revokerId: 0,
	}
	/**,,
	transfer_500_weth_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	},
	transfer_500_weth_with_weth_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: weth,
		revokerId: 0,
	},
	transfer_500_weth_with_usdc_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")], // transfer partial WETH note to gen 3rd change note (USDC change + WETH change + WETH receiver = 3 outputs = transact24/transact44 circuits test)
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: usdc,
		revokerId: 0,
	},
	transfer_500_weth_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	}
	*/
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
	const [name, req] = Object.entries(reqs)[0];
	console.log("req to userop:", req);
	await generatePackedUserOps(name, req, sdk, false, nebraClient);
}

export const genTransferPackedUserOpPreVerified = async (sdk: Core, nebraClient: any) => {
	await mockNotes("deposit_weth_tx", sdk);
	const [name, req] = Object.entries(reqs)[0];
	console.log("req to userop:", req);
	await generatePackedUserOps(name, req, sdk, true, nebraClient);
}
