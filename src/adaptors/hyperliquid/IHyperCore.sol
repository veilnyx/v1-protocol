// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

/// @title HyperCore read precompiles and CoreWriter access
/// @notice Thin, dependency-free bindings for the HyperEVM -> HyperCore interface.
/// @dev Every return shape below was verified against chain 998 by measuring the
///      precompile's returndata size:
///        0x800 position(address,uint32)          -> 160 bytes (5 words)
///        0x80f accountMarginSummary(uint32,addr) -> 128 bytes (4 words)
///        0x806 markPx(uint32)                    ->  32 bytes (1 word)
///        0x808 spotPx(uint32)                    ->  32 bytes (1 word)
library HyperCore {
    address internal constant POSITION = 0x0000000000000000000000000000000000000800;
    address internal constant SPOT_BALANCE = 0x0000000000000000000000000000000000000801;
    address internal constant WITHDRAWABLE = 0x0000000000000000000000000000000000000803;
    address internal constant MARK_PX = 0x0000000000000000000000000000000000000806;
    address internal constant SPOT_PX = 0x0000000000000000000000000000000000000808;
    address internal constant L1_BLOCK = 0x0000000000000000000000000000000000000809;
    address internal constant MARGIN_SUMMARY = 0x000000000000000000000000000000000000080F;
    address internal constant CORE_USER_EXISTS = 0x0000000000000000000000000000000000000810;

    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;

    /// @dev CoreWriter action ids. The full set is 1-13 and 15-17; id 14 does not
    ///      exist. Notably ABSENT and therefore impossible from a contract:
    ///      updating leverage, setting margin mode, and creating sub-accounts.
    uint24 internal constant ACTION_LIMIT_ORDER = 1;
    uint24 internal constant ACTION_SPOT_SEND = 6;
    uint24 internal constant ACTION_USD_CLASS_TRANSFER = 7;
    uint24 internal constant ACTION_CANCEL_BY_CLOID = 11;

    /// @dev Time-in-force encoding for action 1.
    uint8 internal constant TIF_IOC = 3;

    error PrecompileFailed(address precompile);

    struct Position {
        int64 szi;
        int64 entryNtl;
        int64 isolatedRawUsd;
        uint32 leverage;
        bool isIsolated;
    }

    struct MarginSummary {
        int64 accountValue;
        uint64 totalNtlPos;
        uint64 totalRawUsd;
        uint64 totalMarginUsed;
    }

    function position(address user, uint32 perp) internal view returns (Position memory p) {
        (bool ok, bytes memory out) = POSITION.staticcall(abi.encode(user, perp));
        if (!ok) revert PrecompileFailed(POSITION);
        p = abi.decode(out, (Position));
    }

    function marginSummary(address user, uint32 perpDex) internal view returns (MarginSummary memory m) {
        (bool ok, bytes memory out) = MARGIN_SUMMARY.staticcall(abi.encode(perpDex, user));
        if (!ok) revert PrecompileFailed(MARGIN_SUMMARY);
        m = abi.decode(out, (MarginSummary));
    }

    function markPx(uint32 perp) internal view returns (uint64 px) {
        (bool ok, bytes memory out) = MARK_PX.staticcall(abi.encode(perp));
        if (!ok) revert PrecompileFailed(MARK_PX);
        px = abi.decode(out, (uint64));
    }

    function coreUserExists(address user) internal view returns (bool exists) {
        (bool ok, bytes memory out) = CORE_USER_EXISTS.staticcall(abi.encode(user));
        if (!ok) revert PrecompileFailed(CORE_USER_EXISTS);
        exists = abi.decode(out, (bool));
    }

    /// @notice Encode and submit a CoreWriter action.
    /// @dev Wire format is: 1 byte encoding version (only `1` is supported), then
    ///      3 bytes of action id big-endian, then the ABI-encoded payload.
    function sendAction(uint24 actionId, bytes memory payload) internal {
        bytes memory data = abi.encodePacked(bytes1(0x01), bytes3(actionId), payload);
        (bool ok,) = CORE_WRITER.call(abi.encodeWithSignature("sendRawAction(bytes)", data));
        if (!ok) revert PrecompileFailed(CORE_WRITER);
    }

    /// @dev Order actions are deliberately delayed a few seconds on Core. Nothing
    ///      about the fill is knowable in this transaction.
    function limitOrder(uint32 perp, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 tif, uint128 cloid)
        internal
    {
        sendAction(ACTION_LIMIT_ORDER, abi.encode(perp, isBuy, limitPx, sz, reduceOnly, tif, cloid));
    }

    /// @dev Class transfers are NOT delayed, which is what makes margin top-ups fast.
    function usdClassTransfer(uint64 ntl, bool toPerp) internal {
        sendAction(ACTION_USD_CLASS_TRANSFER, abi.encode(ntl, toPerp));
    }

    function spotSend(address destination, uint64 token, uint64 wei_) internal {
        sendAction(ACTION_SPOT_SEND, abi.encode(destination, token, wei_));
    }

    /// @notice System address that a linked ERC20 is sent to in order to credit Core spot.
    /// @dev First byte 0x20, remaining bytes zero except the big-endian token index.
    function systemAddress(uint64 tokenIndex) internal pure returns (address) {
        return address(uint160(uint160(0x20) << 152 | uint160(tokenIndex)));
    }
}
