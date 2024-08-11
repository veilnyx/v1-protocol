// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {ShieldedAccount} from "test/helpers/ShieldedAccount.sol";

struct Fixture {
    uint8 addressTreeDepth;
    uint8 commitmentTreeDepth;
    uint256 withdrawFeeBps;
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
    ShieldedAccount sender;
    ShieldedAccount receiver;
}

library FixtureLib {
    function load(Vm vm) public view returns (Fixture memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/test/fixtures/config.json"
        );
        string memory configJsonStr = vm.readFile(path);

        Fixture memory fixture;

        // Tree params
        fixture.addressTreeDepth = uint8(
            vm.parseJsonUint(configJsonStr, ".addressTreeDepth")
        );
        fixture.commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJsonStr, ".commitmentTreeDepth")
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
        // fixture.sender.signPublicKey[0] = abi.decode(
        //     vm.parseJson(configJsonStr, ".sender.signPublicKey[0]"),
        //     (uint256)
        // );
        // uint256[] memory arr = vm.parseJsonUintArray(
        //     configJsonStr,
        //     ".sender.signPublicKey"
        // );
        // console2.logUint(arr.length);
        // console2.logUint(arr[0]);
        // console2.logUint(arr[1]);
        // fixture.sender.signPublicKey = abi.decode(
        //     vm.parseJson(configJsonStr, ".sender.signPublicKey"),
        //     (uint256[2])
        // );
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
    ) external view returns (ZTransaction memory) {
        bytes memory data = _loadData(name, vm);
        ZTransaction memory ztx = abi.decode(data, (ZTransaction));
        return ztx;
    }

    function loadShieldedAddressRegistrationData(
        string memory name,
        Vm vm
    ) external view returns (ShieldedAddressRegistrationData memory) {
        bytes memory data = _loadData(name, vm);
        ShieldedAddressRegistrationData memory addressRegData = abi.decode(
            data,
            (ShieldedAddressRegistrationData)
        );
        return addressRegData;
    }

    function _loadData(
        string memory name,
        Vm vm
    ) internal view returns (bytes memory) {
        string memory path = string.concat(
            vm.projectRoot(),
            string.concat("/test/fixtures/data/", name, ".txt")
        );
        string memory file = vm.readFile(path);
        bytes memory data = vm.parseBytes(file);
        return data;
    }
}
