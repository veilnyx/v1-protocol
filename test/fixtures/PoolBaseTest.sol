// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Pool} from "src/core/Pool.sol";
import {MESSAGE_REGISTER_ADDRESS, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EIP712_TYPEHASH_REGISTER_ADDRESS} from "src/base/Constants.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Hasher} from "src/core/Hasher.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {BaseTest} from "./BaseTest.sol";

contract PoolBaseTest is BaseTest {
    bytes32 private constant TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    Verifier public verifier;
    AdaptorHandler public adaptorHandler;
    Hasher public hasher;
    Pool public pool;

    uint256 public addressTreeDepth;
    uint256 public commitmentTreeDepth;
    address public entryPoint;

    MockScreener public screener;

    function _setUp() internal virtual override {
        BaseTest._setUp();

        addressTreeDepth = fixture.addressTreeDepth;
        commitmentTreeDepth = fixture.commitmentTreeDepth;

        VerifierTransact21 vt21 = new VerifierTransact21();
        VerifierTransact22 vt22 = new VerifierTransact22();
        VerifierRegister vr = new VerifierRegister();
        VerifierTreeUpdate vTreeUpdate = new VerifierTreeUpdate();
        TransactionVerifierInfo[] memory vInfos = new TransactionVerifierInfo[](
            2
        );
        vInfos[0] = TransactionVerifierInfo({
            id: 21,
            addr: address(vt21),
            selector: vt21.verifyProof.selector
        });
        vInfos[1] = TransactionVerifierInfo({
            id: 22,
            addr: address(vt22),
            selector: vt22.verifyProof.selector
        });
        verifier = new Verifier(vInfos, address(vr), address(vTreeUpdate));
        adaptorHandler = new AdaptorHandler();

        pool = new MockPool();

        screener = new MockScreener();
        hasher = _deployHasher();

        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                fixture.addressTreeDepth,
                fixture.commitmentTreeDepth,
                fixture.commitmentTreeQueueSize,
                address(verifier),
                address(adaptorHandler),
                address(screener),
                address(hasher),
                fixture.withdrawFeeBps
            )
        );

        ERC1967Proxy poolProxy = new ERC1967Proxy(address(pool), initData);
        pool = MockPool(address(poolProxy));
    }

    //////////////////////////////////////////////////////
    /// EIP 712 User Registration Functions       ////////
    //////////////////////////////////////////////////////

    function _getRegisterAddressSignature(
        uint256 userPK,
        bytes memory shieldedAddress
    ) internal view returns (bytes memory) {
        bytes32 hashTypedData = _getHashTypedRegisterAddressStruct(
            shieldedAddress
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, hashTypedData);
        return abi.encodePacked(r, s, v);
    }

    function _getHashTypedRegisterAddressStruct(
        bytes memory shieldedAddress
    ) internal view returns (bytes32) {
        bytes32 hashTypedData = MessageHashUtils.toTypedDataHash(
            _domainSeperator(),
            keccak256(
                abi.encode(
                    EIP712_TYPEHASH_REGISTER_ADDRESS,
                    keccak256(bytes(MESSAGE_REGISTER_ADDRESS)),
                    keccak256(shieldedAddress)
                )
            )
        );
        return hashTypedData;
    }

    function _domainSeperator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TYPE_HASH,
                    keccak256(bytes(EIP712_DOMAIN_NAME)),
                    keccak256(bytes(EIP712_DOMAIN_VERSION)),
                    block.chainid,
                    address(pool)
                )
            );
    }
}
