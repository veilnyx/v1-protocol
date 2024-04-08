import { Hex, hexToBigInt, keccak256, stringToBytes } from "viem";
import MerkleTree from "fixed-merkle-tree";
import { Fp } from "@zkfi-tech/babyjubjub";
import { ShieldedAddress } from "@zkfi-tech/account";
import {
  IAddressResolver,
  INote,
  INoteSource,
  ITreeSource,
} from "@zkfi-tech/shared-types";
import { hexFixed } from "@zkfi-tech/utils";

export class MockAddressResolver implements IAddressResolver {
  private _mockedEnsNames: Record<string, Hex> = {};
  private _mockedShieldedAddresses: Record<Hex, ShieldedAddress> = {};

  mockShieldedAddress(pubAddress: Hex, zAddress: ShieldedAddress) {
    this._mockedShieldedAddresses[pubAddress] = zAddress;
  }

  mockEnsName(name: string, address: Hex) {
    this._mockedEnsNames[name] = address;
  }

  async getShieldedAddress(pubAddress: Hex): Promise<Hex> {
    return this._mockedShieldedAddresses[pubAddress].pack();
  }

  async resolveEnsName(name: string): Promise<Hex> {
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

  insert(leaf: bigint | Hex) {
    const hex = typeof leaf === "bigint" ? `0x${leaf.toString(16)}` : leaf;
    this._tree.insert(hexFixed(hex, 32));
  }

  indexOf(leaf: bigint | Hex): number {
    const hex = typeof leaf === "bigint" ? `0x${leaf.toString(16)}` : leaf;
    return this._tree.indexOf(hexFixed(hex, 32));
  }

  pathElements(index: number): bigint[] {
    return this._tree
      .path(index)
      .pathElements.map((el) => hexToBigInt(el.toString() as Hex));
  }
}

export class MockNotesSource implements INoteSource {
  private _notes: Record<number, INote[]> = {};

  async getAll(assetId?: number): Promise<INote[]> {
    if (isFinite(assetId)) {
      return Promise.resolve(this._notes[assetId]);
    }
    return Object.values(this._notes).flat();
  }

  getUnspent(assetId?: number): Promise<INote[]> {
    if (isFinite(assetId)) {
      return Promise.resolve(this._notes[assetId]);
    }
    return Promise.resolve(Object.values(this._notes).flat());
  }

  mockNotes(assetId: number, notes: INote[]) {
    this._notes[assetId] = notes;
  }

  checkSpent(notes: INote[]): Promise<boolean[]> {
    throw new Error("Method not implemented.");
  }

  chooseForSpending(assetIds: number[], amount: bigint): Promise<INote[]> {
    throw new Error("Method not implemented.");
  }
}
