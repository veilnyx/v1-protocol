// SPDX-LICENSE-Identifier: GPL
pragma solidity 0.8.24;

interface ICurvePool {

    function N_COINS() external view returns (uint256);

    function coins(uint256 i) external view returns (address);

}
