// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IMessageListener} from "./MessageReceiver.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MessageListener is
    Initializable,
    UUPSUpgradeable,
    IMessageListener,
    OwnableUpgradeable
{
    address public pool;

    function initialize(address pool_) external initializer {
        __Ownable_init(msg.sender);
        pool = pool_;
    }

    function onMessage(
        Origin calldata origin,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) public {
        // @todo Check if origin of the msg is expected
        // @todo Check if the `executor` is msg.sender

        (uint256 root, uint8 currentRootIndex) = abi.decode(
            payload,
            (uint256, uint8)
        );
        IPool(pool).updateAddressTree(root, currentRootIndex);
    }

    function setPool(address pool_) external onlyOwner {
        pool = pool_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
