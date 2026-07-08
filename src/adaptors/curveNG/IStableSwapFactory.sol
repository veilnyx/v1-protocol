// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface IStableSwapFactory {
    function find_pool_for_coins(
        address,
        address,
        uint256
    ) external view returns (address);
}
