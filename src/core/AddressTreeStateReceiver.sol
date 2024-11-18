// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppReceiver} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";

interface IAddressTreeStateUpdater {
    function updateAddressTreeState(bytes calldata payload) external;
}

contract AddressTreeStateReceiver is OAppReceiver {
    address public immutable treeStateUpdater;

    constructor(
        address endpoint_,
        address owner_,
        address treeStateUpdater_
    ) OAppCore(endpoint_, owner_) Ownable(owner_) {
        treeStateUpdater = treeStateUpdater_;
    }

    function _lzReceive(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) internal override {
        IAddressTreeStateUpdater(treeStateUpdater).updateAddressTreeState(
            payload
        );
    }

    receive() external payable {}
}
