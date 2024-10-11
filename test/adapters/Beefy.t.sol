// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {BeefyV7Adaptor as BeefyAdp} from "src/adaptors/beefy-v7/BeefyV7Adaptor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {console} from "forge-std/Test.sol";

contract BeefyAdaptorTest is PoolTest {
    using SafeERC20 for IERC20;
    error CheckChainConfig();

    BeefyAdp beefyAdp;
    address public constant wantLPToken =
        0x57064F49Ad7123C92560882a45518374ad982e85;
    address public constant mooToken =
        0xBF7fc2A3d96d80f47b3b89BE84afe10376CE96A5;
    address public constant beefyVault =
        0xBF7fc2A3d96d80f47b3b89BE84afe10376CE96A5;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;
    uint256 public constant INITIAL_SUPPLY = 2 ether;

    function setUp() external {
        require(shouldTestRun(), "BeefyAdpTest: Chain not supported");
        PoolTest._setUp();

        // deploying Ethena adaptor
        beefyAdp = new BeefyAdp(address(pool));

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Beefy adaptor deployed:", address(beefyAdp));

        // Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(beefyAdp), true);
        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = wantLPToken;
        assetAddresses[1] = mooToken;
        pool.addAssets(assetType, assetAddresses);
        vm.stopPrank();
    }

    function testBeefyAdaptorDeploy() external view {
        assert(address(beefyAdp) != address(0));
    }

    function testSupplyInBeefyVault() public {
        console.log("Initiating supply on Beefy");
        vm.startPrank(user);
        deal(wantLPToken, user, INITIAL_SUPPLY);
        IERC20(wantLPToken).forceApprove(address(pool), INITIAL_SUPPLY);

        ShieldedTransaction memory depositStx = _loadShieldedTransaction(
            "deposit_2_wantLPToken"
        );
        pool.transact(depositStx);
        _processCommitmentTreeQueue();

        ShieldedTransaction memory supplyInBeefyStx = _loadShieldedTransaction(
            "supply_2_wantLPToken"
        );
        pool.transact(supplyInBeefyStx);
        vm.stopPrank();

        console.log("Staking done!");
        uint256 mooTokenBal = IERC20(mooToken).balanceOf(address(pool));
        console.log("mooTokens received:", mooTokenBal);
        assert(mooTokenBal > 0);
        // assertGreaterThan(mooTokenBal, 0);
    }

    function testWithdrawInBeefyVault() public {
        console.log("Initiating withdraw on Beefy");
        vm.startPrank(user);
        deal(mooToken, user, INITIAL_SUPPLY);
        IERC20(mooToken).forceApprove(address(pool), INITIAL_SUPPLY);

        ShieldedTransaction memory depositStx = _loadShieldedTransaction(
            "deposit_2_mooLPToken"
        );
        pool.transact(depositStx);
        _processCommitmentTreeQueue();

        ShieldedTransaction memory supplyInBeefyStx = _loadShieldedTransaction(
            "supply_2_mooLPToken"
        );
        pool.transact(supplyInBeefyStx);
        vm.stopPrank();

        console.log("Staking done!");
        uint256 wantTokenBal = IERC20(wantLPToken).balanceOf(address(pool));
        console.log("wantTokens received:", wantTokenBal);
        assert(wantTokenBal > 0);
    }

    function testDepositInBeefyVaultDirectly() public {
        console.log("Initiating supply on Beefy");
        vm.startPrank(user);
        deal(wantLPToken, user, INITIAL_SUPPLY);
        IERC20(wantLPToken).transfer(address(beefyAdp), INITIAL_SUPPLY);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(wantLPToken).id;
        uint256[] memory inValues = new uint256[](1);
        inValues[0] = INITIAL_SUPPLY;
        bytes memory payload = abi.encode(uint8(0), beefyVault);

        // Supplying
        beefyAdp.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: payload
        });
        vm.stopPrank();
        console.log("Staking done!");
        uint256 mooTokenBal = IERC20(mooToken).balanceOf(address(beefyAdp));
        console.log("mooTokens received:", mooTokenBal);
        assert(mooTokenBal > 0);
    }

    function testWithdrawInBeefyVaultDirectly() public {
        console.log("Initiating withdraw on Beefy");
        vm.startPrank(user);
        deal(mooToken, user, INITIAL_SUPPLY);
        IERC20(mooToken).transfer(address(beefyAdp), INITIAL_SUPPLY);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(mooToken).id;
        uint256[] memory inValues = new uint256[](1);
        inValues[0] = INITIAL_SUPPLY;
        bytes memory payload = abi.encode(uint8(1), beefyVault);

        // Supplying
        beefyAdp.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: payload
        });
        vm.stopPrank();
        console.log("Withdrawing done!");
        uint256 lpTokenBal = IERC20(wantLPToken).balanceOf(address(beefyAdp));
        console.log("lpToken received:", lpTokenBal);
        assert(lpTokenBal > 0);
    }

    /**

    /**
    function testsUSDeUnStakingOnEthena() public {
        console.log("Initiating unstaking on Ethena");
        vm.startPrank(user);
        deal(USDe, user, INITIAL_SUPPLY);
        IERC20(USDe).transfer(address(beefyAdp), INITIAL_SUPPLY);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(USDe).id;

        uint256[] memory inValues = new uint256[](1);
        inValues[0] = INITIAL_SUPPLY;

        // Staking
        beefyAdp.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: abi.encode(address(0))
        });
        vm.stopPrank();
        console.log("Staking done!");
        uint256 sUSDeBalAfterStaking = IERC20(sUSDe).balanceOf(
            address(beefyAdp)
        );
        console.log("sUSDe received:", sUSDeBalAfterStaking);

        // will increament timestamp by the cool down duration since user will only be able to unstake after this cooldown period. `Ethena::coolDownDuration()`
        uint24 coolDownDuration = IEthena(ETHENA).cooldownDuration();
        vm.warp(block.timestamp + coolDownDuration + 1 hours);
        inAssetIds[0] = pool.getAsset(sUSDe).id;
        inValues[0] = sUSDeBalAfterStaking;

        // Unstaking
        console.log("Unstaking now!!");
        beefyAdp.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: abi.encode(user)
        });

        // Asserts
        uint256 sUSDeBalPostUnStaking = IERC20(sUSDe).balanceOf(
            address(beefyAdp)
        );
        uint256 USDeBalPostUnStaking = IERC20(USDe).balanceOf(user);
        console.log("Pool sUSDe bal after unstaking:", sUSDeBalPostUnStaking);
        console.log("Pool USDe bal after unstaking:", USDeBalPostUnStaking);
        assert(sUSDeBalPostUnStaking == 0);
        assert(USDeBalPostUnStaking > 0);
    }
     */

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 1) {
            console.log(
                "Skipping Beefy adaptor tests on the current chain as Beefy protocol may not be deployed. To run Beefy tests, kindly run the tests on the ETH Mainnet fork. Ref: https://ETHENA-labs.gitbook.io/ETHENA-labs/solution-design/key-addresses"
            );
            return false;
        }
        return true;
    }
}
