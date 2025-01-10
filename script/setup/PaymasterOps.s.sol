// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";

interface IPaymaster {
    function withdrawFromEntryPoint(
        address payable withdrawAddress,
        uint256 amount
    ) external;
}

contract PaymasterOps is BaseScript {
    function run() external broadcast {
        address paymaster = 0x5e68f66e478e725Ec19C301aA62DaD73eC886B29;
        address payable owner = payable(
            0x8f9Af25A446b8fF4aFBb52438e5B60512510fa63
        );

        IPaymaster(paymaster).withdrawFromEntryPoint(owner, 2e18);
    }
}
