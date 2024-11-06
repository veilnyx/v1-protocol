// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppReceiver} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {console2} from "forge-std/console2.sol";

interface IMessageListener {
    function onMessage(
        Origin calldata origin,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) external;
}

contract MessageReceiver is OAppReceiver {
    address public immutable messageListener;

    constructor(
        address endpoint_,
        address owner_,
        address messageListener_
    ) OAppCore(endpoint_, owner_) Ownable(owner_) {
        messageListener = messageListener_;
    }

    function _lzReceive(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) internal override {
        console2.log("Inside MessageReceiver._lzReceive()");
        
        IMessageListener(messageListener).onMessage(
            origin,
            payload,
            executor,
            options
        );
    }

    receive() external payable {}
}
