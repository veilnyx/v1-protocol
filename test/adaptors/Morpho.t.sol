// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {MorphoVaultAdaptor as MorphoAdp} from "src/adaptors/morpho/MorphoVaultAdaptor.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {console} from "forge-std/Test.sol";

contract MorphoAdaptorTest is PoolTest {
    using SafeERC20 for IERC20;
    error CheckChainConfig();

    MorphoAdp morphoAdp;
    address public constant loanToken =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH (18 decimals)
    address public constant vaultToken =
        0x2371e134e3455e0593363cBF89d3b6cf53740618;
    address public constant morphoVault =
        0x2371e134e3455e0593363cBF89d3b6cf53740618; // Gauntlet WETH Prime
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    uint256 public constant INITIAL_SUPPLY = 2 ether;

    function setUp() external {
        if (!shouldTestRun()) {
            vm.skip(true);
        }

        PoolTest._setUp();

        // deploying Ethena adaptor
        morphoAdp = new MorphoAdp(pool);

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Morpho adaptor deployed:", address(morphoAdp));

        // Whitelist the hardcoded adaptor address used in fixture ZK proofs
        // and etch the dynamically deployed adaptor's runtime code at that address
        address fixtureAdaptorAddr = 0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8;
        vm.etch(fixtureAdaptorAddr, address(morphoAdp).code);

        // Adaptor & asset support on Veilnyx Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(IAdaptorHandler(fixtureAdaptorAddr), true);
        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        // assetAddresses[0] = loanToken;
        assetAddresses[0] = vaultToken;
        uint8[] memory precisions = new uint8[](1);
        precisions[0] = 18;

        pool.addAssets(
            assetType,
            _toAssetInitParams(
                assetAddresses,
                precisions,
                _mockFeedsArray(assetAddresses.length)
            )
        );
        vm.stopPrank();
    }

    function testMorphoAdaptorDeploy() external view {
        assert(address(morphoAdp) != address(0));
    }

    function testSupplyInMorphoVault() public {
        console.log("Initiating supply on morpho");
        vm.startPrank(user);
        deal(loanToken, user, INITIAL_SUPPLY);
        IERC20(loanToken).forceApprove(address(pool), INITIAL_SUPPLY);

        ShieldedTransaction memory depositStx = _loadShieldedTransaction(
            "deposit_2_morphoLoanToken"
        );
        pool.transact(depositStx);
        _processCommitmentTreeQueue();

        ShieldedTransaction memory supplyStx = _loadShieldedTransaction(
            "supply_2_morphoLoanToken"
        );
        pool.transact(supplyStx);
        vm.stopPrank();

        console.log("Supplying done!");
        uint256 vaultTokenBal = IERC20(vaultToken).balanceOf(address(pool));
        console.log("morpho vault tokens received:", vaultTokenBal);
        assert(vaultTokenBal > 0);
    }

    function testWithdrawFromMorphoVault() public {
        console.log("Initiating withdraw on morpho");
        vm.startPrank(user);
        deal(vaultToken, user, INITIAL_SUPPLY);
        IERC20(vaultToken).forceApprove(address(pool), INITIAL_SUPPLY);

        ShieldedTransaction memory depositStx = _loadShieldedTransaction(
            "deposit_2_morphoVaultToken"
        );
        pool.transact(depositStx);
        _processCommitmentTreeQueue();

        ShieldedTransaction memory withdrawStx = _loadShieldedTransaction(
            "withdraw_2_morphoLoanToken"
        );
        pool.transact(withdrawStx);
        vm.stopPrank();

        console.log("Withdrawing done!");
        uint256 loanTokenBal = IERC20(loanToken).balanceOf(address(pool));
        console.log("loanTokens received:", loanTokenBal);
        assert(loanTokenBal > 0);
    }

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 1) {
            console.log(
                "Skipping Morpho adaptor tests on the current chain as morpho protocol may not be deployed. To run Morpho tests, kindly run the tests on the ETH Mainnet fork."
            );
            return false;
        }
        return true;
    }
}
