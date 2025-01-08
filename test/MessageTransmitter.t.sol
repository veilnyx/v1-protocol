// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {AddressTreeStateTransmitter} from "src/core/AddressTreeStateTransmitter.sol";
import {AddressTreeStateReceiver} from "src/core/AddressTreeStateReceiver.sol";

contract MockAddressTreeStateUpdater {
    bool public flagReceived = false;

    function onMessage(
        Origin calldata origin,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) public {
        flagReceived = true;
    }
}

contract MessageTransmitterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    AddressTreeStateTransmitter public messageSender;
    AddressTreeStateReceiver public messageReceiver;
    MockAddressTreeStateUpdater public messageListener;

    uint32 public eidSender = 1;
    uint32 public eidReceiver = 2;

    function setUp() public virtual override {
        super.setUp();

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        messageListener = new MockAddressTreeStateUpdater();
        messageSender = new AddressTreeStateTransmitter(
            endpoints[eidSender],
            address(this)
        );
        messageReceiver = new AddressTreeStateReceiver(
            endpoints[eidReceiver],
            address(this),
            address(messageListener)
        );

        address[] memory oApps = new address[](2);
        oApps[0] = address(messageSender);
        oApps[1] = address(messageReceiver);

        wireOApps(oApps);
    }

    function test_constructor() public view {
        assertEq(messageSender.owner(), address(this));
        assertEq(messageReceiver.owner(), address(this));
    }

    function test_send() public {
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(150_000, 0);

        MessagingFee memory fee = messageSender.quote(
            eidReceiver,
            "test message",
            options,
            false
        );

        assertFalse(messageListener.flagReceived());

        // will send msg to the endpoint of the receiver
        messageSender.send{value: fee.nativeFee}(
            eidReceiver,
            "test message",
            options,
            fee,
            address(this)
        );

        // DVN verifies the msg packet
        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        // Receiver receives the msg and sets the `messageListener.flagReceived` to true. `messageListener` is a contract who's address is passed to the `AddressTreeStateReceiver` contract during its deployment.
        assertTrue(messageListener.flagReceived());
    }
}
