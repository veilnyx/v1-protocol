// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Mempool} from "src/core/Mempool.sol";
import {MempoolProxy} from "src/core/MempoolProxy.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PreVerificationDetails} from "src/core/Mempool.sol";

contract MempoolTest is PoolTest {
    uint256 public constant INITIAL_MINT_AMT = 10000 ether;
    uint256 public constant DEPOSIT_AMT = 100 ether;

    modifier addSTXToMempool() {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        PreVerificationDetails
            memory preVerificationDetails = _loadPreVerificationDetails(
                "deposit_weth_tx_preVerificationEncodedStruct"
            );

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
        _;
    }

    function setUp() public {
        PoolTest._setUp();
        console.log("Mempool deployed: ", address(mempool));
        mempool.updatePoolAddress(address(pool));
    }

    ///////////// Add STX to Mempool Tests //////////////
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
        vm.expectEmit(true, true, true, false);
        emit Mempool.LockNotes(stxHashPI, stx.nullifiers);
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

    ///////////// Exit Mempool Tests //////////////

    function testExitMempool() public addSTXToMempool {
        uint256 stxHashPI = _loadPreVerificationDetails(
            "deposit_weth_tx_preVerificationEncodedStruct"
        ).publicInputs[2];

        uint256[] memory noteNullifiers = _loadShieldedTransaction(
            "deposit_weth_tx"
        ).nullifiers;

        bytes32 proofId = mempool.getProofId(stxHashPI);

        vm.expectEmit(true, true, true, true);
        emit Mempool.STXProcessed(stxHashPI, proofId, block.timestamp);
        vm.expectEmit(true, true, true, false);
        emit Mempool.UnlockNotes(stxHashPI, noteNullifiers);
        mempool.exitSTXFromMempool(stxHashPI);

        assertEq(IERC20(asset1.assetAddress).balanceOf(address(mempool)), 0);
        assertEq(
            IERC20(asset1.assetAddress).balanceOf(address(pool)),
            DEPOSIT_AMT
        );
        assertEq(address(mempool).balance, MEMPOOL_EXIT_FEES);
        assertEq(mempool.isSTXInMempool(stxHashPI), false);
    }

    function testRevertWhenExitingSTXTDoesNotExistInMempool() public {
        uint256 stxHashPI = _loadPreVerificationDetails(
            "deposit_weth_tx_preVerificationEncodedStruct"
        ).publicInputs[2];

        vm.expectRevert(
            abi.encodeWithSelector(Mempool.STXNotInMempool.selector, stxHashPI)
        );
        mempool.exitSTXFromMempool(stxHashPI);
    }

    function testRevertWhenExitingSTXTIsNotVerifiedYet()
        public
        addSTXToMempool
    {
        uint256 stxHashPI = _loadPreVerificationDetails(
            "deposit_weth_tx_preVerificationEncodedStruct"
        ).publicInputs[2];

        // Mocking the proof verification result to false when testing locally
        if (block.chainid == 31337) {
            mockNebraVerifier.setIsProofVerifiedResult(false);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                Mempool.STXNotPreVerified.selector,
                stxHashPI,
                mempool.getProofId(stxHashPI)
            )
        );
        mempool.exitSTXFromMempool(stxHashPI);
    }

    ///////////// Refund //////////////////
    function testDropFromMempool() public addSTXToMempool {
        uint256 stxHashPI = _loadPreVerificationDetails(
            "deposit_weth_tx_preVerificationEncodedStruct"
        ).publicInputs[2];

        uint256[] memory noteNullifiers = _loadShieldedTransaction(
            "deposit_weth_tx"
        ).nullifiers;

        // Mocking the proof verification result to false when testing locally
        if (block.chainid == 31337) {
            mockNebraVerifier.setIsProofVerifiedResult(false);
        }

        vm.expectEmit(true, true, true, true);
        emit Mempool.STXDropped(stxHashPI, address(this), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit Mempool.UnlockNotes(stxHashPI, noteNullifiers);

        mempool.dropFromMempool(stxHashPI);
        assert(IERC20(token1).balanceOf(address(this)) == INITIAL_MINT_AMT);
        assert(IERC20(token1).balanceOf(address(mempool)) == 0);
        assert(address(this).balance == MEMPOOL_EXIT_FEES);
        assert(address(mempool).balance == 0);
    }

    receive() external payable {
        console.log("Received native eth:", msg.value);
    }
}
