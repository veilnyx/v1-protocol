// SPDX-License-Identifier: GPL-2.0-later

pragma solidity 0.8.26;

interface IWithdrawQueueERC721 {
    function requestWithdrawalsWstETH(uint256[] calldata _amounts, address _owner) external returns (uint256[] calldata requestIds);
}