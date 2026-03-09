import { parseEther, parseUnits, zeroAddress, encodeAbiParameters } from "viem";
import { Core } from "@labyrinthac/core";
import { TransactionType } from "@labyrinthac/shared-types";
import { fixture, generateTestTransactions, mockNotes, PAYMASTER_ADDR_FIXTURE } from "./fixture";

const {
    assets: { testnetWeth, testnetUsdc, beefyWantLPToken, beefyMooToken },
    sender: { account: senderAccount, pubAddress: senderPubAddress },
    receiver: { account: receiverAccount },
} = fixture;

enum Action {
    SUPPLY = 0,
    WITHDRAW = 1
}

export const reqs = {
    withdraw_2_mooLPToken: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [beefyMooToken],
        values: [parseEther("2")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 1 (withdraw)
        payload: "0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000014E0be19De3118b5b29842dd1696a2A98EB9Db" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    }/**,
    supply_2_wantLPToken: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [beefyWantLPToken],
        values: [parseEther("2")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 0 (supply)
        payload: "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014E0be19De3118b5b29842dd1696a2A98EB9Db" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    },
    lend_1_aave_weth: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 0 (supply)
        paymaster: zeroAddress,
        revokerId: 0,
        viaBundler: false
    },
    swap_1_testnet_weth_to_usdc_via_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8", // adaptor to which the ZkFi Convertor will call to execute swap
        revokerId: 0,
        feeAssetId: testnetWeth,
        viaBundler: true,
        paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
        payload:
            "0x000000000000000000000000000000000000000000000000000000000001000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`, // refund: pool address (address(0))
    },
    lend_1_aave_weth_through_bundler: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetWeth],
        values: [parseEther("1")],
        feeAssetId: testnetUsdc,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: action: 0 (supply)
        payload: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: true,
        paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,

    }
    /**
    withdraw_2_morphoLoanToken: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [morphoVaultToken],
        values: [parseEther("2")],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: refund: pool address (address(0)), outToken: testnetUsdc
        payload: encodeAbiParameters(
            [{
                type: "uint8",
                name: "action"
            }, {
                type: "address",
                name: "morphoVault"
            }],
            [Action.WITHDRAW, '0x2371e134e3455e0593363cBF89d3b6cf53740618']
        ),
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress
    },
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
        paymaster: PAYMASTER_ADDR_FIXTURE as `0x${string}`,
    },
    supply_5_usdt_crvUsd_on_curve: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUsdt, testnetCrvUsd],
        values: [parseUnits("5", 6), parseUnits("5", 18)],
        feeAssetId: 0,
        // adaptor to which the ZkFi AdaptorHandler will call to execute swap
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8",
        // payload:: address pool: 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4, action: 0 (supply)
        payload: "0x000000000000000000000000390f3595bca2df7d23783dfd126427cceb997bf40000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`,
        revokerId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
    },
    stake_2_orig_usde_on_ethena: {
        type: TransactionType.CALL_ADAPTER,
        assetIds: [testnetUsde],
        values: [parseEther("2")],
        to: "0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8", // adaptor addr. which the ZkFi adaptor handler will call to execute this convert req
        revokerId: 0,
        feeAssetId: 0,
        viaBundler: false,
        paymaster: zeroAddress,
        payload: "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`
    }
*/
};

// Uses notes from deposit_aaveWeth_testnetUsdc
export const genTestCallAdaptors = async (sdk: Core) => {
    await mockNotes("deposit_2_mooLPToken", sdk);
    await generateTestTransactions(reqs, sdk);
};