// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {ZKFi} from "test/helpers/ZKFi.sol";
import {ZAccount} from "test/helpers/ZAccount.sol";

struct Fixture {
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
    address withdrawAddress;
    ZAccount senderAccount;
    ZAccount receiverAccount;
}

library FixtureLib {
    function load(ZKFi zkfi) public returns (Fixture memory) {
        ZAccount memory sender = zkfi.genAccount(uint256(keccak256("sender")));
        ZAccount memory receiver = zkfi.genAccount(
            uint256(keccak256("receiver"))
        );
        return
            Fixture({
                revokerPublicKey: [
                    8116072818876777666029027213729376705234613448128995613697283149497235402123,
                    4598772416842731049226007701899382609184728232075557894618791492264594188716
                ],
                encryptionPublicKey: [
                    15187339732644800751812193648350861431733040013104897934882869545575329240973,
                    18224946718075372665314217959364704865149122115871220475141871484502637776562
                ],
                withdrawAddress: address(bytes20(keccak256("withdraw"))),
                senderAccount: sender,
                receiverAccount: receiver
            });
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
