import { hexToBigInt, keccak256, stringToBytes } from "viem";
import MerkleTree from "fixed-merkle-tree";
import { Fp } from "@zkfi-tech/babyjubjub";
import { ShieldedAddress } from "@zkfi-tech/account";
import {
  HexString,
  IAddressResolver,
  INote,
  INoteSource,
  ITreeSource,
} from "@zkfi-tech/shared-types";
import { hexFixed } from "@zkfi-tech/utils";

export class MockAddressResolver implements IAddressResolver {
  private _mockedEnsNames: Record<string, HexString> = {};
  private _mockedShieldedAddresses: Record<HexString, ShieldedAddress> = {};

  mockShieldedAddress(pubAddress: HexString, zAddress: ShieldedAddress) {
    this._mockedShieldedAddresses[pubAddress] = zAddress;
  }

  mockEnsName(name: string, address: HexString) {
    this._mockedEnsNames[name] = address;
  }

  async getShieldedAddress(pubAddress: HexString): Promise<ShieldedAddress> {
    return this._mockedShieldedAddresses[pubAddress];
  }

  async resolveEnsName(name: string): Promise<HexString> {
    return this._mockedEnsNames[name];
  }
}

export class MockTreeSource implements ITreeSource {
  private _tree: MerkleTree;

  constructor(tree: MerkleTree) {
    this._tree = tree;
  }

  get root() {
    return BigInt(this._tree.root.toString());
  }

  get depth() {
    return this._tree.levels;
  }

  get zeroLeaf() {
    return Fp.from(keccak256(stringToBytes("zkFi"))).val;
  }

  indexOf(leaf: bigint | HexString): number {
    const hex = typeof leaf === "bigint" ? `0x${leaf.toString(16)}` : leaf;
    return this._tree.indexOf(hexFixed(hex, 32));
  }

  pathElements(index: number): bigint[] {
    return this._tree
      .path(index)
      .pathElements.map((el) => hexToBigInt(el.toString() as HexString));
  }
}

export class MockNotesSource implements INoteSource {
  private _notes: Record<HexString, HexString> = {};

  getAll(): Promise<INote[]> {
    return Promise.resolve([]);
  }

  getSpent(): Promise<INote[]> {
    return Promise.resolve([]);
  }

  getUnspent(): Promise<INote[]> {
    return Promise.resolve([]);
  }

  getByAssetId(assetId: number): Promise<INote[]> {
    return Promise.resolve([]);
  }

  checkSpent(notes: INote[]): Promise<boolean[]> {
    return Promise.resolve([]);
  }

  chooseForSpending(assetIds: number[], amount: bigint): Promise<INote[]> {
    return Promise.resolve([]);
  }
}
