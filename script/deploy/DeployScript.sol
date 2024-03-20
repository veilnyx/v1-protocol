// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Config} from "./Config.sol";

struct TxInfo {
    address contractAddress;
}

abstract contract DeployScript is Script {
    Config internal _config;

    constructor() {
        _config = new Config();
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        _deploy();
        vm.stopBroadcast();
    }

    function _getContract(string memory name) internal returns (address) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/broadcast/",
            name,
            ".s.sol/",
            vm.toString(block.chainid),
            "/run-latest.json"
        );

        if (!vm.exists(path)) {
            revert("File not found");
        }

        string memory json = vm.readFile(path);
        bytes memory res = vm.parseJson(
            json,
            ".transactions[-1].contractAddress"
        );

        return address(uint160(uint256(bytes32(res))));
    }

    function _deploy() internal virtual;
}
