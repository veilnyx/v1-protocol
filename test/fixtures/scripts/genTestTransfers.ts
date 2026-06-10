import { parseEther, zeroAddress } from "viem";
import { Core } from "@labyrinthac/core";
import { TransactionType } from "@labyrinthac/shared-types";
import { fixture, generateTestTransactions, generateTestTxsWithOutsourcedProofVerification, mockNotes, generatePackedUserOps, PAYMASTER_ADDR_FIXTURE } from "./fixture";

const {
	assets: { weth, usdc },
	sender: { account: senderAccount, pubAddress: senderPubAddress },
	receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
	transfer_500_weth_with_weth_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: weth,
		revokerId: 0,
	}
	/**,
	transfer_20_weth_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("20")],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
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
	}
	/**,
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
	transfer_20_weth_with_weth_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("20")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
		feeAssetId: weth,
		revokerId: 0
	},
	transfer_1000_weth_with_usdc_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("1000")],
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
