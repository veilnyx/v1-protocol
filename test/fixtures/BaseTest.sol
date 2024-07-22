// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZTransactionType, ZTransaction} from "src/libraries/ZTransaction.sol";
import {Hasher} from "src/core/Hasher.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";

abstract contract BaseTest is Test {
    Fixture public fixture;

    function _setUp() internal {
        fixture = FixtureLib.load(vm);
    }

    function _loadZTx(
        string memory name
    ) internal view returns (ZTransaction memory) {
        return FixtureLib.loadZTx(name, vm);
    }

    function _deployHasher() internal returns (address) {
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

        address hasher = address(new Hasher(poseidonT3, poseidonT4));
        return hasher;
    }
}
