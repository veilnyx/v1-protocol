// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Pool} from "src/core/Pool.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ZTransaction, RevokerData} from "src/libraries/ZTransaction.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {BaseTest} from "./BaseTest.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {MESSAGE_REGISTER_ADDRESS, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EIP712_TYPEHASH_REGISTER_ADDRESS} from "src/base/Constants.sol";
import {console2} from "forge-std/console2.sol";

contract PoolTest is BaseTest {
    Verifier public verifier;
    AdaptorHandler public adaptorHandler;
    Pool public pool;

    uint256 public addressTreeDepth;
    uint256 public commitmentTreeDepth;
    address public entryPoint;

    MockERC20 public token1;
    MockERC20 public token2;

    MockScreener public screener;

    Asset public asset1;
    Asset public asset2;

    bytes revokerMetaData = abi.encode("Revoker 1", "Organization 1");

    uint256 constant INITIAL_DEPOSIT = 1000 ether;
    bytes32 private constant TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    function _initFixture() internal virtual {
        BaseTest._setUp();

        addressTreeDepth = fixture.addressTreeDepth;
        commitmentTreeDepth = fixture.commitmentTreeDepth;

        VerifierTransact21 vt21 = new VerifierTransact21();
        VerifierTransact22 vt22 = new VerifierTransact22();
        VerifierRegister vr = new VerifierRegister();
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
        verifier = new Verifier(vInfos, address(vr));
        adaptorHandler = new AdaptorHandler();

        pool = new Pool();

        // Assets
        token1 = new MockERC20(address(this));
        token2 = new MockERC20(address(this));
        asset1 = Asset({
            id: 65537,
            assetType: AssetType.ERC20,
            assetAddress: address(token1),
            isSupported: true
        });
        asset2 = Asset({
            id: 65538,
            assetType: AssetType.ERC20,
            assetAddress: address(token2),
            isSupported: true
        });

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(token1);
        assetAddresses[1] = address(token2);

        screener = new MockScreener();
        address hasher = _deployHasher();

        bytes memory initData = abi.encodeCall(
            Pool.initialize,
            (
                fixture.addressTreeDepth,
                fixture.commitmentTreeDepth,
                address(verifier),
                address(adaptorHandler),
                address(screener),
                hasher,
                fixture.withdrawFeeBps
            )
        );

        ERC1967Proxy poolProxy = new ERC1967Proxy(address(pool), initData);
        pool = Pool(address(poolProxy));
        pool.addAssets(assetType, assetAddresses);

        pool.registerRevoker(
            fixture.revokerPublicKey,
            fixture.encryptionPublicKey,
            revokerMetaData
        );

        (, uint256 senderPk) = makeAddrAndKey("sender");
        bytes memory signature = _getRegisterAddressSignature(
            senderPk,
            bytes.concat(
                bytes32(fixture.sender.rootAddress),
                bytes32(fixture.sender.signPublicKey[0]),
                bytes32(fixture.sender.signPublicKey[1]),
                bytes32(fixture.sender.viewPublicKey[0]),
                bytes32(fixture.sender.viewPublicKey[1])
            )
        );

        ShieldedAddressRegistrationData
            memory addressRegData = _loadShieldedAddressRegistrationData(
                "register_sender"
            );
        addressRegData.signature = signature;
        pool.registerAddress(addressRegData);
    }

    function _mintAsset(
        Asset storage asset,
        address to,
        uint256 amount
    ) internal {
        MockERC20(asset.assetAddress).mint(to, amount);
    }

    function _approveAsset(
        Asset storage asset,
        address spender,
        uint256 amount
    ) internal {
        MockERC20(asset.assetAddress).approve(spender, amount);
    }

    function _getAssetId(Asset storage asset) internal view returns (uint24) {
        return pool.getAsset(asset.assetAddress).id;
    }

    // Deposits 10000 ether
    function _mockDeposit() internal {
        string memory path = string.concat(
            vm.projectRoot(),
            "/test/mocks/deposit.txt"
        );
        string memory file = vm.readFile(path);
        bytes memory data = vm.parseBytes(file);
        ZTransaction memory ztx = abi.decode(data, (ZTransaction));

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000 ether);
        pool.transact(ztx);
    }

    function _makeInitialDeposit() internal {
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _mintAsset(asset2, address(this), INITIAL_DEPOSIT);
        _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);
        _approveAsset(asset2, address(pool), INITIAL_DEPOSIT);
        ZTransaction memory ztx = _loadZTx(
            "deposit_1000_weth_usdc_without_fee"
        );
        pool.transact(ztx);
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
