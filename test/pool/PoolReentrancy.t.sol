// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20ForReentrancyTest} from "test/mocks/MockERC20ForReentrancyTest.sol";
import {MockAttacker} from "test/mocks/MockAttacker.t.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";

contract PoolReentrancyTest is PoolTest {
    using MerkleTreeLogic for MerkleTree;

    ShieldedTransaction attackerWithdrawStx;
    MockERC20ForReentrancyTest tokenReent;
    MockAttacker attacker;
    Asset assetReent;
    uint256 constant INITIAL_DEPOSIT = 1000 ether;

    function setUp() public {
        _setUp();
        _helperTree.init(fixture.commitmentTreeDepth, address(hasher));

        // Deploying the ERC20 token for testing reentrancy attack
        tokenReent = new MockERC20ForReentrancyTest(address(this));

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(tokenReent);
        pool.addAssets(assetType, assetAddresses);
        assetReent = pool.getAsset(address(tokenReent));

        _mintAsset(assetReent, address(this), INITIAL_DEPOSIT);
        _approveAsset(assetReent, address(pool), INITIAL_DEPOSIT);

        ShieldedTransaction
            memory reentTokenDepositStx = _loadShieldedTransaction(
                "deposit_1000_reentrantToken_without_fee"
            );
        pool.transact(reentTokenDepositStx);

        // `to` address will be that of the attacker contract which
        // will perform the reentrancy attack
        attackerWithdrawStx = _loadShieldedTransaction(
            "withdraw_500_reentrantToken_to_attacker_contract"
        );

        // will perform the reentrancy attack and test the revert
        attacker = new MockAttacker(pool, attackerWithdrawStx, tokenReent);
        console.log("Attacker address:", address(attacker));
    }

    function test_reentrancyAttack() public {
        _updateOnChainMT();

        // initiating the withdraw to attacker that will perform reentrancy attack and check the revert
        pool.transact(attackerWithdrawStx);
    }

    function _updateOnChainMT() internal {
        // UPDATE QUEUE MT SERVICE
        // service reading the queue and generating new merkle tree state on-chain
        (uint256[] memory leaves, , , , ) = pool.getCommitmentTreeState();
        for (uint8 i; i < leaves.length; ) {
            _helperTree.insert(leaves[i]);
            unchecked {
                ++i;
            }
        }

        (uint256[] memory lastSubtrees, uint256 lastRoot, , ) = _helperTree
            .getState();

        TreeUpdateData memory treeUpdateData = TreeUpdateData({
            newRoot: lastRoot,
            newSubtrees: lastSubtrees,
            proof: bytes("")
        });

        pool.updateCommitmentTree(treeUpdateData);
    }
}
