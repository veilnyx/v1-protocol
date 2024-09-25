import { parseEther, parseUnits, zeroAddress } from "viem";
import { Core } from "@zkfi-tech/core";
import { TransactionType } from "@zkfi-tech/shared-types";
import { fixture, generateTestTransactions, mockNotes } from "./fixture";

const {
    assets: { testnetUSDT, testnetCRVUSD },
    sender: { account: senderAccount, pubAddress: senderPubAddress },
    receiver: { account: receiverAccount },
} = fixture;

export const reqs = {
    /**
    swap_1_testnet_weth_to_usdc: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress
    },
    swap_1_testnet_weth_to_usdc_via_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8", // adaptor to which the ZkFi Convertor will call to execute swap
        revokerId: 0,
        feeAssetId: testnetWeth,
        viaBundler: true,
        paymaster:
            `0x${"03E98aE18908eBc2Fe82e646E4DFB628963383c1"}` as `0x${string}`,
        payload:
            "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`, // refund: pool address (address(0))
    },
    stake_2_orig_usde_on_ethena: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUsdc],
        values: [parseUnits("2", 6)],
        to: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1", // adaptor addr. which the ZkFi adaptor handler will call to execute this convert req
        revokerId: 0,
        feeAssetId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
        payload:
            "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x{string}`, // refund: pool address (address(0)), outToken: USDe
    },
    stake_1_testnet_weth: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: "0x" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress
    },
    stake_1_testnet_weth_via_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: testnetWeth,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: "0x" as `0x${string}`,
        revokerId: 0,
        viaBundler: true,
        paymaster: "0x03E98aE18908eBc2Fe82e646E4DFB628963383c1" as `0x${string}`,
    },
    lend_1_aave_weth: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [aaveWethUnderlying],
        values: [parseEther("1")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 0 (supply)
        payload: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    },
    supply_2_wantLPToken: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [wantLPToken],
        values: [parseEther("2")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 0 (supply)
        payload: "0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000092a14518434a46e88cb4c3918ad33b3344099e02" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    }
        */
    supply_2_usdt_crvUsd_on_curve: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUSDT, testnetCRVUSD],
        values: [parseUnits("2", 6), parseUnits("2", 6)],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: address pool: 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4, action: 0 (supply)
        payload: "0x000000000000000000000000390f3595bca2df7d23783dfd126427cceb997bf40000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    }

};

export const genTestCallAdaptors = async (sdk: Core) => {
    await mockNotes("deposit_2_testnet_usdt_crvusd", sdk);
    await generateTestTransactions(reqs, sdk);
};
