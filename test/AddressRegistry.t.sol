// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {Errors} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/Errors.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Pool} from "src/core/Pool.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {PoolProxy} from "src/core/PoolProxy.sol";
import {AddressTreeStateTransmitter} from "src/core/AddressTreeStateTransmitter.sol";
import {AddressTreeStateReceiver, IAddressTreeStateUpdater} from "src/core/AddressTreeStateReceiver.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddress.sol";
import {AddressRegistry} from "src/core/AddressRegistry.sol";
import {PoolBaseTest} from "./fixtures/PoolBaseTest.sol";
import {console2} from "forge-std/console2.sol";

contract MockAddressTreeStateUpdater is IAddressTreeStateUpdater {
    uint32 public eidReceiver = 2;
    uint8 public currentRootIndex;
    mapping(uint8 => uint256) public roots;

    function updateAddressTreeState(bytes calldata payload) public {
        console2.log("inside mockListener.onMessage");
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
    AddressTreeStateTransmitter public messageSender;
    AddressTreeStateReceiver public messageReceiver;
    MockAddressTreeStateUpdater public mockUpdater;

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

        messageSender = new AddressTreeStateTransmitter(
            endpoints[eidSender],
            address(addressRegistry)
        );

        addressRegistry.setAddrTreeStateTransmitter(
            payable(address(messageSender)),
            eidSender
        );

        mockUpdater = new MockAddressTreeStateUpdater();
        messageReceiver = new AddressTreeStateReceiver(
            endpoints[eidReceiver],
            address(this),
            address(mockUpdater)
        );

        // transferring ownership of msgReceiver to addressRegistry to call `setPeer()`
        messageReceiver.transferOwnership(address(addressRegistry));

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

        addressRegistry.setChainAndPeer(
            dstChainId,
            eidReceiver,
            payable(address(messageReceiver))
        );
    }

    function test_registrationFeeEstimate() public {
        (
            MessagingFee[] memory dstChainFees,
            uint256 totalNativeFee
        ) = addressRegistry.getRegistrationFees();

        console2.log("native fee:", dstChainFees[0].nativeFee);
        // 120000000110516 = 1.2e14
        assert(dstChainFees[0].nativeFee > 0);
        assert(totalNativeFee > 0);
        // q when sending 0.01 ether as the `value` attr. in the LZ Options, the actual value sent increases by 0.02 ether!
        // native fee returned when LZ Option value param is 0 = 110516
        // native fee returned when LZ Option value param is 0.01 ether = 12000000000110516
        // Expected: 10000000000000000 + 110516 = 10000000000110516
        // Received:12000000000110516
        // Diff: 12000000000110516 - 10000000000110516 = 20000000000000000 (2e16 = 0.02e18)?
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

        // assertTrue(mockUpdater.flagReceived());

        // sending native eth to addressRegistry for LZ fee
        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas);
        addressRegistry.syncTreeState{value: totalNativeGas}(address(this));

        // DVN verifies the msg packet
        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        assertEq(addressRegistry.getTreeRoot(), mockUpdater.getTreeRoot());
    }

    function test_registerAddressAndAddressTreeUpdate() public {
        ShieldedAddressRegistrationData
            memory addressRegistrationData = _prepareShieldedAddrRegStruct();

        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas);
        pool.registerAddress{value: totalNativeGas}(addressRegistrationData);

        verifyPackets(eidReceiver, addressToBytes32(address(messageReceiver)));

        (uint256 originPoolLastRoot, uint8 originPoolCurrentRootIndex) = pool
            .getAddressTreeState();

        uint8 dstCurrentRootIndex = mockUpdater.currentRootIndex();
        uint256 dstLastRoot = mockUpdater.getTreeRoot();

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
