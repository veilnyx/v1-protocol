// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Stand-ins for HyperCore, for local chains where none of it exists.
/// @dev Each is meant to be placed AT its precompile address (vm.etch in tests,
///      anvil_setCode locally). Their fallbacks ignore the arguments and return a
///      single configured value, which is enough to drive one vault. The real
///      precompiles key on (user, perp); these do not.
///      Calldata always begins with four zero bytes here (a right-aligned uint32 or
///      a left-padded address), so it can never collide with a setter selector.

contract MockPositionPrecompile {
    int64 public szi;
    int64 public entryNtl;
    int64 public isolatedRawUsd;
    uint32 public leverage = 10;
    bool public isIsolated;

    function set(int64 szi_, int64 entryNtl_, uint32 leverage_) external {
        szi = szi_;
        entryNtl = entryNtl_;
        leverage = leverage_;
    }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(szi, entryNtl, isolatedRawUsd, leverage, isIsolated);
    }
}

contract MockMarginSummaryPrecompile {
    int64 public accountValue;
    uint64 public totalNtlPos;
    uint64 public totalRawUsd;
    uint64 public totalMarginUsed;

    /// @param accountValue_ in Core's 8-decimal USD, i.e. 100x the linked ERC20 value.
    function set(int64 accountValue_) external {
        accountValue = accountValue_;
    }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(accountValue, totalNtlPos, totalRawUsd, totalMarginUsed);
    }
}

contract MockPxPrecompile {
    uint64 public px;

    function set(uint64 px_) external {
        px = px_;
    }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(px);
    }
}

/// @notice Records what would have been sent to Core so it can be inspected.
contract MockCoreWriter {
    event RawAction(address indexed sender, bytes data);

    bytes[] public actions;

    function sendRawAction(bytes calldata data) external {
        actions.push(data);
        emit RawAction(msg.sender, data);
    }

    function actionCount() external view returns (uint256) {
        return actions.length;
    }
}
