// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import { IMessageListener } from "./MessageReceiver.sol";
import { Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";


    struct AddressTree{
    mapping(uint8 => uint256) roots;
    uint8 currentRootIndex;
    }

contract MessageListner is IMessageListener {
    AddressTree internal _addressTree;

    function onMessage(
        Origin calldata origin,
        bytes calldata payload,
        address executor,
        bytes calldata options
    )
        public
    {
        // @todo Check if origin of the msg is expected
        // @todo Check if the `executor` is msg.sender
        
        (uint256 root, uint8 currentRootIndex) = abi.decode(payload, (uint256, uint8));
        _addressTree.roots[currentRootIndex] = root;
        _addressTree.currentRootIndex = currentRootIndex;
    }
}