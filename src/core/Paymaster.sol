// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BasePaymaster} from "@account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ZTransaction} from "../libraries/ZTransaction.sol";
import {IPool} from "../interfaces/IPool.sol";

contract Paymaster is BasePaymaster {
    uint256 public constant VALIDATION_SUCCESS = 0;

    address public immutable sender;

    /**
     * @dev Mapping from assetId to fee value.
     */
    mapping(uint24 => uint256) private _assetFees;

    error InvalidPaymaster(address paymaster);
    error InvalidSender(address sender);
    error InvalidCallData();
    error InsufficientFee(uint256 given, uint256 required);
    error UnsupportedFeeAsset(uint24 asset);

    constructor(
        address entryPoint_,
        address sender_
    ) BasePaymaster(IEntryPoint(entryPoint_)) {
        sender = sender_;
    }

    function getAssetFee(uint24 assetId) external view returns (uint256) {
        return _assetFees[assetId];
    }

    function updateAssetFee(
        uint24 assetId,
        uint256 feeValue
    ) external onlyOwner {
        _assetFees[assetId] = feeValue;
    }

    function isFeeAssetSupported(uint24 assetId) external view returns (bool) {
        return _assetFees[assetId] > 0;
    }

    function withdrawTo(
        address token,
        address payable to,
        uint256 value
    ) public onlyOwner {
        if (token == address(0)) {
            Address.sendValue(to, value);
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, value);
        }
    }

    /// @dev The only requirements for validation are
    ///     - sender is pool contract
    ///     - specified paymaster is this contract only (guarantee to receive fee to this contract)
    ///     - specified fee is sufficient
    /// Since thispaymaster is only used by and meant for zkFi pool and the pool's `validateUserOp` already checks
    /// for validity of tx (so that it does not revert when called), we don't need to check those here.
    /// This paymaster must always maintain sufficient deposit in the `EntryPoint` contract to pay for gas.
    /// Note that it always reverts for invalid operations rather than returning.
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCostEth
    ) internal view override returns (bytes memory, uint256) {
        // Only support pool contract as sender
        if (userOp.sender != sender) {
            revert InvalidSender(userOp.sender);
        }

        (
            address paymaster,
            uint24 feeAssetId,
            uint256 givenFee
        ) = _parseFeeParams(userOp);

        // Fee recipient must be this contract
        if (paymaster != address(this)) {
            revert InvalidPaymaster(paymaster);
        }

        uint256 requiredFee = _getRequiredFee(feeAssetId, maxCostEth);

        if (givenFee < requiredFee) {
            revert InsufficientFee(givenFee, requiredFee);
        }

        return ("", VALIDATION_SUCCESS);
    }

    function _parseFeeParams(
        PackedUserOperation calldata userOp
    ) internal pure returns (address, uint24, uint256) {
        ZTransaction memory ztx = abi.decode(
            userOp.callData[4:],
            (ZTransaction)
        );

        uint24 feeAssetId = ztx.pubAssetIds[0];
        uint256 feeValue = uint256(uint96(ztx.feeData));
        address paymaster = address(bytes20(bytes32(ztx.feeData)));

        return (paymaster, feeAssetId, feeValue);
    }

    function _getRequiredFee(
        uint24 feeAssetId,
        uint256 /*maxCostEth*/
    ) internal view returns (uint256) {
        uint256 feeAssetValue = _assetFees[feeAssetId];

        if (feeAssetValue == 0) {
            revert UnsupportedFeeAsset(feeAssetId);
        }

        return feeAssetValue;
    }

    receive() external payable {}
}
