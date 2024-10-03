// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {EthenaAdaptor} from "src/adaptors/ETHENA/EthenaAdaptor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {IEthena} from "src/adaptors/Ethena/IEthena.sol";
import {console} from "forge-std/console.sol";

contract EthenaAdaptorTest is PoolTest {
    error CheckChainConfig();

    EthenaAdaptor ethenaAdaptor;
    address uniswapSwapRouter02;
    address public constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant ETHENA = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    uint256 public constant INITIAL_SUPPLY = 2 ether;
    address public user = 0x689EcF264657302052c3dfBD631e4c20d3ED0baB;

    function setUp() external {
        require(shouldTestRun(), "EthenaAdaptorTest: Chain not supported");
        PoolTest._setUp();

        // deploying Ethena adaptor
        ethenaAdaptor = new EthenaAdaptor(ETHENA, USDe, address(pool));

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Ethena adaptor deployed:", address(ethenaAdaptor));

        // Adaptor support on Labyrinth Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(address(ethenaAdaptor), true);
        vm.stopPrank();
    }

    function testEthenaAdaptorDeploy() external view {
        assert(address(ethenaAdaptor) != address(0));
    }

    function testUSDeStakingOnEthena() public {
        console.log("Initiating staking on Ethena");
        vm.startPrank(user);
        deal(USDe, user, INITIAL_SUPPLY);
        IERC20(USDe).approve(address(pool), INITIAL_SUPPLY);
        ShieldedTransaction memory ztxDeposit = _loadShieldedTransaction(
            "deposit_2_testnet_usde"
        );
        pool.transact(ztxDeposit);
        _processCommitmentTreeQueue();

        uint256 poolsUSDeBalBeforeStaking = IERC20(ETHENA).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory ztxStake = _loadShieldedTransaction(
            "stake_2_orig_usde_on_ethena"
        );
        pool.transact(ztxStake);
        vm.stopPrank();

        // Asserts
        uint256 poolsUSDeBalPostStake = IERC20(ETHENA).balanceOf(address(pool));
        console.log("Pool ETHENA bal before swap:", poolsUSDeBalBeforeStaking);
        console.log("Pool ETHENA bal after swap:", poolsUSDeBalPostStake);
        assert(poolsUSDeBalPostStake > poolsUSDeBalBeforeStaking);
    }

    /**
    function testsUSDeUnStakingOnEthena() public {
        console.log("Initiating unstaking on Ethena");
        vm.startPrank(user);
        deal(USDe, user, INITIAL_SUPPLY);
        IERC20(USDe).transfer(address(ethenaAdaptor), INITIAL_SUPPLY);

        uint24[] memory inAssetIds = new uint24[](1);
        inAssetIds[0] = pool.getAsset(USDe).id;

        uint256[] memory inValues = new uint256[](1);
        inValues[0] = INITIAL_SUPPLY;

        // Staking
        ethenaAdaptor.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: abi.encode(address(0))
        });
        vm.stopPrank();
        console.log("Staking done!");
        uint256 sUSDeBalAfterStaking = IERC20(ETHENA).balanceOf(
            address(ethenaAdaptor)
        );
        console.log("ETHENA received:", sUSDeBalAfterStaking);

        // will increament timestamp by the cool down duration since user will only be able to unstake after this cooldown period. `Ethena::coolDownDuration()`
        uint24 coolDownDuration = IEthena(ETHENA).cooldownDuration();
        vm.warp(block.timestamp + coolDownDuration + 1 hours);
        inAssetIds[0] = pool.getAsset(ETHENA).id;
        inValues[0] = sUSDeBalAfterStaking;

        // Unstaking
        console.log("Unstaking now!!");
        ethenaAdaptor.handleAssets({
            inAssetIds: inAssetIds,
            inValues: inValues,
            payload: abi.encode(user)
        });

        // Asserts
        uint256 sUSDeBalPostUnStaking = IERC20(ETHENA).balanceOf(
            address(ethenaAdaptor)
        );
        uint256 USDeBalPostUnStaking = IERC20(USDe).balanceOf(user);
        console.log("Pool ETHENA bal after unstaking:", sUSDeBalPostUnStaking);
        console.log("Pool USDe bal after unstaking:", USDeBalPostUnStaking);
        assert(sUSDeBalPostUnStaking == 0);
        assert(USDeBalPostUnStaking > 0);
    }
     */

    /// @dev Only allowing Lido tests to run on Holesky testnet and ETH mainnet. More chains can be added.
    function shouldTestRun() internal view returns (bool) {
        if (block.chainid != 1) {
            console.log(
                "Skipping Ethena adaptor tests on the current chain as Ethena protocol may not be deployed. To run Ethena tests, kindly run the tests on the ETH Mainnet fork. Ref: https://ETHENA-labs.gitbook.io/ETHENA-labs/solution-design/key-addresses"
            );
            return false;
        }
        return true;
    }
}
