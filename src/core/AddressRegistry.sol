// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { MerkleTree } from "@openzeppelin/contracts/utils/structs/MerkleTree.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageSender } from "./MessageSender.sol";
import { ShieldedAddressRegistrationData } from "../libraries/ShieldedAddress.sol";
import { IPool } from "../interfaces/IPool.sol";
import { IVerifier } from "../interfaces/IVerifier.sol";
import { IHasher } from "../interfaces/IHasher.sol";
import {
    ZERO_LEAF,
    EIP712_DOMAIN_NAME,
    EIP712_DOMAIN_VERSION,
    EIP712_TYPEHASH_REGISTER_ADDRESS,
    MESSAGE_REGISTER_ADDRESS,
    FIELD_SIZE_DIV_2
} from "../base/Constants.sol";

contract AddressRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable {
    using OptionsBuilder for bytes;
    using MerkleTree for MerkleTree.Bytes32PushTree;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    bytes32 public constant MASK_PACK = hex"8000000000000000000000000000000000000000000000000000000000000000";

    uint256 public constant SIZE_UNPACKED_SHIELDED_ADDRESS = 160;

    uint256 public immutable SELF_CHAIN_ID = block.chainid;

    bytes _options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(50_000, 0);

    MerkleTree.Bytes32PushTree internal _tree;
    uint256 internal _nextLeafIndex;
    uint256 internal _treeRoot;

    address public verifier;
    address public hasher;
    address payable public messageSender;

    mapping(uint256 rootAddr => bool isRegistered) internal rootAddresses;

    mapping(address publicAddr => uint256 rootAddr) internal publicAddresses;

    EnumerableMap.UintToUintMap internal _lzEIds;

    function initialize(uint8 treeDepth_, address verifier_, address hasher_) external initializer {
        verifier = verifier_;
        hasher = hasher_;
        _treeRoot = uint256(_tree.setup(treeDepth_, bytes32(ZERO_LEAF), _hashLeaves));
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __EIP712_init(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);
    }

    function setMessageSender(address payable newMessageSender) external onlyOwner {
        messageSender = newMessageSender;
    }

    function setChainAndPeer(uint256 chainId, uint256 eid, address peerAddress) external onlyOwner {
        if (chainId == SELF_CHAIN_ID) {
            revert("AddressRegistry: cannot set lzEId for self chain");
        }

        _lzEIds.set(chainId, eid);
        // MessageSender(messageSender).setPeer(uint32(eid), _addressToBytes32(peerAddress));
    }

    function syncTreeState() external payable {
        _syncTreeState();
    }

    function register(ShieldedAddressRegistrationData calldata self) external {
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

        bytes32 hashStruct = _hashRegsiterAddressStruct(self.shieldedAddress);
        bytes32 hashTypedData = _hashTypedDataV4(hashStruct);
        address publicAddress = ECDSA.recover(hashTypedData, self.signature);

        if (publicAddresses[publicAddress] != 0) {
            revert IPool.PublicAddressAlreadyRegistered(publicAddress);
        }

        uint32 index = _insertAddress(rootAddress);
        rootAddresses[rootAddress] = true;
        publicAddresses[publicAddress] = rootAddress;

        _syncTreeState();

        emit IPool.RegisterAddress(publicAddress, rootAddress, index, _packShieldedAddress(self.shieldedAddress));
    }

    function getRegistrationFees() external view returns (uint256[] memory, MessagingFee[] memory) {
        bytes memory message = abi.encodePacked(_treeRoot);

        uint256 nChains = _lzEIds.length();
        uint256[] memory chainIds = new uint256[](nChains);
        MessagingFee[] memory fees = new MessagingFee[](nChains);

        uint256 eid;
        for (uint8 i = 0; i < nChains; ++i) {
            (chainIds[i], eid) = _lzEIds.at(i);
            fees[i] = MessageSender(messageSender).quote(uint32(eid), message, _options, false);
        }

        return (chainIds, fees);
    }

    function verifyProof(ShieldedAddressRegistrationData calldata self) public view returns (bool) {
        bytes memory vInp = abi.encodePacked(self.proof, self.shieldedAddress);
        return IVerifier(verifier).verifyAddressProof(vInp);
    }

    function getTreeRoot() external view returns (uint256) {
        return _treeRoot;
    }

    function _syncTreeState() internal {
        bytes memory message = abi.encodePacked(_treeRoot);

        uint256 nChains = _lzEIds.length();

        uint256 eid;
        for (uint8 i = 0; i < nChains; ++i) {
            (, eid) = _lzEIds.at(i);
            MessageSender(messageSender).send(uint32(eid), message, _options, MessagingFee(msg.value, 0), msg.sender);
        }
    }

    function _packShieldedAddress(bytes calldata shieldedAddress) internal pure returns (bytes memory) {
        bytes32 vx = bytes32(shieldedAddress[32:64]);
        bytes32 vy = bytes32(shieldedAddress[64:96]);
        bytes32 sx = bytes32(shieldedAddress[96:128]);
        bytes32 sy = bytes32(shieldedAddress[128:160]);
        return abi.encodePacked(shieldedAddress[0:32], _packPoint(vx, vy), _packPoint(sx, sy));
    }

    function _packPoint(bytes32 x, bytes32 y) internal pure returns (bytes32) {
        if (uint256(x) > FIELD_SIZE_DIV_2) {
            return MASK_PACK | y;
        }
        return y;
    }

    function _insertAddress(uint256 rootAddress) internal returns (uint32) {
        (uint256 index, bytes32 root) = _tree.push(bytes32(rootAddress), _hashLeaves);
        _nextLeafIndex = index + 1;
        _treeRoot = uint256(root);
        return uint32(index);
    }

    function _hashRegsiterAddressStruct(bytes calldata shieldedAddress) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_TYPEHASH_REGISTER_ADDRESS, keccak256(bytes(MESSAGE_REGISTER_ADDRESS)), keccak256(shieldedAddress)
            )
        );
    }

    function _hashLeaves(bytes32 left, bytes32 right) internal view returns (bytes32) {
        return bytes32(IHasher(hasher).hash([uint256(left), uint256(right)]));
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    receive() external payable { }
}
