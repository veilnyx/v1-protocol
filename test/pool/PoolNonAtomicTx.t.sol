// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IAdaptor} from "src/interfaces/IAdaptor.sol";
import {ShieldedTransaction, ShieldedTransactionLogic} from "src/libraries/ShieldedTransaction.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {console2} from "forge-std/console2.sol";

contract MockNonAtomicTxAdaptor is IAdaptor {
    address immutable adpHandler;

    constructor(address adpHandler_) {
        adpHandler = adpHandler_;
    }

    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata targetPayload
    ) external payable override returns (uint24[] memory, uint256[] memory) {
        console2.log("MockNonAtomicTxAdaptor.handleAssets called");
        return (new uint24[](0), new uint256[](0));
    }

    function completeNonAtomicTx(
        uint256 txHash,
        uint24 refundedAssetId,
        uint256 refundedValue,
        AdaptorHandler adpHandlerContract
    ) external {
        console2.log("MockNonAtomicTxAdaptor.completeNonAtomicTx called");

        uint24[] memory outAssetIds = new uint24[](1);
        outAssetIds[0] = refundedAssetId;

        uint256[] memory outAssetValues = new uint256[](1);
        outAssetValues[0] = refundedValue;

        adpHandlerContract.completeNonAtomicTx(
            txHash,
            outAssetIds,
            outAssetValues
        );
    }
}

contract PoolNonAtomicTxTest is PoolTest {
    using ShieldedTransactionLogic for ShieldedTransaction;

    uint256 constant DEPOSIT_AMOUNT = 2 ether;
    MockNonAtomicTxAdaptor mockAdaptor;
    ShieldedTransaction stxNonAtomic = _loadShieldedTransaction("use_2_weth");

    function setUp() public {
        PoolTest._setUp();
        deal(address(token1), address(this), DEPOSIT_AMOUNT);

        IERC20(address(token1)).approve(address(pool), DEPOSIT_AMOUNT);
        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "deposit_2_weth"
        );
        pool.transact(stxDeposit);
        _processCommitmentTreeQueue();

        mockAdaptor = new MockNonAtomicTxAdaptor(address(adaptorHandler));
        pool.addAdaptorSupport(address(mockAdaptor), true);
        console2.log(
            "MockNonAtomicTxAdaptor deployed at: {}",
            address(mockAdaptor)
        );
    }

    function test_nonAtomicTx() public {
        _checkEventEmits(stxNonAtomic);
    }

    function test_AdaptorHandlerStorageForNonAtomicTx() public {
        pool.transact(stxNonAtomic);

        assertEq(adaptorHandler.nonAtomicTxStatus(stxNonAtomic.hash()), true);
    }

    function test_completeNonAtomicTxFlow() public {
        uint256 txHash = stxNonAtomic.hash();
        pool.transact(stxNonAtomic);
        assertEq(adaptorHandler.nonAtomicTxStatus(txHash), true);

        // enacting the external protocol to complete the non-atomic tx
        uint24 refundAssetId = asset1.id;
        uint256 refundValue = 2e18;
        deal(address(token1), address(this), refundValue);

        token1.transfer(address(adaptorHandler), refundValue); // since adpHandler makes a `delegateCall` to the adaptor, the external protocol must transfer the refund value to the adaptorHandler

        mockAdaptor.completeNonAtomicTx(
            txHash,
            refundAssetId,
            refundValue,
            adaptorHandler
        );

        assertEq(adaptorHandler.nonAtomicTxStatus(stxNonAtomic.hash()), false);
    }
}
