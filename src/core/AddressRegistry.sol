// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {MerkleTree} from "@openzeppelin/contracts/utils/structs/MerkleTree.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AddressTreeStateTransmitter} from "./AddressTreeStateTransmitter.sol";
import {AddressTreeStateReceiver} from "./AddressTreeStateReceiver.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {ZERO_LEAF, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EIP712_TYPEHASH_REGISTER_ADDRESS, MESSAGE_REGISTER_ADDRESS, SIZE_UNPACKED_SHIELDED_ADDRESS} from "../base/Constants.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "../libraries/ShieldedAddress.sol";

struct MerkleTreeStorage {
    uint8 currentRootIndex;
    mapping(uint8 => uint256) roots;
}

struct TreeTransmitterInfo {
    address payable transmitterAddr;
    uint32 transmitterEid;
}

/**
 * @dev The cross-chain address registration system comprises of the following contracts:
 * 1. AddressRegistry: The contract that manages the address registration process.
 * 2. AddressTreeStateTransmitter: The contract that sends the address registration
 * message to the destination chain.
 * 3. AddressTreeStateReceiver: The contract that receives the address registration
 * message from the source chain.
 * 4. AddressTreeStateUpdater: The contract that updates the address tree state on the
 * destination chain.
 */
contract AddressRegistry is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable
{
    using OptionsBuilder for bytes;
    using MerkleTree for MerkleTree.Bytes32PushTree;
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using EnumerableMap for EnumerableMap.UintToBytes32Map;

    error NotEnoughEther();
    error ExcessEtherRefundFailed();

    address public verifier;
    address public hasher;
    mapping(address publicAddr => uint256 rootAddr) internal publicAddresses;
    mapping(uint256 rootAddr => bool isRegistered) internal rootAddresses;
    bytes internal _lzOptions;
    MerkleTreeStorage public addressTreeStorage;
    MerkleTree.Bytes32PushTree public addressTree;
    EnumerableMap.UintToUintMap internal _lzEIds;
    EnumerableMap.UintToBytes32Map internal _chainIdToPeerAddrInBytes32;
    TreeTransmitterInfo internal _treeStateTransmitter;

    /**
     * Gas profiling:
     * decoding hash: 50_000
     * changing state from zero to non-zero values: 20_000
     * updating non-zero value: 3_000
     * total = 73k => 100k (approx)
     */
    uint128 public constant DST_CHAIN_ADDRESS_TREE_UPDATE_GAS = 150_000;
    uint8 public constant ROOT_HISTORY_SIZE = 100;

    function initialize(
        uint8 treeDepth_,
        address verifier_,
        address hasher_
    ) external initializer {
        verifier = verifier_;
        hasher = hasher_;
        addressTreeStorage.currentRootIndex = 0;
        addressTreeStorage.roots[addressTreeStorage.currentRootIndex] = uint256(
            addressTree.setup(treeDepth_, bytes32(ZERO_LEAF), _hashLeaves)
        );
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __EIP712_init(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);
    }

    function setAddrTreeStateTransmitter(
        address payable newMessageSender,
        uint32 newMessageSenderEid
    ) external onlyOwner {
        _treeStateTransmitter.transmitterAddr = newMessageSender;
        _treeStateTransmitter.transmitterEid = newMessageSenderEid;
    }

    function setChainAndPeer(
        uint256 chainId,
        uint32 eid,
        address payable peerAddress
    ) external onlyOwner {
        if (chainId == block.chainid) {
            revert("AddressRegistry: cannot set lzEId for self chain");
        }

        _lzEIds.set(chainId, eid);
        _chainIdToPeerAddrInBytes32.set(
            chainId,
            _addressToBytes32(peerAddress)
        );

        // Setting peer for sender
        AddressTreeStateTransmitter(_treeStateTransmitter.transmitterAddr)
            .setPeer(eid, _addressToBytes32(peerAddress));

        // Setting peer for receiver
        AddressTreeStateReceiver(peerAddress).setPeer(
            _treeStateTransmitter.transmitterEid,
            _addressToBytes32(_treeStateTransmitter.transmitterAddr)
        );
    }

    function syncTreeState(address refundAddress) external payable onlyOwner {
        if (refundAddress == address(0)) {
            refundAddress = address(this);
        }
        _syncTreeState(refundAddress);
    }

    function register(
        ShieldedAddressRegistrationData calldata self
    ) external payable returns (uint256 updatedRoot, uint8 currentRootIndex) {
        uint256 rootAddress = uint256(bytes32(self.shieldedAddress[0:32]));

        if (rootAddresses[rootAddress]) {
            revert IPool.RootAddressAlreadyRegistered(rootAddress);
        }

        if (self.shieldedAddress.length != SIZE_UNPACKED_SHIELDED_ADDRESS) {
            revert IPool.BadArguments();
        }

        if (!verifyProof(self)) {
            revert IPool.InvalidAddressProof();
        }

        (, uint256 totalFeeNeeded) = getRegistrationFees();
        if (totalFeeNeeded > address(this).balance) {
            revert NotEnoughEther();
        }

        bytes32 hashStruct = _hashRegsiterAddressStruct(self.shieldedAddress);
        bytes32 hashTypedData = _hashTypedDataV4(hashStruct);
        address publicAddress = ECDSA.recover(hashTypedData, self.signature);

        if (publicAddresses[publicAddress] != 0) {
            revert IPool.PublicAddressAlreadyRegistered(publicAddress);
        }

        // returning any excess fee
        // in addition to this, if estimated fee > actual fee used by LZ, it will be refunded to the publicAddress being registered
        uint256 feeDiff = address(this).balance - totalFeeNeeded;
        if (feeDiff > 0) {
            (bool success, ) = publicAddress.call{value: feeDiff}("");
            if (!success) {
                revert ExcessEtherRefundFailed();
            }
        }

        uint32 insertedAtIndex = _insertAddress(rootAddress);
        rootAddresses[rootAddress] = true;
        publicAddresses[publicAddress] = rootAddress;

        _syncTreeState(publicAddress);

        emit IPool.RegisterAddress(
            publicAddress,
            rootAddress,
            insertedAtIndex,
            ShieldedAddressLogic.packShieldedAddress(self.shieldedAddress)
        );

        currentRootIndex = addressTreeStorage.currentRootIndex;
        return (addressTreeStorage.roots[currentRootIndex], currentRootIndex);
    }

    function isKnownRoot(uint256 _root) public view returns (bool) {
        if (_root == 0) {
            return false;
        }

        uint8 _currentRootIndex = addressTreeStorage.currentRootIndex;
        uint8 i = _currentRootIndex; // currentRootIndex -> 0
        do {
            if (_root == addressTreeStorage.roots[i]) {
                return true;
            }
            if (i == 0) {
                // ROOT_HISTORY_SIZE -> currentRootIndex + 1
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    function getRegistrationFees()
        public
        view
        returns (MessagingFee[] memory, uint256 totalNativeRegistrationFee)
    {
        bytes memory message = abi.encode(
            addressTreeStorage.roots[addressTreeStorage.currentRootIndex],
            addressTreeStorage.currentRootIndex
        );

        MessagingFee[] memory fees = new MessagingFee[](_lzEIds.length());
        uint256 eid;

        // _lzEIds.length() = no. of chains
        for (uint8 i = 0; i < _lzEIds.length(); ++i) {
            (, eid) = _lzEIds.at(i);
            (, bytes32 peerAddrInBytes32) = _chainIdToPeerAddrInBytes32.at(i);
            // q should the gas param to addExecutorLzReceiveOption be non-zero?
            bytes memory _lzOptions = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(
                    DST_CHAIN_ADDRESS_TREE_UPDATE_GAS,
                    0
                );
            // .addExecutorNativeDropOption(0.0001 ether, peerAddrInBytes32);

            fees[i] = AddressTreeStateTransmitter(
                _treeStateTransmitter.transmitterAddr
            ).quote(uint32(eid), message, _lzOptions, false);

            totalNativeRegistrationFee += fees[i].nativeFee;
        }

        return (fees, totalNativeRegistrationFee);
    }

    function verifyProof(
        ShieldedAddressRegistrationData calldata self
    ) public view returns (bool) {
        bytes memory vInp = abi.encodePacked(self.proof, self.shieldedAddress);
        return IVerifier(verifier).verifyAddressProof(vInp);
    }

    function getTreeRoot() external view returns (uint256) {
        return addressTreeStorage.roots[addressTreeStorage.currentRootIndex];
    }

    function _syncTreeState(address refundAddress) internal {
        bytes memory message = abi.encode(
            addressTreeStorage.roots[addressTreeStorage.currentRootIndex],
            addressTreeStorage.currentRootIndex
        );

        (MessagingFee[] memory dstChainFees, ) = getRegistrationFees();

        uint256 eid;
        // _lzEIds.length() = no. of chains
        for (uint8 i = 0; i < _lzEIds.length(); ++i) {
            (, eid) = _lzEIds.at(i);
            (, bytes32 peerAddrInBytes32) = _chainIdToPeerAddrInBytes32.at(i);
            bytes memory _lzOptions = OptionsBuilder
                .newOptions()
                .addExecutorLzReceiveOption(
                    DST_CHAIN_ADDRESS_TREE_UPDATE_GAS,
                    0
                );
            // .addExecutorNativeDropOption(0.0001 ether, peerAddrInBytes32);

            AddressTreeStateTransmitter(_treeStateTransmitter.transmitterAddr)
                .send{value: (dstChainFees[i].nativeFee)}(
                uint32(eid),
                message,
                _lzOptions,
                dstChainFees[i],
                refundAddress
            );
        }
    }

    function _insertAddress(uint256 rootAddress) internal returns (uint32) {
        (uint256 index, bytes32 root) = addressTree.push(
            bytes32(rootAddress),
            _hashLeaves
        );

        addressTreeStorage.currentRootIndex++;
        addressTreeStorage.roots[addressTreeStorage.currentRootIndex] = uint256(
            root
        );
        return uint32(index);
    }

    function _hashRegsiterAddressStruct(
        bytes calldata shieldedAddress
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_TYPEHASH_REGISTER_ADDRESS,
                    keccak256(bytes(MESSAGE_REGISTER_ADDRESS)),
                    keccak256(shieldedAddress)
                )
            );
    }

    function _hashLeaves(
        bytes32 left,
        bytes32 right
    ) internal view returns (bytes32) {
        return bytes32(IHasher(hasher).hash([uint256(left), uint256(right)]));
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
