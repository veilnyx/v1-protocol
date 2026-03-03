// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockAttacker} from "test/mocks/MockAttacker.t.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";

contract PoolReentrancyTest is PoolTest {
    using MerkleTreeLogic for MerkleTree;

    ShieldedTransaction attackerWithdrawStx;
    MockAttacker attacker;
    Asset assetReent;
    uint256 constant INITIAL_DEPOSIT = 1000 ether;
    address constant REENTRANCY_ATTACK_CONTRACT_FIXTURE =
        0x8F2FbdFDa8BE4Da8B9454aE9F0301150932AE4b5;

    function setUp() public {
        _setUp();

        assetReent = pool.getAsset(address(tokenReent));
        _mintAsset(assetReent, address(this), INITIAL_DEPOSIT);
        _approveAsset(assetReent, address(pool), INITIAL_DEPOSIT);

        ShieldedTransaction
            memory reentTokenDepositStx = _loadShieldedTransaction(
                "deposit_1000_reentrantToken_without_fee"
            );
        pool.transact(reentTokenDepositStx, false);
        _processCommitmentTreeQueue();

        // `to` address will be that of the attacker contract which
        // will perform the reentrancy attack
        attackerWithdrawStx = _loadShieldedTransaction(
            "withdraw_500_reentrantToken_to_attacker_contract"
        );

        StdCheats.deployCodeTo(
            "MockAttacker.t.sol:MockAttacker",
            abi.encode(pool, attackerWithdrawStx, tokenReent),
            REENTRANCY_ATTACK_CONTRACT_FIXTURE
        );
    }

    function test_reentrancyAttack() public {
        // initiating the withdraw to attacker that will perform reentrancy attack and check the revert
        pool.transact(attackerWithdrawStx, false);
    }
}
