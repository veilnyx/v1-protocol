// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AddressTreeStateTransmitter} from "src/core/AddressTreeStateTransmitter.sol";
import {AddressTreeStateReceiver} from "src/core/AddressTreeStateReceiver.sol";
import {AddressTreeStateUpdater} from "src/core/AddressTreeStateUpdater.sol";
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
    AddressTreeStateTransmitter public messageSender;
    AddressTreeStateReceiver public messageReceiver;
    AddressTreeStateUpdater public messageListener;

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
        // origin chain side: AddressRegistry, AddressTreeStateTransmitter
        // dst. chain side: AddressTreeStateReceiver, AddressTreeStateUpdater

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // AddressTreeStateTransmitter deployment
        messageSender = new AddressTreeStateTransmitter(
            endpoints[eidSender],
            address(addressRegistry)
        );
        addressRegistry.setMessageSender(
            payable(address(messageSender)),
            eidSender
        );

        // AddressTreeStateUpdater deployment
        AddressTreeStateUpdater messageListenerImpl = new AddressTreeStateUpdater();
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

        // AddressTreeStateReceiver deployment
        messageReceiver = new AddressTreeStateReceiver(
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

    function test_revertDueToLowGasValue() public {
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _prepareShieldedAddrRegStruct();
        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas / 2);

        vm.expectRevert(
            abi.encodeWithSelector(AddressRegistry.NotEnoughEther.selector)
        );
        pool.registerAddress{value: address(this).balance}(
            addressRegistrationData
        );
    }

    function test_registerAddressCallAndPropogationOfStateCrossChain() public {
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _prepareShieldedAddrRegStruct();

        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas);
        pool.registerAddress{value: totalNativeGas}(addressRegistrationData);

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
