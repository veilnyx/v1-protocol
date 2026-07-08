// SPDX-License-Identifier: LicenseRef-BUSL

pragma solidity 0.8.24;

interface IWithdrawQueueERC721 {
    function requestWithdrawalsWstETH(
        uint256[] calldata _amounts,
        address _owner
    ) external returns (uint256[] calldata requestIds);
}
