// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "forge-std/Script.sol";

contract TransferOwnershipScript is Script {
    address public newOwner = 0x8f9Af25A446b8fF4aFBb52438e5B60512510fa63;
    address public ownableContractAddress =
        0x9163043b553aDeF9fE44b088922560cfBFdEC51b;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        OwnableUpgradeable ownableContract = OwnableUpgradeable(
            ownableContractAddress
        );
        ownableContract.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
