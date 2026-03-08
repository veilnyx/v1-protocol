// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {PreVerificationDetails} from "src/core/Mempool.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {ShieldedAccount} from "test/helpers/ShieldedAccount.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";

struct Fixture {
    address payable paymaster;
    address payable gateway;
    uint8 addressTreeDepth;
    uint8 commitmentTreeDepth;
    uint8 commitmentTreeQueueSize;
    uint256 withdrawFeeBps;
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
    ShieldedAccount sender;
    ShieldedAccount receiver;
    uint256[] leavesQueue1;
    uint256[] leavesQueue2;
    uint256[] leavesQueuePartial;
    uint256[] preDepositedNotesCommitments;
}

library FixtureLib {
    function load(Vm vm) public view returns (Fixture memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/test/fixtures/config.json"
        );
        string memory configJsonStr = vm.readFile(path);

        Fixture memory fixture;

        fixture.paymaster = payable(
            vm.parseJsonAddress(configJsonStr, ".paymaster")
        );

        fixture.gateway = payable(
            vm.parseJsonAddress(configJsonStr, ".gateway")
        );

        // Tree params
        fixture.addressTreeDepth = uint8(
            vm.parseJsonUint(configJsonStr, ".addressTreeDepth")
        );
        fixture.commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJsonStr, ".commitmentTreeDepth")
        );
        fixture.commitmentTreeQueueSize = uint8(
            vm.parseJsonUint(configJsonStr, ".commitmentTreeQueueSize")
        );

        // Queue of leaves for queued merkle tree
        fixture.leavesQueue1 = vm.parseJsonUintArray(
            configJsonStr,
            ".leavesQueue1"
        );
        fixture.leavesQueue2 = vm.parseJsonUintArray(
            configJsonStr,
            ".leavesQueue2"
        );
        fixture.leavesQueuePartial = vm.parseJsonUintArray(
            configJsonStr,
            ".leavesQueuePartial"
        );

        // Pre-deposited notes commitments
        fixture.preDepositedNotesCommitments = vm.parseJsonUintArray(
            configJsonStr,
            ".preDepositedNotesCommitments"
        );

        // Fee
        fixture.withdrawFeeBps = vm.parseJsonUint(
            configJsonStr,
            ".withdrawFeeBps"
        );

        // Compliance Keys
        fixture.revokerPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".revokerPublicKey[0]"
        );
        fixture.revokerPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".revokerPublicKey[1]"
        );
        fixture.encryptionPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".encryptionPublicKey[0]"
        );
        fixture.encryptionPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".encryptionPublicKey[1]"
        );

        // Sender Accounts
        fixture.sender.seed = vm.parseJsonUint(configJsonStr, ".sender.seed");
        fixture.sender.pubAddress = vm.parseJsonAddress(
            configJsonStr,
            ".sender.pubAddress"
        );
        fixture.sender.rootAddress = vm.parseJsonUint(
            configJsonStr,
            ".sender.rootAddress"
        );

        fixture.sender.signPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".sender.signPublicKey[0]"
        );
        fixture.sender.signPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".sender.signPublicKey[1]"
        );
        fixture.sender.viewPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".sender.viewPublicKey[0]"
        );
        fixture.sender.viewPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".sender.viewPublicKey[1]"
        );
        fixture.sender.shieldedAddress = vm.parseJsonBytes(
            configJsonStr,
            ".sender.shieldedAddress"
        );

        fixture.receiver.seed = vm.parseJsonUint(
            configJsonStr,
            ".receiver.seed"
        );
        fixture.receiver.pubAddress = vm.parseJsonAddress(
            configJsonStr,
            ".receiver.pubAddress"
        );
        fixture.receiver.rootAddress = vm.parseJsonUint(
            configJsonStr,
            ".receiver.rootAddress"
        );
        fixture.receiver.signPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".receiver.signPublicKey[0]"
        );
        fixture.receiver.signPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".receiver.signPublicKey[1]"
        );
        fixture.receiver.viewPublicKey[0] = vm.parseJsonUint(
            configJsonStr,
            ".receiver.viewPublicKey[0]"
        );
        fixture.receiver.viewPublicKey[1] = vm.parseJsonUint(
            configJsonStr,
            ".receiver.viewPublicKey[1]"
        );
        fixture.receiver.shieldedAddress = vm.parseJsonBytes(
            configJsonStr,
            ".receiver.shieldedAddress"
        );

        return fixture;
    }

    function loadShieldedTransaction(
        string memory name,
        Vm vm
    ) external view returns (ShieldedTransaction memory) {
        bytes memory data = loadData(name, vm);
        ShieldedTransaction memory stx = abi.decode(
            data,
            (ShieldedTransaction)
        );
        return stx;
    }

    function loadPreVerificationDetails(
        string memory name,
        Vm vm
    ) external view returns (PreVerificationDetails memory) {
        bytes memory data = loadData(name, vm);
        PreVerificationDetails memory preVerificationDetails = abi.decode(
            data,
            (PreVerificationDetails)
        );
        return preVerificationDetails;
    }

    function loadPackedUserOp(
        string memory name,
        Vm vm
    ) external view returns (PackedUserOperation memory) {
        bytes memory data = loadData(name, vm);
        PackedUserOperation memory packedUserOp = abi.decode(
            data,
            (PackedUserOperation)
        );
        return packedUserOp;
    }

    function loadShieldedAddressRegistrationData(
        string memory name,
        Vm vm
    ) external view returns (ShieldedAddressRegistrationData memory) {
        bytes memory data = loadData(name, vm);
        ShieldedAddressRegistrationData memory addressRegData = abi.decode(
            data,
            (ShieldedAddressRegistrationData)
        );
        return addressRegData;
    }

    function loadTreeUpdateData(
        string memory name,
        Vm vm
    ) external view returns (TreeUpdateData memory) {
        bytes memory data = loadData(name, vm);
        TreeUpdateData memory treeUpdateData = abi.decode(
            data,
            (TreeUpdateData)
        );
        return treeUpdateData;
    }

    function loadData(
        string memory name,
        Vm vm
    ) public view returns (bytes memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            string.concat("/test/fixtures/data/", name, ".txt")
        );
        string memory file = vm.readFile(path);
        bytes memory data = vm.parseBytes(file);
        return data;
    }
}
