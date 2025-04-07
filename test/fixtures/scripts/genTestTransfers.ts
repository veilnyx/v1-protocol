import { parseEther, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes, generatePackedUserOps } from "./fixture";

const {
	assets: { weth, usdc },
	sender: { account: senderAccount, pubAddress: senderPubAddress },
	receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
	transfer_100_weth_with_weth_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("99.998")], // 99.998 to account for 0.002 fee and preventing use of transact22 (no refund notes) since transact22 circuit is not supporting UHF yet
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster:
			`0x${"0beEbd452688b33EF0021261d93D3c3A04916598"}` as `0x${string}`,
		feeAssetId: weth,
		revokerId: 0,
	}
	/**,
	transfer_100_weth_without_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("100")],
		feeAssetId: 0,
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: false,
		paymaster: zeroAddress,
		revokerId: 0,
	},
	transfer_500_weth_with_usdc_fee: {
		type: TransactionType.TRANSFER,
		assetIds: [weth],
		values: [parseEther("500")],
		to: receiverAccount.shieldedAddress.pack(),
		viaBundler: true,
		paymaster:
			`0x${"03E98aE18908eBc2Fe82e646E4DFB628963383c1"}` as `0x${string}`,
		feeAssetId: usdc,
		revokerId: 0,
	},
   */
};

export const genTestTransfers = async (sdk: Core) => {
	await mockNotes("deposit_weth_tx", sdk);
	await generateTestTransactions(reqs, sdk);
};

export const genTransferPackedUserOp = async (sdk: Core) => {
	await mockNotes("deposit_weth_tx", sdk);
	const [name, req] = Object.entries(reqs)[0];
	console.log("req to userop:", req);
	await generatePackedUserOps(name, req, sdk);
}
