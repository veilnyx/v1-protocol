// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Pool} from "src/core/Pool.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolProxy} from "src/core/PoolProxy.sol";
import {MessageSender} from "src/core/MessageSender.sol";
import {MessageReceiver, IMessageListener} from "src/core/MessageReceiver.sol";
import {MessageListener} from "src/core/MessageListener.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {AddressRegistry} from "src/core/AddressRegistry.sol";
import {PoolBaseTest} from "./fixtures/PoolBaseTest.sol";
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

contract AddressRegistryTest is TestHelperOz5, PoolBaseTest {
    using OptionsBuilder for bytes;

    MockPool dstChainPool = new MockPool();
    MessageSender public messageSender;
    MessageReceiver public messageReceiver;
    MockMessageListener public mockMessageListener;

    uint32 public eidSender = 1;
    uint256 public originChainId = 1;
    uint32 public eidReceiver = 2;
    uint256 public dstChainId = 2;

    function setUp() public override {
        console2.log("setUp");
        super.setUp();
        _setUp();

        // Initialize 2 endpoints, using UltraLightNode as the library type
        setUpEndpoints(2, LibraryType.UltraLightNode);

        messageSender = new MessageSender(
            endpoints[eidSender],
            address(addressRegistry)
        );

        addressRegistry.setMessageSender(
            payable(address(messageSender)),
            eidSender
        );

        mockMessageListener = new MockMessageListener();
        messageReceiver = new MessageReceiver(
            endpoints[eidReceiver],
            address(this),
            address(mockMessageListener)
        );

        // transferring ownership of msgReceiver to addressRegistry to call `setPeer()`
        messageReceiver.transferOwnership(address(addressRegistry));

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

        // assertTrue(mockMessageListener.flagReceived());

        // sending native eth to addressRegistry for LZ fee
        vm.deal(address(this), 5 ether);
        MessagingReceipt memory receipt = addressRegistry.syncTreeState{
            value: 5 ether
        }();

        // DVN verifies the msg packet
        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        assertEq(
            addressRegistry.getTreeRoot(),
            mockMessageListener.getTreeRoot()
        );
    }

    function test_registerAddressAndAddressTreeUpdate() public {
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _prepareShieldedAddrRegStruct();

        vm.deal(payable(address(addressRegistry)), 5 ether);
        MessagingReceipt memory receipt = pool.registerAddress(
            addressRegistrationData
        );

        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        (uint256 originPoolLastRoot, uint8 originPoolCurrentRootIndex) = pool
            .getAddressTreeState();

        uint8 dstCurrentRootIndex = mockMessageListener.currentRootIndex();
        uint256 dstLastRoot = mockMessageListener.getTreeRoot();

        assertEq(originPoolLastRoot, dstLastRoot);
        assertEq(originPoolCurrentRootIndex, dstCurrentRootIndex);
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
