// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IPool} from "../interfaces/IPool.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddressTreeStateUpdater is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    error UnauthorizedSender(address);

    address public pool;
    address public stateReceiver;

    function initialize(address pool_) external initializer {
        __Ownable_init(msg.sender);
        pool = pool_;
    }

    function updateAddressTreeState(bytes calldata payload) public {
        if (msg.sender != stateReceiver) {
            revert UnauthorizedSender(msg.sender);
        }

        (uint256 root, uint8 currentRootIndex) = abi.decode(
            payload,
            (uint256, uint8)
        );
        IPool(pool).updateAddressTree(root, currentRootIndex);
    }

    function setPool(address pool_) external onlyOwner {
        pool = pool_;
    }

    function setReceiver(address addrTreeStateTransmitter) external onlyOwner {
        stateReceiver = addrTreeStateTransmitter;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
