// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {ZKFi} from "test/helpers/ZKFi.sol";
import {ShieldedAccount} from "test/helpers/ShieldedAccount.sol";

struct Fixture {
    uint8 addressTreeDepth;
    uint8 commitmentTreeDepth;
    uint256 withdrawFeeBps;
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
    ShieldedAccount senderAccount;
    ShieldedAccount receiverAccount;
}

library FixtureLib {
    function load(Vm vm) public view returns (Fixture memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/test/fixtures/config.json"
        );
        string memory configJson = vm.readFile(path);

        Fixture memory fixture;

        // Tree params
        fixture.addressTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".addressTreeDepth")
        );
        fixture.commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".commitmentTreeDepth")
        );

        // Fee
        fixture.withdrawFeeBps = vm.parseJsonUint(
            configJson,
            ".withdrawFeeBps"
        );

        // Compliance Keys
        fixture.revokerPublicKey[0] = vm.parseJsonUint(
            configJson,
            ".revokerPublicKey[0]"
        );
        fixture.revokerPublicKey[1] = vm.parseJsonUint(
            configJson,
            ".revokerPublicKey[1]"
        );
        fixture.encryptionPublicKey[0] = vm.parseJsonUint(
            configJson,
            ".encryptionPublicKey[0]"
        );
        fixture.encryptionPublicKey[1] = vm.parseJsonUint(
            configJson,
            ".encryptionPublicKey[1]"
        );

        // Accounts
        fixture.senderAccount.seed = vm.parseJsonUint(
            configJson,
            ".senderAccount.seed"
        );
        fixture.senderAccount.pubAddress = vm.parseJsonAddress(
            configJson,
            ".senderAccount.pubAddress"
        );
        fixture.senderAccount.rootAddress = vm.parseJsonUint(
            configJson,
            ".senderAccount.rootAddress"
        );
        fixture.receiverAccount.seed = vm.parseJsonUint(
            configJson,
            ".receiverAccount.seed"
        );
        fixture.receiverAccount.pubAddress = vm.parseJsonAddress(
            configJson,
            ".receiverAccount.pubAddress"
        );
        fixture.receiverAccount.rootAddress = vm.parseJsonUint(
            configJson,
            ".receiverAccount.rootAddress"
        );

        return fixture;
    }

    function loadZTx(
        string memory name,
        Vm vm
    ) external view returns (ZTransaction memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            string.concat("/test/fixtures/ztx/", name, ".txt")
        );
        string memory file = vm.readFile(path);
        bytes memory data = vm.parseBytes(file);
        ZTransaction memory ztx = abi.decode(data, (ZTransaction));
        return ztx;
    }
}
