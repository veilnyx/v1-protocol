// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract AddAdaptorScript is Script {
    address public poolAddress = 0xa5FA5D5709DE4A96c737302Ddb07e8aE2CdAE465;
    address[] adaptorAddresses;

    function run() external {
        adaptorAddresses = [
            0x86a56e31c86e6E4E2669A4b84fD06235f1be70C7,
            0x298E3c43E0A235Cee3470b02869e076404A5964f,
            0x957e7A83144da8Ac100a83e9f701cddEC8E52a2e
        ];
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        IPool pool = IPool(poolAddress);

        vm.startBroadcast(privateKey);
        pool.addAdaptorSupport(
            0x957e7A83144da8Ac100a83e9f701cddEC8E52a2e,
            true
        );
        vm.stopBroadcast();
    }
}
