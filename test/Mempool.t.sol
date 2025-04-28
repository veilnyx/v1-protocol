// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IMempool} from "src/interfaces/IMempool.sol";
import {Mempool} from "src/core/Mempool.sol";
import {MempoolProxy} from "src/core/MempoolProxy.sol";
import {MempoolValidator} from "src/libraries/MempoolValidator.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PreVerificationDetails} from "src/core/Mempool.sol";
import {console} from "forge-std/console.sol";

contract MempoolTest is PoolTest {
    uint256 public constant INITIAL_MINT_AMT = 10000 ether;
    uint256 public constant DEPOSIT_AMT = 100 ether;

    ShieldedTransaction stx;
    PreVerificationDetails preVerificationDetails;

    modifier addSTXToMempool() {
        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
        _;
    }

    modifier addTransferSTXToMempool() {
        ShieldedTransaction memory transferStx = _loadShieldedTransaction(
            "transfer_20_weth_with_weth_fee"
        );
        PreVerificationDetails
            memory preVerificationDetailsForTransfer = _loadPreVerificationDetails(
                "transfer_20_weth_with_weth_fee_preVerificationEncodedStruct"
            );

        vm.prank(MOCK_GATEWAY);
        mempool.addSTXToMempool(transferStx, preVerificationDetailsForTransfer);
        _;
    }

    function _generateProofId(
        PreVerificationDetails memory preVerificationDetails_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    preVerificationDetails_.circuitId,
                    preVerificationDetails_.publicInputs
                )
            );
    }

    function setUp() public {
        PoolTest._setUp();
        console.log("Mempool deployed: ", address(mempool));
        mempool.updatePoolAddress(address(pool));

        stx = _loadShieldedTransaction("deposit_weth_tx");
        preVerificationDetails = _loadPreVerificationDetails(
            "deposit_weth_tx_preVerificationEncodedStruct"
        );
    }

    ///////////// Add STX to Mempool Tests //////////////
    function testAddStxToMempool() public {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];
        bytes32 proofId = _generateProofId(preVerificationDetails);
        console.log("ProofId");
        console.logBytes32(proofId);

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        vm.expectEmit(true, true, true, true);
        emit IMempool.STXAddedToMempool(
            stxHashPI,
            address(this),
            proofId,
            block.timestamp
        );
        vm.expectEmit(true, true, true, false);
        emit IMempool.LockNotes(stxHashPI, stx.nullifiers);
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
        // Mocking preVerificationDetails to have a different STX hash
        preVerificationDetails.publicInputs[2] = uint256(
            keccak256(abi.encodePacked("random"))
        );

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES);

        vm.expectRevert(MempoolValidator.InvalidStx.selector);
        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
    }

    function testRevertWhenDuplicateSTXAdded() public {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        _mintAsset(asset1, address(this), INITIAL_MINT_AMT);
        _approveAsset(asset1, address(mempool), INITIAL_MINT_AMT);
        deal(address(this), MEMPOOL_EXIT_FEES * 2);

        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MempoolValidator.DuplicateStx.selector,
                stxHashPI
            )
        );
        mempool.addSTXToMempool{value: MEMPOOL_EXIT_FEES}(
            stx,
            preVerificationDetails
        );
    }

    ///////////// Exit Mempool Tests //////////////
    function testExitMempool() public addSTXToMempool {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];
        uint256[] memory noteNullifiers = stx.nullifiers;
        bytes32 proofId = _generateProofId(preVerificationDetails);

        vm.expectEmit(true, true, true, true);
        emit IMempool.STXProcessed(stxHashPI, proofId, block.timestamp);

        vm.expectEmit(true, true, true, false);
        emit IMempool.UnlockNotes(stxHashPI, noteNullifiers);
        mempool.exitSTXFromMempool(stxHashPI, stx, proofId);

        assertEq(IERC20(asset1.assetAddress).balanceOf(address(mempool)), 0);
        assertEq(
            IERC20(asset1.assetAddress).balanceOf(address(pool)),
            DEPOSIT_AMT
        );
        assertEq(address(mempool).balance, MEMPOOL_EXIT_FEES);
        // assertEq(mempool.isSTXInMempool(stxHashPI), false);
    }

    function testExitTransferTxMempool() public addTransferSTXToMempool {
        // Depositing assets before transfer
        _mintAsset(asset1, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);

        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "deposit_weth_tx"
        );
        pool.transact(stxDeposit, false);
        _processCommitmentTreeQueue();

        ShieldedTransaction memory stxTransfer = _loadShieldedTransaction(
            "transfer_20_weth_with_weth_fee"
        );

        PreVerificationDetails
            memory preVerificationDetailsForTransferTx = _loadPreVerificationDetails(
                "transfer_20_weth_with_weth_fee_preVerificationEncodedStruct"
            );

        uint256 stxHashPI = preVerificationDetailsForTransferTx.publicInputs[2];
        uint256[] memory noteNullifiers = stxTransfer.nullifiers;

        bytes32 proofId = _generateProofId(preVerificationDetailsForTransferTx);

        vm.expectEmit(true, true, true, true);
        emit IMempool.STXProcessed(stxHashPI, proofId, block.timestamp);

        vm.expectEmit(true, true, true, false);
        emit IMempool.UnlockNotes(stxHashPI, noteNullifiers);
        mempool.exitSTXFromMempool(stxHashPI, stxTransfer, proofId);
    }

    function testRevertWhenExitingSTXTDoesNotExistInMempool() public {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        vm.expectRevert(
            abi.encodeWithSelector(
                IMempool.STXProofIdMismatchOrSTXAbsent.selector,
                stxHashPI
            )
        );
        mempool.exitSTXFromMempool(
            stxHashPI,
            stx,
            _generateProofId(preVerificationDetails)
        );
    }

    function testRevertWhenExitingSTXTIsNotVerifiedYet()
        public
        addSTXToMempool
    {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];
        bytes32 proofId = _generateProofId(preVerificationDetails);

        // Mocking the proof verification result to false when testing locally
        if (block.chainid == 31337) {
            mockNebraVerifier.setIsProofVerifiedResult(false);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                IMempool.STXNotPreVerified.selector,
                stxHashPI,
                proofId
            )
        );
        mempool.exitSTXFromMempool(stxHashPI, stx, proofId);
    }

    ///////////// Refund //////////////////
    function testDropFromMempool() public addSTXToMempool {
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];
        bytes32 proofId = _generateProofId(preVerificationDetails);
        uint256[] memory noteNullifiers = _loadShieldedTransaction(
            "deposit_weth_tx"
        ).nullifiers;

        // Mocking the proof verification result to false as it's a prerequisite for dropping stx from Mempool.
        if (block.chainid == 31337) {
            mockNebraVerifier.setIsProofVerifiedResult(false);
        }

        uint8 DROP_TX_PENALTY_PERC = 8;
        uint256 expectedPenalty = (MEMPOOL_EXIT_FEES * DROP_TX_PENALTY_PERC) /
            100;
        uint256 expectedRefundOfExitFee = MEMPOOL_EXIT_FEES - expectedPenalty;

        vm.expectEmit(true, true, true, true);
        emit IMempool.STXDropped(stxHashPI, address(this), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit IMempool.UnlockNotes(stxHashPI, noteNullifiers);

        mempool.dropFromMempool(stxHashPI, stx, proofId);

        assert(IERC20(token1).balanceOf(address(this)) == INITIAL_MINT_AMT);
        assert(IERC20(token1).balanceOf(address(mempool)) == 0);
        assert(address(this).balance == expectedRefundOfExitFee);
        assert(address(mempool).balance == expectedPenalty);
    }

    receive() external payable {
        console.log("Received native eth:", msg.value);
    }
}
