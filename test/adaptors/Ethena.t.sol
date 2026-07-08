// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {EthenaAdaptor} from "src/adaptors/ethena/EthenaAdaptor.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {IEthena} from "src/adaptors/ethena/IEthena.sol";
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
        if (!shouldTestRun()) {
            vm.skip(true);
        }

        PoolTest._setUp();

        // deploying Ethena adaptor
        ethenaAdaptor = new EthenaAdaptor(IEthena(ETHENA), IERC20(USDe), pool);

        /// @dev update convert req fixture with this adaptor addr as `to`
        console.log("Ethena adaptor deployed:", address(ethenaAdaptor));

        // Whitelist the hardcoded adaptor address used in fixture ZK proofs
        // and etch the dynamically deployed adaptor's runtime code at that address
        address fixtureAdaptorAddr = 0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8;
        vm.etch(fixtureAdaptorAddr, address(ethenaAdaptor).code);

        // Adaptor support on Veilnyx Protocol
        address poolOwner = pool.owner();
        vm.startPrank(poolOwner);
        pool.addAdaptorSupport(IAdaptorHandler(fixtureAdaptorAddr), true);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = USDe;
        assetAddresses[1] = ETHENA;
        uint8[] memory precisions = new uint8[](2);
        precisions[0] = 18;
        precisions[1] = 18;

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

    function testEthenaAdaptorDeploy() external view {
        assert(address(ethenaAdaptor) != address(0));
    }

    function testUSDeStakingOnEthena() public {
        console.log("Initiating staking on Ethena");
        vm.startPrank(user);
        deal(USDe, user, INITIAL_SUPPLY);
        IERC20(USDe).approve(address(pool), INITIAL_SUPPLY);
        ShieldedTransaction memory ztxDeposit = _loadShieldedTransaction(
            "deposit_2_usde"
        );
        pool.transact(ztxDeposit);
        _processCommitmentTreeQueue();

        uint256 poolsUSDeBalBeforeStaking = IERC20(ETHENA).balanceOf(
            address(pool)
        );

        ShieldedTransaction memory ztxStake = _loadShieldedTransaction(
            "stake_2_usde_on_ethena"
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
     * Unstaking not supported due to the cool down period required by Ethena before unstaking, making it a non-atomic tx. User's will have to unstake from Ethena's UI after withdrawing their `sUSDe` from Veilnyx.
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
