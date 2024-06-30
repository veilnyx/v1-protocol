// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hasher} from "src/core/Hasher.sol";
import {BaseScript} from "../BaseScript.sol";

contract HasherDeployer is BaseScript {
    function run() external broadcast {
        string memory t3Path = string.concat(
            vm.projectRoot(),
            "/src/poseidon/t3.txt"
        );
        string memory t4Path = string.concat(
            vm.projectRoot(),
            "/src/poseidon/t4.txt"
        );

        string memory t3BytecodeFile = vm.readFile(t3Path);
        string memory t4BytecodeFile = vm.readFile(t4Path);
        bytes memory t3Bytecode = vm.parseBytes(t3BytecodeFile);
        bytes memory t4Bytecode = vm.parseBytes(t4BytecodeFile);

        address poseidonT3;
        address poseidonT4;
        assembly {
            poseidonT3 := create(0, add(t3Bytecode, 0x20), mload(t3Bytecode))
            poseidonT4 := create(0, add(t4Bytecode, 0x20), mload(t4Bytecode))
        }

        new Hasher(poseidonT3, poseidonT4);
    }
}
