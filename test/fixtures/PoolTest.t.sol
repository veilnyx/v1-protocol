// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Pool} from "src/core/Pool.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {Verifier, VerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ZTransaction, RevokerData} from "src/libraries/ZTransaction.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockScrenner} from "test/mocks/MockScreener.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {Config} from "script/Config.sol";
import {console2} from "forge-std/console2.sol";

contract PoolTest is BaseTest {
    Verifier public verifier;
    AdaptorHandler public adaptorHandler;
    Pool public pool;

    uint256 public addressTreeDepth = 20;
    uint256 public commitmentTreeDepth = 25;
    address public entryPoint;

    MockERC20 public token1;
    MockERC20 public token2;

    MockScrenner public screener;

    Asset public asset1;
    Asset public asset2;

    bytes revokerMetaData = abi.encode("Revoker 1", "Organization 1");

    uint256 constant INITIAL_DEPOSIT = 1000 ether;

    function _initFixture() internal virtual {
        Verifier22 v22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        verifier = new Verifier(vInfos);
        adaptorHandler = new AdaptorHandler();
        Config config = new Config();
        entryPoint = address(0);

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

        screener = new MockScrenner();

        bytes memory initData = abi.encodeWithSelector(
            pool.initialize.selector,
            addressTreeDepth,
            commitmentTreeDepth,
            address(verifier),
            address(adaptorHandler),
            address(screener)
        );

        ERC1967Proxy poolProxy = new ERC1967Proxy(address(pool), initData);
        pool = Pool(address(poolProxy));
        pool.addAssets(assetType, assetAddresses);

        pool.registerRevoker(
            fixture.revokerPublicKey,
            fixture.encryptionPublicKey,
            revokerMetaData
        );

        bytes memory publicKeys = new bytes(64);
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            bytes.concat(bytes32(fixture.senderAccount.rootAddress), publicKeys)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(123), msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        pool.registerAddress(
            fixture.senderAccount.rootAddress,
            publicKeys,
            signature
        );
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
}
