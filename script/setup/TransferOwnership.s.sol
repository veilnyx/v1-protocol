// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "forge-std/Script.sol";

contract TransferOwnership is Script {
    address public newOwner = 0x53315b2b31f3301D6f2145D634E4Bdba7E118471; // Multisig addr SAFE
    address public ownableContractAddress =
        0x62E7485535ea31382dcc3Bbfc399Ddd6B9c9b27F;

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
