// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AssetType} from "src/libraries/AssetLogic.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {COMMITMENT_TREE_DEPTH} from "src/base/Constants.sol";
import {console2} from "forge-std/console2.sol";

/// @title The shielded path, end to end: a REAL proof through the REAL Pool
/// @notice Every other perp-vault suite calls the adaptor directly. This one
///         spends an actual ZK-proven note (`perp_vault_deposit_10_usdc`)
///         through `pool.transact`, which is the only path users ever take. The
///         proof binds the adaptor address and payload at generation time, so the
///         runtime code is deployed AT those addresses (constructor included —
///         a bare etch would leave storage zeroed, and depositCap 0 refuses
///         every deposit).
contract PerpVaultFixtureTest is PoolTest {
    // Fixed addresses the fixture proof commits to (genTestCallAdaptor.ts).
    address constant FIXTURE_ADAPTOR = 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE;
    address constant FIXTURE_VAULT = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;

    PerpVault vault;

    function setUp() external {
        PoolTest._setUp();

        // The vault's HyperCore does not exist on this chain; a flat empty
        // account is mocked. The deposit path reads position (for notional == 0),
        // margin summary and spot balance (for totalAssets); with no position it
        // never touches prices.
        vm.mockCall(
            HyperCore.POSITION,
            abi.encode(FIXTURE_VAULT, uint32(3)),
            abi.encode(HyperCore.Position(0, 0, 0, 10, false))
        );
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), FIXTURE_VAULT),
            abi.encode(HyperCore.MarginSummary(0, 0, 0, int64(0)))
        );
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(FIXTURE_VAULT, uint64(0)),
            abi.encode(HyperCore.SpotBalance(0, 0, 0))
        );

        // Runtime code at the proof-bound addresses, constructors and all.
        // asset2 is the fixture USDC (asset id 65538 by registration order).
        StdCheats.deployCodeTo(
            "PerpVault.sol:PerpVault",
            abi.encode(
                IERC20(asset2.assetAddress),
                uint64(0),
                uint32(3),
                true,
                uint256(20_000),
                "BTC Long 2x",
                "vBTC2L",
                address(this)
            ),
            FIXTURE_VAULT
        );
        StdCheats.deployCodeTo(
            "PerpVaultAdaptor.sol:PerpVaultAdaptor", abi.encode(pool), FIXTURE_ADAPTOR
        );
        vault = PerpVault(FIXTURE_VAULT);

        // Adaptor and asset support, exactly as DeployPerpVault.s.sol registers
        // them: share and CLAIM both 18dp.
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(IAdaptorHandler(FIXTURE_ADAPTOR), true);
        address[] memory addrs = new address[](2);
        addrs[0] = FIXTURE_VAULT;
        addrs[1] = address(vault.claimToken());
        uint8[] memory precisions = new uint8[](2);
        precisions[0] = 18;
        precisions[1] = 18;
        pool.addAssets(
            AssetType.ERC20,
            _toAssetInitParams(addrs, precisions, _mockFeedsArray(2))
        );
        vm.stopPrank();
    }

    /// @dev The full user path: shielded USDC note -> CALL_ADAPTOR -> vault mints
    ///      shares to the Pool -> the Pool commits the share note. The proof was
    ///      generated against deposit_pre_tx's USDC half, so that deposit runs
    ///      first, exactly as it did at fixture-generation time.
    function testShieldedDepositMintsSharesThroughRealPool() public {
        _makePreDeposit();

        // The fixture run inserted THREE transactions into the shared tree, in
        // order: deposit_pre_tx, this withdrawal, then the perp deposit. The perp
        // proof commits to the tree root AFTER the withdrawal's change
        // commitments, so the withdrawal must be replayed too — skipping it is an
        // UnknownCommitmentTreeRoot at transact.
        ShieldedTransaction memory wtx =
            _loadShieldedTransaction("withdraw_10_weth_with_weth_fee");
        pool.transact(wtx);

        // The SDK's generation-side tree carried one leaf on-chain replay does
        // not queue: the 2-2 circuit's padded second output. Same leaves through
        // _processCommitmentTreeQueue therefore land one index apart and the
        // roots diverge (verified: the root after pre_tx replays EXACTLY, the
        // divergence begins at this flush). The perp proof states the root it
        // was proven against, so flush this batch TO that root — the tree-update
        // verifier is mocked in PoolTest, everything else on the path is real:
        // real transact proof, real nullifiers, real adaptor, real vault.
        ShieldedTransaction memory perpStx =
            _loadShieldedTransaction("perp_vault_deposit_10_usdc");
        _flushQueueToRoot(perpStx.commitmentTreeRoot);

        uint256 potBefore = IERC20(asset2.assetAddress).balanceOf(address(pool));
        assertEq(vault.balanceOf(address(pool)), 0, "no shares yet");

        pool.transact(perpStx);

        // 10 USDC left the Pool for the vault...
        assertEq(
            potBefore - IERC20(asset2.assetAddress).balanceOf(address(pool)),
            10e6,
            "the note's 10 USDC moved to the vault"
        );
        assertEq(vault.idleAssets(), 10e6, "vault holds the deposit");

        // ...and the Pool holds the shares the note commitment now represents.
        uint256 shares = vault.balanceOf(address(pool));
        assertGt(shares, 0, "Pool custodies the share tokens");
        // First deposit at NAV 1.0 less the 10bp entry fee.
        assertApproxEqRel(shares, 9.99e18, 1e12, "priced at NAV 1.0 minus entry fee");

        console2.log("shares minted to Pool:", shares);
        console2.log("nav after           :", vault.pricePerShare());
    }

    /// @dev Flush the queued commitments while forcing the resulting root, for
    ///      batches where the generation-side tree and the on-chain queue differ
    ///      by SDK-internal padding leaves. Subtrees are zeroed: acceptable only
    ///      because no later flush happens in this test.
    function _flushQueueToRoot(uint256 newRoot) internal {
        (uint32 sIdx, uint32 eIdx, , , ) = pool.getQueueRawState();
        uint256[COMMITMENT_TREE_DEPTH] memory subtrees;
        _mockVerifierResult(true);
        pool.updateCommitmentTree(
            TreeUpdateData({
                newRoot: newRoot,
                batchSize: eIdx - sIdx,
                newLevelSubtrees: subtrees,
                proof: bytes("")
            })
        );
        _mockVerifierReset();
    }
}
