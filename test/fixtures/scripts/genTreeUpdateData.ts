import { readFileSync, writeFileSync } from "fs";
import { keccak256, stringToBytes } from 'viem';
import { getSDKInstance } from "./sdk";
import {Fp, poseidonHash} from "@zkfi-tech/babyjubjub";
import { fixture } from './fixture';
import { MerkleTreeState } from '@zkfi-tech/zk-prover';
const path = require('path');

const dirFixtureData = path.resolve(__dirname, "../data");

export const genTreeUpdateData  = async () => {
    const sdk = getSDKInstance();
    let initialTreeState: MerkleTreeState = getInitialTreeState();
    const subtreeUpdateData = await sdk.prover.proveSubtreeUpdate({
        lastTree: initialTreeState,
        leaves: fixture.leavesQueue
    });
    const subtreeUpdateDataEncoded = subtreeUpdateData.encode();
    writeFileSync(`${dirFixtureData}/subtreeUpdateData.txt`, subtreeUpdateDataEncoded);
}

const getInitialTreeState = (): MerkleTreeState => {
    let z = Fp.from(keccak256(stringToBytes("zero"))).val;
    const lastSubtree: bigint[] = [];
    const zeros: bigint[] = [];
    const treeDepth: number = fixture.commitmentTreeDepth;
    
    for (let i = 0; i < treeDepth; i++) {
        zeros.push(z);
        lastSubtree.push(z);
        z = poseidonHash([z, z]);
    }
    const root = z;

    return { 
        depth: treeDepth,
        root,
        nextLeafIndex: 0,
        subtree: lastSubtree, 
        zeros
    };
};


genTreeUpdateData().then(() => {
        console.log("Successfully generated test fixtures!");
        process.exit(0);
    })
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });