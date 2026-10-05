// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool, InitAddressParams, PoolConfigParams} from "src/interfaces/IPool.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {Pool} from "src/core/Pool.sol";
import {MockPool} from "test/mocks/MockPool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {AssetType, Asset} from "src/libraries/AssetLogic.sol";
import {MerkleTree} from "src/libraries/MerkleTreeLogic.sol";
import {RevokerData} from "src/libraries/ShieldedTransactionLogic.sol";
import {PoolStorage} from "src/base/PoolStorage.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _setUp();
    }

    function test_correctParameters() public view {
        address verifier_ = address(pool.verifier());
        address adaptorHandler_ = address(pool.adaptorHandler());
        assertEq(verifier_, address(verifier));
        assertEq(adaptorHandler_, address(adaptorHandler));
        assertEq(commitmentTreeDepth, fixture.commitmentTreeDepth);
        assertEq(addressTreeDepth, fixture.addressTreeDepth);
    }

    function test_addAsset() external {
        MockERC20 testToken = new MockERC20(address(this), 18);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(testToken);
        uint8[] memory precisions = new uint8[](1);
        precisions[0] = 18;
        AssetType assetType = AssetType.ERC20;

        pool.addAssets(
            assetType,
            _toAssetInitParams(
                assetAddresses,
                precisions,
                _mockFeedsArray(assetAddresses.length)
            )
        );

        // bool isAssetActive = pool.isAssetActive(assetAddress);
        Asset memory newAsset = pool.getAsset(assetAddresses[0]);
        // assert(isAssetActive);
        assertNotEq(newAsset.id, 0);
        assert(newAsset.assetType == assetType);
        assertEq(newAsset.assetAddress, address(testToken));
    }

    ///////////////////////////
    ////// Revoker Tests  /////
    ///////////////////////////
    function test_registerRevoker() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerKeys();

        vm.expectEmit(true, true, true, true);
        emit IPool.RevokerRegistered(
            1,
            revokerKeys,
            encryptionKeys,
            revokerMetaData
        ); // one revoker already registered in PoolTest::_initFixture()

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
    }

    function test_revertOnDuplicateRevoker() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerKeys();

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);

        vm.expectRevert(
            abi.encodeWithSelector(IPool.DuplicateRevoker.selector, revokerKeys)
        );
        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
    }

    function test_revertWhenNonOwnerAddsRevoker() external {
        address random = makeAddr("random");
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerKeys();

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                random
            )
        );
        vm.prank(random);
        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
    }

    function test_getRevoker() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerKeys();

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);

        RevokerData memory cKeys = pool.getRevokerData(1); // one revoker already registered in PoolTest::_initFixture()
        assertEq(cKeys.revokerPublicKey[0], revokerKeys[0]);
        assertEq(cKeys.revokerPublicKey[1], revokerKeys[1]);
        assertEq(cKeys.encryptionPublicKey[0], encryptionKeys[0]);
        assertEq(cKeys.encryptionPublicKey[1], encryptionKeys[1]);

        assertTrue(cKeys.isActive);
    }

    function test_setRevokerStatus() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerKeys();

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
        vm.expectEmit(true, true, true, true);
        emit IPool.RevokerStatusUpdated(1, false);
        pool.setRevokerStatus(1, false);

        RevokerData memory revoker = pool.getRevokerData(1);
        assertEq(revoker.isActive, false);
    }

    ///////////////////////////
    ////// Initialize     /////
    ///////////////////////////

    function test_initializeSetsScreenerAndPauser() external {
        address newPauser = makeAddr("initPauser");

        MockPool newPool = _deployPool(address(screener), newPauser);

        assertEq(address(newPool.screener()), address(screener));
        assertEq(newPool.pauser(), newPauser);
    }

    function test_initializeAllowsZeroScreenerAndPauser() external {
        MockPool newPool = _deployPool(address(0), address(0));

        assertEq(address(newPool.screener()), address(0));
        assertEq(newPool.pauser(), address(0));
    }

    function test_revertWhenInitializedWithEoaScreener() external {
        address eoa = makeAddr("eoaScreener");
        address impl = address(new MockPool());
        bytes memory initData = _initData(eoa, address(0));

        vm.expectRevert(
            abi.encodeWithSelector(IPool.InvalidScreenerAddress.selector, eoa)
        );
        new ERC1967Proxy(impl, initData);
    }

    /// @dev Deploys a fresh Pool behind a proxy with the given screener and pauser.
    function _deployPool(
        address screener_,
        address pauser_
    ) internal returns (MockPool) {
        return
            MockPool(
                payable(
                    address(
                        new ERC1967Proxy(
                            address(new MockPool()),
                            _initData(screener_, pauser_)
                        )
                    )
                )
            );
    }

    /// @dev Builds the `Pool.initialize` calldata used by the proxy deployments above.
    function _initData(
        address screener_,
        address pauser_
    ) internal view returns (bytes memory) {
        InitAddressParams memory initAddressParams = InitAddressParams({
            verifier: IVerifier(address(verifier)),
            adaptorHandler: IAdaptorHandler(address(adaptorHandler)),
            screener: IScreener(screener_),
            hasher: IHasher(address(hasher)),
            pauser: pauser_
        });

        PoolConfigParams memory configParams = PoolConfigParams({
            withdrawFeeBps: fixture.withdrawFeeBps,
            tvlLimitUsd: type(uint256).max,
            minDepositUsd: 0,
            maxDepositUsd: type(uint256).max,
            priceFeedStalenessThreshold: 1 days,
            nativeWToken: IWToken(config.nativeWToken())
        });

        return
            abi.encodeCall(Pool.initialize, (initAddressParams, configParams));
    }

    function _getRevokerKeys()
        internal
        pure
        returns (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        )
    {
        // Must be genuine BabyJubJub points: registerRevoker validates them, and the
        // circuit uses both as scalar-multiplication bases. Previously these were
        // keccak hashes reused for x and y, which are not on the curve (and were not
        // even field elements).
        // 2G and 3G on BabyJubJub, G being the standard base point.
        uint256 revokerKeyX = 10031262171927540148667355526369034398030886437092045105752248699557385197826;
        uint256 revokerKeyY = 633281375905621697187330766174974863687049529291089048651929454608812697683;

        uint256 encryptionKeyX = 2763488322167937039616325905516046217694264098671987087929565332380420898366;
        uint256 encryptionKeyY = 15305195750036305661220525648961313310481046260814497672243197092298550508693;

        revokerKeys = [revokerKeyX, revokerKeyY];
        encryptionKeys = [encryptionKeyX, encryptionKeyY];

        return (revokerKeys, encryptionKeys);
    }
}
