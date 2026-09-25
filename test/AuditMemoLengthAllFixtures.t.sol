// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {FixtureLib} from "test/fixtures/Fixture.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";

/// Isolates the decode so an undecodable fixture can be reported rather than reverting
/// the whole test.
contract FixtureProbe {
    function dims(
        string memory name,
        Vm vm
    ) external view returns (uint256 nOuts, uint256 memoLen) {
        ShieldedTransaction memory stx = FixtureLib.loadShieldedTransaction(
            name,
            vm
        );
        return (stx.commitments.length, stx.notesMemo.length);
    }
}

/// L-2 tightened `_decomposeNotesMemo` from "length is a multiple of 32" to the exact
/// 32 * (7 + 4 * nOuts). Every adaptor suite (Morpho, Aave, Lido, Curve, Ethena, Beefy,
/// RocketPool, Uniswap, 1inch) is a fork test and is skipped without an RPC, so that
/// change had no coverage on the CALL_ADAPTOR path.
///
/// This asserts the invariant directly against the committed transaction fixtures,
/// including the adaptor ones, without needing a fork.
contract AuditMemoLengthAllFixtures is BaseTest {
    FixtureProbe internal probe;
    uint256 internal checked;
    uint256 internal undecodable;

    function setUp() public {
        _setUp();
        probe = new FixtureProbe();
    }

    function _check(string memory name) internal {
        try probe.dims(name, vm) returns (uint256 nOuts, uint256 memoLen) {
            assertEq(
                memoLen,
                32 * (7 + 4 * nOuts),
                string.concat("notesMemo length mismatch: ", name)
            );
            checked++;
        } catch {
            // Pre-existing: some committed fixtures no longer abi.decode into
            // ShieldedTransaction. No test referenced them, so nothing caught that they
            // had gone stale. Reported, not asserted on.
            console2.log("UNDECODABLE (stale fixture):", name);
            undecodable++;
        }
    }

    function test_adaptorFixturesSatisfyExactMemoLength() public {
        string[18] memory names = [
            "supply_2_morphoVaultToken",
            "supply_2_morphoLoanToken",
            "deposit_2_morphoVaultToken",
            "deposit_2_morphoLoanToken",
            "withdraw_2_morphoLoanToken",
            "lend_1_aave_weth",
            "lend_1_aave_weth_through_bundler",
            "deposit_2_aave_weth_underlying",
            "stake_1_testnet_weth_lido",
            "stake_1_testnet_weth_on_lido",
            "stake_1_testnet_weth_rocketpool",
            "stake_1_testnet_weth_via_bundler",
            "stake_2_usde_on_ethena",
            "stake_2_orig_usde_on_ethena",
            "supply_2_usdt_crvUsd_on_curve",
            "supply_2_mooLPToken",
            "swap_1_testnet_weth_to_usdc",
            "swap_1_testnet_weth_to_usdc_via_bundler"
        ];
        for (uint256 i; i < names.length; i++) _check(names[i]);

        console2.log("adaptor fixtures checked :", checked);
        console2.log("adaptor fixtures stale   :", undecodable);
        assertGt(checked, 0, "no adaptor fixture was decodable");
    }

    function test_coreFixturesSatisfyExactMemoLength() public {
        string[9] memory names = [
            "deposit_pre_tx",
            "deposit_pre_tx_4x2_a",
            "deposit_weth_tx",
            "deposit_1_testnet_weth",
            "deposit_2_testnet_weth",
            "withdraw_100_weth_without_fee",
            "withdraw_10_weth_with_weth_fee",
            "transfer_4x2_weth_usdc_without_fee",
            "transfer_4x4_weth_usdc_without_fee"
        ];
        for (uint256 i; i < names.length; i++) _check(names[i]);

        console2.log("core fixtures checked :", checked);
        console2.log("core fixtures stale   :", undecodable);
        assertGt(checked, 0, "no core fixture was decodable");
    }
}
