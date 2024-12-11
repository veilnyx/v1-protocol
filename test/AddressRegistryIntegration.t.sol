// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// LZ
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IExecutor} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/interfaces/IExecutor.sol";
import {ExecutorOptions} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";
import {PacketV1Codec} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/PacketV1Codec.sol";
import {EndpointV2Mock as EndpointV2} from "@layerzerolabs/test-devtools-evm-foundry/contracts//mocks//EndpointV2Mock.sol";
import {OptionsHelper} from "@layerzerolabs/test-devtools-evm-foundry/contracts/OptionsHelper.sol";

// Oz
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

// Labyrinth
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
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using PacketV1Codec for bytes;

    MockPool public dstChainPool = new MockPool();
    AddressTreeStateTransmitter public stateTransmitter;
    AddressTreeStateReceiver public stateReceiver;
    AddressTreeStateUpdater public stateUpdator;

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
        stateTransmitter = new AddressTreeStateTransmitter(
            endpoints[eidSender],
            address(addressRegistry)
        );
        addressRegistry.setAddrTreeStateTransmitter(
            payable(address(stateTransmitter)),
            eidSender
        );

        // AddressTreeStateUpdater deployment
        AddressTreeStateUpdater stateUpdaterImpl = new AddressTreeStateUpdater();
        bytes memory msgListenerInit = abi.encodeCall(
            stateUpdaterImpl.initialize,
            (address(dstChainPool))
        );

        ERC1967Proxy stateUpdatorProxy = new ERC1967Proxy(
            address(stateUpdaterImpl),
            msgListenerInit
        );
        stateUpdator = AddressTreeStateUpdater(address(stateUpdatorProxy));

        // stateReceiver --> stateUpdator --> dstPool
        IPool(dstChainPool).setAddressTreeUpdator(address(stateUpdator));
        console2.log("dstChainPool address tree updated set");

        // AddressTreeStateReceiver deployment
        stateReceiver = new AddressTreeStateReceiver(
            endpoints[eidReceiver],
            address(this),
            address(stateUpdator)
        );

        // transferring ownership of msgReceiver to addressRegistry to call `setPeer()`
        stateReceiver.transferOwnership(address(addressRegistry));
        stateUpdator.setReceiver(address(stateReceiver));

        addressRegistry.setChainAndPeer(
            dstChainId,
            eidReceiver,
            payable(address(stateReceiver))
        );
    }

    function test_revertDueToLowGasValue() public {
        (
            ShieldedAddressRegistrationData memory addressRegistrationData,

        ) = _prepareShieldedAddrRegStruct();
        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas / 2);

        vm.expectRevert(
            abi.encodeWithSelector(AddressRegistry.NotEnoughEther.selector)
        );
        pool.registerAddress{value: address(this).balance}(
            addressRegistrationData
        );
    }

    function test_revertWhenOldReceiverCallsUpdater() external {
        address newReceiver = makeAddr("newReceiver");
        stateUpdator.setReceiver(newReceiver);

        (
            ShieldedAddressRegistrationData memory addressRegistrationData,

        ) = _prepareShieldedAddrRegStruct();

        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        vm.deal(address(this), totalNativeGas);
        pool.registerAddress{value: totalNativeGas}(addressRegistrationData);

        _verifyPacketsWithRevertCheck(
            eidReceiver,
            addressToBytes32(address(stateReceiver)),
            0,
            address(0x0),
            address(stateReceiver)
        );
    }

    function test_registerAddressCallAndPropogationOfStateCrossChain() public {
        (
            ShieldedAddressRegistrationData memory addressRegistrationData,
            address senderAddr
        ) = _prepareShieldedAddrRegStruct();

        (, uint256 totalNativeGas) = addressRegistry.getRegistrationFees();
        uint256 extraGas = 0.25 ether;
        vm.deal(senderAddr, (totalNativeGas + extraGas));
        console2.log(
            "Sender native bal before registration:",
            senderAddr.balance
        );

        vm.prank(senderAddr);
        pool.registerAddress{value: totalNativeGas + extraGas}(addressRegistrationData);

        console2.log("Sender bal after initiating call:", senderAddr.balance);
        verifyPackets(eidReceiver, addressToBytes32(address(stateReceiver)));

        (uint256 originPoolLastRoot, uint8 originPoolCurrentRootIndex) = pool
            .getAddressTreeState();

        (uint256 dstPoolLastRoot, uint8 dstPoolCurrentRootIndex) = dstChainPool
            .getAddressTreeState();

        assertEq(originPoolLastRoot, dstPoolLastRoot);
        assertEq(originPoolCurrentRootIndex, dstPoolCurrentRootIndex);
        assertEq(senderAddr.balance, extraGas);
        console2.log(
            "Sender native bal after registration (refund?):",
            senderAddr.balance
        );
    }

    function _prepareShieldedAddrRegStruct()
        internal
        returns (ShieldedAddressRegistrationData memory, address)
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
        return (addressRegistrationData, senderAddr);
    }

    function _verifyPacketsWithRevertCheck(
        uint32 _dstEid,
        bytes32 _dstAddress,
        uint256 _packetAmount,
        address _composer,
        address oldStateReceiver
    ) internal {
        require(
            endpoints[_dstEid] != address(0),
            "endpoint not yet registered"
        );

        DoubleEndedQueue.Bytes32Deque storage queue = packetsQueue[_dstEid][
            _dstAddress
        ];
        uint256 pendingPacketsSize = queue.length();
        uint256 numberOfPackets;
        if (_packetAmount == 0) {
            numberOfPackets = queue.length();
        } else {
            numberOfPackets = pendingPacketsSize > _packetAmount
                ? _packetAmount
                : pendingPacketsSize;
        }
        while (numberOfPackets > 0) {
            numberOfPackets--;
            // front in, back out
            bytes32 guid = queue.popBack();
            bytes memory packetBytes = packets[guid];
            this.assertGuid(packetBytes, guid);
            this.validatePacket(packetBytes);

            bytes memory options = optionsLookup[guid];
            if (
                _executorOptionExists(
                    options,
                    ExecutorOptions.OPTION_TYPE_NATIVE_DROP
                )
            ) {
                (
                    uint256 amount,
                    bytes32 receiver
                ) = _parseExecutorNativeDropOption(options);
                address to = address(uint160(uint256(receiver)));
                (bool sent, ) = to.call{value: amount}("");
                require(sent, "Failed to send Ether");
            }
            if (
                _executorOptionExists(
                    options,
                    ExecutorOptions.OPTION_TYPE_LZRECEIVE
                )
            ) {
                this._lzReceiveWithRevertCheck(
                    packetBytes,
                    options,
                    oldStateReceiver
                );
            }
            if (
                _composer != address(0) &&
                _executorOptionExists(
                    options,
                    ExecutorOptions.OPTION_TYPE_LZCOMPOSE
                )
            ) {
                this.lzCompose(packetBytes, options, guid, _composer);
            }
        }
    }

    function _lzReceiveWithRevertCheck(
        bytes calldata _packetBytes,
        bytes memory _options,
        address oldStateReceiver
    ) public payable {
        EndpointV2 endpoint = EndpointV2(endpoints[_packetBytes.dstEid()]);
        (uint256 gas, uint256 value) = OptionsHelper
            ._parseExecutorLzReceiveOption(_options);

        Origin memory origin = Origin(
            _packetBytes.srcEid(),
            _packetBytes.sender(),
            _packetBytes.nonce()
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                AddressTreeStateUpdater.UnauthorizedSender.selector,
                payable(address(oldStateReceiver))
            )
        );
        endpoint.lzReceive{value: value, gas: gas}(
            origin,
            _packetBytes.receiverB20(),
            _packetBytes.guid(),
            _packetBytes.message(),
            bytes("")
        );
    }
}
