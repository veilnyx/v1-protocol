// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { Packet } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { MessageSender } from "src/core/MessageSender.sol";
import { MessageReceiver } from "src/core/MessageReceiver.sol";

contract MockMessageListener {
    bool public flagReceived = false;

    function onMessage(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata payload,
        address executor,
        bytes calldata options
    )
        public
    {
        flagReceived = true;
    }
}

contract MessageSenderTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    MessageSender public messageSender;
    MessageReceiver public messageReceiver;
    MockMessageListener public messageListener;

    uint32 public eidSender = 1;
    uint32 public eidReceiver = 2;

    function setUp() public virtual override {
        super.setUp();

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        messageListener = new MockMessageListener();
        messageSender = new MessageSender(endpoints[eidSender], address(this));
        messageReceiver = new MessageReceiver(endpoints[eidReceiver], address(this), address(messageListener));

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
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(150_000, 0);
        MessagingFee memory fee = messageSender.quote(eidReceiver, "test message", options, false);

        assertFalse(messageListener.flagReceived());

        MessagingReceipt memory receipt =
            messageSender.send{ value: fee.nativeFee }(eidReceiver, "test message", options, fee, address(this));
        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        assertTrue(messageListener.flagReceived());
    }
}
