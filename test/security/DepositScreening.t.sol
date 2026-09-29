// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {DevVerifierRegister} from "./DevVerifierRegister.sol";
import {DevVerifierTreeUpdate} from "./DevVerifierTreeUpdate.sol";
import {DevVerifierTransact21} from "./DevVerifierTransact21.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";
import {Gateway} from "src/core/Gateway.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IScreener} from "src/interfaces/IScreener.sol";

/// Same storage layout as MockERC20 (ERC20, Ownable) plus a WETH9-style deposit, so the
/// Gateway can wrap native value into the pool's asset1.
contract WrapERC20 is ERC20, Ownable {
    constructor() ERC20("W", "W") Ownable(msg.sender) {}
    function decimals() public pure override returns (uint8) { return 18; }
    function deposit() external payable { _mint(msg.sender, msg.value); }
    function withdraw(uint256) external {}
}

/// Regression tests for the sanctions-screening bypasses (2026-09 audit).
///
/// Before the fix the pool screened only `msg.sender`, so a sanctioned EOA could deposit
/// through the permissionless Gateway, or have anyone relay its shielded-address
/// registration. Note: `vm.prank(x)` alone leaves tx.origin at Foundry's default sender,
/// so the tests set both.
contract DepositScreeningTest is PoolTest {
    address constant SANCTIONED = address(0xBAD);
    Gateway gw;

    function setUp() public {
        _setUp();
        vm.etch(asset1.assetAddress, address(new WrapERC20()).code);
        gw = new Gateway(IEntryPoint(address(0xE1)), IWToken(asset1.assetAddress), IPool(address(pool)));
        vm.deal(SANCTIONED, 100 ether);
    }

    function test_directDepositScreened() public {
        screener.setSanctioned(SANCTIONED, true);
        ShieldedTransaction memory stx = _loadShieldedTransaction("deposit_weth_tx");
        vm.prank(SANCTIONED, SANCTIONED);
        vm.expectRevert(abi.encodeWithSelector(IScreener.SanctionedAddress.selector, SANCTIONED));
        pool.transact{value: 100 ether}(stx);
    }

    /// MEDIUM (fixed): the Gateway was the only screened party.
    function test_gatewayDepositScreensOrigin() public {
        screener.setSanctioned(SANCTIONED, true);
        ShieldedTransaction memory stx = _loadShieldedTransaction("deposit_weth_tx");
        vm.prank(SANCTIONED, SANCTIONED);
        vm.expectRevert(abi.encodeWithSelector(IScreener.SanctionedAddress.selector, SANCTIONED));
        gw.handleWrapAndDeposit{value: 100 ether}(stx);
    }

    function test_control_gatewayDepositWorksForCleanOrigin() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("deposit_weth_tx");
        uint256 before = IWToken(asset1.assetAddress).balanceOf(address(pool));
        vm.prank(SANCTIONED, SANCTIONED); // not flagged in this test
        gw.handleWrapAndDeposit{value: 100 ether}(stx);
        assertEq(IWToken(asset1.assetAddress).balanceOf(address(pool)), before + 100 ether);
    }
}

/// Uses the dev-key register verifier so a fresh registration proof (`poc_register`) can be
/// submitted; PoolTest has already registered the production `register_sender` fixture.
contract RegistrationScreeningTest is PoolBaseTest {
    function setUp() public {
        PoolBaseTest._setUp();
        TransactionVerifierInfo[] memory v = new TransactionVerifierInfo[](1);
        DevVerifierTransact21 v21 = new DevVerifierTransact21();
        v[0] = TransactionVerifierInfo(21, v21.verifyProof.selector, address(v21));
        pool.mock_verifier(
            address(new Verifier(v, address(new DevVerifierRegister()), address(new DevVerifierTreeUpdate()), address(this)))
        );
    }

    /// MEDIUM (fixed): registration screened only the relayer (msg.sender), not the signer.
    function test_relayedRegistrationScreensSigner() public {
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("poc_register");
        reg.signature = _getRegisterAddressSignature(fixture.registrant.privateKey, reg.shieldedAddress);
        screener.setSanctioned(fixture.registrant.addr, true);

        address relayer = makeAddr("relayer");
        vm.prank(relayer, relayer);
        vm.expectRevert(abi.encodeWithSelector(IScreener.SanctionedAddress.selector, fixture.registrant.addr));
        pool.registerAddress(reg);

        screener.setSanctioned(fixture.registrant.addr, false);
        vm.prank(relayer, relayer);
        pool.registerAddress(reg);
    }
}
