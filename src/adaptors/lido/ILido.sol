// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.26;

interface ILido {
    error LidoWithdrawNotSupportedOnChain(uint256 chainid);
    error ZeroAddress();
    
    function submit(address _referral) external payable returns (uint256);

    function getPooledEthByShares(
        uint256 _sharesAmount
    ) external view returns (uint256);
}
