// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageSender} from "src/core/MessageSender.sol";
import {MessageReceiver, IMessageListener} from "src/core/MessageReceiver.sol";
import {AddressRegistry} from "src/core/AddressRegistry.sol";
import {BaseTest} from "./fixtures/BaseTest.sol";
import {console2} from "forge-std/console2.sol";

contract MockMessageListener is IMessageListener {
    uint32 public eidReceiver = 2;
    uint8 public currentRootIndex;
    mapping(uint8 => uint256) public roots;

    function onMessage(
        Origin calldata origin,
        bytes calldata payload,
        address executor,
        bytes calldata options
    ) public {
        console2.log("inside mockListener.onMessage");
        console2.log("Executor used:");
        console2.logAddress(executor);
        // (, , , uint128 nativeCap, ) = IExecutor(executor).dstConfig(eidReceiver);
        // console2.log("Executor gas cap:", nativeCap);
        console2.logBytes(payload);
        (uint256 root, uint8 index) = abi.decode(payload, (uint256, uint8));
        console2.log("Root decoded", root);
        console2.log("Index decoded", index);
        roots[index] = root;
        currentRootIndex = index;
    }

    function getTreeRoot() public view returns (uint256) {
        return roots[currentRootIndex];
    }
}

contract AddressRegistryTest is TestHelperOz5, BaseTest {
    using OptionsBuilder for bytes;

    MockMessageListener public messageListener;
    MessageSender public messageSender;
    MessageReceiver public messageReceiver;
    AddressRegistry public addressRegistry;

    uint32 public eidSender = 1;
    uint256 public originChainId = 1;
    uint32 public eidReceiver = 2;
    uint256 public dstChainId = 2;

    function setUp() public override {
        console2.log("setUp");
        super.setUp();

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        messageListener = new MockMessageListener();
        messageSender = new MessageSender(endpoints[eidSender], address(this));
        messageReceiver = new MessageReceiver(
            endpoints[eidReceiver],
            address(this),
            address(messageListener)
        );

        address[] memory oApps = new address[](2);
        oApps[0] = address(messageSender);
        oApps[1] = address(messageReceiver);
        // wireOApps(oApps); // not using wireOApps(), instead setting peers using `AddressRegistry::setChainAndPeer()`. Ref line 104.

        address hasher = address(_deployHasher());

        address addressRegistryImpl = address(new AddressRegistry());
        bytes memory initData = abi.encodeCall(
            AddressRegistry.initialize,
            (25, address(0), hasher)
        );

        ERC1967Proxy addressRegistryProxy = new ERC1967Proxy(
            addressRegistryImpl,
            initData
        );
        addressRegistry = AddressRegistry(
            payable(address(addressRegistryProxy))
        );
        console2.log("addressRegistry initialised", address(addressRegistry));

        messageSender.transferOwnership(address(addressRegistry));
        messageReceiver.transferOwnership(address(addressRegistry));

        addressRegistry.setMessageSender(
            payable(address(messageSender)),
            eidSender
        );

        addressRegistry.setChainAndPeer(
            dstChainId,
            eidReceiver,
            payable(address(messageReceiver))
        );
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

        // sending native eth to addressRegistry for LZ fee
        vm.deal(address(this), 5 ether);
        MessagingReceipt memory receipt = addressRegistry.syncTreeState{
            value: 5 ether
        }();

        // DVN verifies the msg packet
        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        assertEq(addressRegistry.getTreeRoot(), messageListener.getTreeRoot());
    }
}
