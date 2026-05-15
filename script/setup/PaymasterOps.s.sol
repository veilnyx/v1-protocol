// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {console2} from "forge-std/console2.sol";

interface IPaymaster {
    function withdrawFromEntryPoint(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    function getEntryPointDeposit() external view returns (uint256);
}

contract PaymasterOps is BaseScript {
    function run() external broadcast {
        address paymaster = 0xe7cf8561b681E551Dea857A39AA8E65Ca5207561;
        address payable owner = payable(
            0x8f9Af25A446b8fF4aFBb52438e5B60512510fa63
        );

        uint256 deposit = IPaymaster(paymaster).getEntryPointDeposit();
        console2.log("Current deposit: ", deposit);

        // uint256 nullifier = 16937152957139504032254418390344261336685621099750145755553774237564908002161;
        // bytes32 nullifierHex = bytes32(nullifier);
        // console2.logBytes32(nullifierHex);

        // console2.log(
        //     uint256(
        //         bytes32(
        //             0x19ae60d8daa749808b4b5d884c6d84690459008c6dd17046a982ce467d48a444
        //         )
        //     )
        // );
    }
}
