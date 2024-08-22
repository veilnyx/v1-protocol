// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ShieldedTransactionType, ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {Hasher} from "src/core/Hasher.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC20ForReentrancyTest} from "test/mocks/MockERC20ForReentrancyTest.sol";

abstract contract BaseTest is Test {
    Fixture public fixture;

    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20ForReentrancyTest public tokenReent;

    function _setUp() internal virtual {
        fixture = FixtureLib.load(vm);
        token1 = new MockERC20(address(this));
        token2 = new MockERC20(address(this));
        // Deploying the ERC20 token for testing reentrancy attack
        tokenReent = new MockERC20ForReentrancyTest(address(this));
    }

    function _loadShieldedTransaction(
        string memory name
    ) internal view returns (ShieldedTransaction memory) {
        return FixtureLib.loadShieldedTransaction(name, vm);
    }

    function _loadShieldedAddressRegistrationData(
        string memory name
    ) internal view returns (ShieldedAddressRegistrationData memory) {
        return FixtureLib.loadShieldedAddressRegistrationData(name, vm);
    }

    function _loadTreeUpdateData(
        string memory name
    ) internal view returns (TreeUpdateData memory) {
        return FixtureLib.loadTreeUpdateData(name, vm);
    }

    function _loadData(
        string memory name
    ) internal view returns (bytes memory) {
        return FixtureLib.loadData(name, vm);
    }

    function _deployHasher() internal returns (Hasher) {
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

        Hasher hasher = new Hasher(poseidonT3, poseidonT4);
        return hasher;
    }
}
