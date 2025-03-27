// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Mempool} from "src/core/Mempool.sol";
import {MempoolProxy} from "src/core/MempoolProxy.sol";
import {ShieldedTransaction, PreVerificationDetails} from "src/libraries/ShieldedTransaction.sol";

contract MempoolTest is PoolTest {
    Mempool public mempool;
    uint256 public constant MEMPOOL_EXIT_FEES = 45e13; // 500k gas @ 0.9 gwei = 0.00045 ETH
    address public immutable VERIFICATION_TRACKER_SERVICE = makeAddr("tracker");
    uint256 public constant INITIAL_MINT_AMT = 10000 ether;
    uint256 public constant DEPOSIT_AMT = 100 ether;
    address public nebraVerifier = makeAddr("nebra");

    function setUp() public {
        PoolTest._setUp();
        mempool = new Mempool();

        bytes memory initializeData = abi.encodeWithSelector(
            mempool.initialize.selector,
            address(pool),
            MEMPOOL_EXIT_FEES,
            VERIFICATION_TRACKER_SERVICE,
            nebraVerifier
        );

        MempoolProxy proxy = new MempoolProxy(address(mempool), initializeData);
        mempool = Mempool(address(proxy));
        console.log("Mempool deployed ");
    }

    function testAddStxToMempool() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        PreVerificationDetails
            memory preVerificationDetails = _loadPreVerificationDetails(
                "deposit_weth_tx_preVerificationEncodedStruct"
            );

        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        vm.expectEmit(true, true, true, false);
        emit Mempool.STXAddedToMempool(
            stxHashPI,
            address(this),
            keccak256(abi.encodePacked("random")),
            block.timestamp
        );
        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );

        assertEq(
            IERC20(asset1.assetAddress).balanceOf(address(mempool)),
            DEPOSIT_AMT
        );
    }

    function testRevertWhenSTXAndPIDontMatch() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        PreVerificationDetails
            memory preVerificationDetails = _loadPreVerificationDetails(
                "deposit_weth_tx_preVerificationEncodedStruct"
            );

        preVerificationDetails.publicInputs[2] = uint256(
            keccak256(abi.encodePacked("random"))
        );

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        vm.expectRevert(Mempool.InvalidStx.selector);
        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
    }

    function testRevertWhenDuplicateSTXAdded() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        PreVerificationDetails
            memory preVerificationDetails = _loadPreVerificationDetails(
                "deposit_weth_tx_preVerificationEncodedStruct"
            );

        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES * 2);

        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );

        vm.expectRevert(
            abi.encodeWithSelector(Mempool.DuplicateStx.selector, stxHashPI)
        );
        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
    }
}
