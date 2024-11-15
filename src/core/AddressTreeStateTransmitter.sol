// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

contract AddressTreeStateTransmitter is OAppSender {
    constructor(address endpoint_, address owner_) OAppCore(endpoint_, owner_) Ownable(owner_) { }

    function send(
        uint32 eid,
        bytes calldata message,
        bytes calldata options,
        MessagingFee calldata fee,
        address refundAddress
    )
        external
        payable
        onlyOwner {
        _lzSend(uint32(eid), message, options, fee, refundAddress);
    }

    function quote(
        uint32 eid,
        bytes calldata message,
        bytes calldata options,
        bool payInLzToken
    )
        external
        view
        returns (MessagingFee memory)
    {
        return _quote(uint32(eid), message, options, payInLzToken);
    }

    receive() external payable { }
}
