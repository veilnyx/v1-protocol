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
import {MessageListener} from "src/core/MessageListener.sol";
import {PoolProxy} from "src/core/PoolProxy.sol";
import {AddressRegistry} from "src/core/AddressRegistry.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {PoolBaseTest} from "./fixtures/PoolBaseTest.sol";
import {Pool} from "src/core/Pool.sol";
import {MockPool} from "./mocks/MockPool.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {console2} from "forge-std/console2.sol";

contract AddressRegistryIntegrationTest is TestHelperOz5, PoolBaseTest {
    using OptionsBuilder for bytes;

    MockPool public dstChainPool = new MockPool();
    MessageSender public messageSender;
    MessageReceiver public messageReceiver;
    MessageListener public messageListener;

    uint32 public eidSender = 1;
    uint256 public originChainId = 1;
    uint32 public eidReceiver = 2;
    uint256 public dstChainId = 2;

    function setUp() public override {
        super.setUp();
        _setUp();

        // Integration test setup
        // Deploying destination chain pool
        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                fixture.addressTreeDepth,
                fixture.commitmentTreeDepth,
                fixture.commitmentTreeQueueSize,
                fixture.withdrawFeeBps,
                externalContracts
            )
        );

        PoolProxy dstChainPoolProxy = new PoolProxy(
            address(dstChainPool),
            initData
        );
        dstChainPool = MockPool(address(dstChainPoolProxy));

        // INFRA:
        // origin chain side: AddressRegistry, MessageSender
        // dst. chain side: MessageReceiver, MessageListener

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // MessageSender deployment
        messageSender = new MessageSender(
            endpoints[eidSender],
            address(addressRegistry)
        );
        addressRegistry.setMessageSender(
            payable(address(messageSender)),
            eidSender
        );

        // MessageListener deployment
        MessageListener messageListenerImpl = new MessageListener();
        bytes memory msgListenerInit = abi.encodeCall(
            messageListenerImpl.initialize,
            (address(dstChainPool))
        );

        messageListenerProxy = new ERC1967Proxy(
            address(messageListenerImpl),
            msgListenerInit
        );

        // messageReceiver --> messageListener --> dstPool
        IPool(dstChainPool).setAddressTreeUpdator(
            address(messageListenerProxy)
        );
        console2.log("dstChainPool address tree updated set");

        // MessageReceiver deployment
        messageReceiver = new MessageReceiver(
            endpoints[eidReceiver],
            address(this),
            address(messageListenerProxy)
        );

        // transferring ownership of msgReceiver to addressRegistry to call `setPeer()`
        messageReceiver.transferOwnership(address(addressRegistry));

        addressRegistry.setChainAndPeer(
            dstChainId,
            eidReceiver,
            payable(address(messageReceiver))
        );
    }

    function test_registerAddressCallAndPropogationOfStateCrossChain() public {
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _prepareShieldedAddrRegStruct();

        vm.deal(payable(address(addressRegistry)), 5 ether);
        pool.registerAddress(addressRegistrationData);

        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        (uint256 originPoolLastRoot, uint8 originPoolCurrentRootIndex) = pool
            .getAddressTreeState();

        (uint256 dstPoolLastRoot, uint8 dstPoolCurrentRootIndex) = dstChainPool
            .getAddressTreeState();

        assertEq(originPoolLastRoot, dstPoolLastRoot);
        assertEq(originPoolCurrentRootIndex, dstPoolCurrentRootIndex);
    }

    function _prepareShieldedAddrRegStruct()
        internal
        returns (ShieldedAddressRegistrationData memory)
    {
        address senderAddr;
        uint256 senderPK;
        (senderAddr, senderPK) = makeAddrAndKey("sender");
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _loadShieldedAddressRegistrationData(
                "register_sender"
            );

        bytes memory shieldedAddress = bytes.concat(
            bytes32(fixture.sender.rootAddress),
            bytes32(fixture.sender.signPublicKey[0]),
            bytes32(fixture.sender.signPublicKey[1]),
            bytes32(fixture.sender.viewPublicKey[0]),
            bytes32(fixture.sender.viewPublicKey[1])
        );

        /// @dev using the same `senderPK` private key to sign the msg and update the fixture.
        addressRegistrationData.signature = _getRegisterAddressSignature(
            senderPK,
            shieldedAddress
        );
        return addressRegistrationData;
    }
}
