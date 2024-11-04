// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { Packet } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MessageSender } from "src/core/MessageSender.sol";
import { MessageReceiver } from "src/core/MessageReceiver.sol";
import { AddressRegistry } from "src/core/AddressRegistry.sol";
import { BaseTest } from "./fixtures/BaseTest.sol";
import { console2 } from "forge-std/console2.sol";

contract MockMessageListener {
    uint256 public root;

    function onMessage(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata payload,
        address executor,
        bytes calldata options
    )
        public
    {
        root = uint256(abi.decode(payload, (uint256)));
    }
}

contract AddressRegistryTest is TestHelperOz5, BaseTest {
    using OptionsBuilder for bytes;

    MockMessageListener public messageListener;
    MessageSender public messageSender;
    MessageReceiver public messageReceiver;
    AddressRegistry public addressRegistry;

    uint32 public eidSender = 1;
    uint32 public eidReceiver = 2;

    function setUp() public override {
        console2.log("setUp");
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

        address hasher = address(_deployHasher());

        address addressRegistryImpl = address(new AddressRegistry());
        bytes memory initData = abi.encodeCall(AddressRegistry.initialize, (25, address(0), hasher));
        ERC1967Proxy addressRegistryProxy = new ERC1967Proxy(addressRegistryImpl, initData);
        addressRegistry = AddressRegistry(payable(address(addressRegistryProxy)));

        messageSender.transferOwnership(address(addressRegistry));
        addressRegistry.setMessageSender(payable(address(messageSender)));
        addressRegistry.setChainAndPeer(1, eidReceiver, address(messageReceiver));
    }

    // function test_constructor() public view {
    //     assertEq(messageSender.owner(), address(this));
    //     assertEq(messageReceiver.owner(), address(this));
    // }

    function test_syncTreeState() public {
        // bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(150_000, 0);
        // MessagingFee memory fee = messageSender.quote(eidReceiver, "test message", options, false);

        // MessagingReceipt memory receipt =
        //     messageSender.send{ value: fee.nativeFee }(eidReceiver, "test message", options, fee, address(this));
        // verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        // assertTrue(messageListener.flagReceived());
        addressRegistry.syncTreeState();
        console2.log("root", addressRegistry.getTreeRoot());
        console2.log("root", messageListener.root());
    }
}
