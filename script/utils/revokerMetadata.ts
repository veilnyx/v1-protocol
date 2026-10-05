import { createHash } from "crypto";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import { Hex, encodeAbiParameters, parseAbiParameters } from "viem";
import type { CommonParams } from "../configs";

/**
 * The revoker metadata format, and the guard that keeps a bad one off-chain.
 *
 * `Pool.registerRevoker` takes `bytes revokerMetadata` and only re-emits it in `RevokerRegistered`.
 * The pool never reads it, so nothing on-chain constrains the encoding — which makes it the deploy
 * script's job to get right, and a mistake permanent: there is no metadata setter (`setRevokerStatus`
 * only toggles `isActive`), and re-registering the same keypair reverts with `DuplicateRevoker`.
 * A revoker registered with the wrong bytes keeps them for the life of the pool.
 *
 * The encoding is `abi.encode(string pinataCID)` — a CIDv1 (raw codec, sha2-256, base32) resolving
 * to a JSON document `{name, description}`. It replaced `abi.encode(string name, string description)`,
 * and the two are *silently* confusable in one direction: decoding the old two-string payload as a
 * single string succeeds and returns the name, because the leading `0x40` head word is read as the
 * string offset. A consumer expecting a CID gets "Veilnyx Security Group" and no error. Every
 * registration path therefore goes through {@link encodeRevokerMetadata} rather than open-coding
 * the parameter list — one definition, so the two formats cannot drift back apart.
 *
 * {@link assertRevokerMetadata} pins the configured CID to a document committed in `docs/`, the same
 * way `verifierProvenance` pins verifier bytecode to a ceremony: content addressing means the hash
 * of the local file *is* the identity of the pinned object, so the check needs no network and cannot
 * be fooled. It also makes the repo the recovery path — anyone can re-pin `docs/revoker.json` and
 * reproduce the exact CID the pool points at.
 */

/** `docs/revoker.json` today; the glob is so a second revoker only needs a second file. */
const METADATA_DIR = join(__dirname, "..", "..", "docs");
const METADATA_FILE_RE = /^revoker.*\.json$/i;

/** CIDv1 + raw + sha2-256 in base32 is always this shape: "bafkrei" then 52 base32 chars. */
const CID_RE = /^bafkrei[a-z2-7]{52}$/;

const GATEWAYS = [
  "https://gateway.pinata.cloud/ipfs/",
  "https://ipfs.io/ipfs/",
];

const GATEWAY_TIMEOUT_MS = 15_000;

/** RFC 4648 base32, lowercase, unpadded — the multibase "b" alphabet. */
const BASE32_ALPHABET = "abcdefghijklmnopqrstuvwxyz234567";

// ArrayLike rather than Uint8Array so Buffer is accepted without a cast: @types/node parameterises
// Buffer over ArrayBufferLike, which does not satisfy Uint8Array<ArrayBuffer>.
const base32Encode = (bytes: ArrayLike<number>): string => {
  let bits = 0;
  let value = 0;
  let out = "";
  // Indexed rather than for-of: tsconfig sets no `target`, so it defaults low enough that
  // iterating a Uint8Array would need --downlevelIteration.
  for (let i = 0; i < bytes.length; i++) {
    // At most 4 bits are held over, so `value` never exceeds 12 bits.
    value = (value << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      out += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    out += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  }
  return out;
};

/**
 * The CID a raw file gets when pinned: multibase "b", CID version 1, raw codec, sha2-256.
 * This is what `ipfs add --cid-version 1 --raw-leaves` produces, and what Pinata returns for a
 * single small file.
 */
export const computeRawCidV1 = (content: Uint8Array | Buffer): string => {
  // Copied into a plain Uint8Array first: @types/node's Buffer does not satisfy `BinaryLike` under
  // this project's type setup, and the documents involved are a few hundred bytes.
  const digest = createHash("sha256").update(Uint8Array.from(content)).digest();
  const prefix = [
    0x01, // CIDv1
    0x55, // multicodec: raw
    0x12, // multihash: sha2-256
    0x20, // digest length: 32 bytes
  ];
  const multihash = new Uint8Array(prefix.length + digest.length);
  multihash.set(prefix, 0);
  multihash.set(digest, prefix.length);
  return "b" + base32Encode(multihash);
};

/** The one definition of the on-chain metadata format. Every registration path calls this. */
export const encodeRevokerMetadata = (pinataCID: string): Hex =>
  encodeAbiParameters(parseAbiParameters("string pinataCID"), [pinataCID]);

type LocalDocument = { cid: string; path: string; name?: unknown; description?: unknown };

/** Every metadata document in `docs/`, tagged with the CID it would be pinned under. */
const readLocalDocuments = (): LocalDocument[] =>
  readdirSync(METADATA_DIR)
    .filter((file) => METADATA_FILE_RE.test(file))
    .map((file) => {
      const raw = readFileSync(join(METADATA_DIR, file));
      // A document that is not valid JSON still has a CID; only the field comparison is skipped,
      // and the mismatch surfaces there rather than as a crash here.
      let parsed: any;
      try {
        parsed = JSON.parse(raw.toString("utf8"));
      } catch {
        parsed = undefined;
      }
      return {
        cid: computeRawCidV1(raw),
        path: join("docs", file),
        name: parsed?.name,
        description: parsed?.description,
      };
    });

/**
 * Validates every configured revoker's `pinataCID` before a deployment spends any gas. Pure —
 * reads files only, touches no chain state and no network.
 *
 * Must run before the first transaction rather than inside the registration loop: revokers are
 * registered in the same try block as the base assets, after `addAssets` has already advanced the
 * pool's asset counter. An unset CID throws there and leaves a pool with assets and no revoker —
 * which reverts every `transact` with `InvalidRevoker` and cannot be repaired in place. An empty
 * or typo'd CID is worse: it encodes cleanly, the transaction succeeds, and the dangling pointer
 * is permanent.
 */
export const assertRevokerMetadata = (revokers: CommonParams["revokers"]) => {
  if (revokers.length === 0) {
    throw new Error(
      "config.json declares no revokers. A pool with no active revoker reverts every transact() " +
      "with InvalidRevoker — nothing has been deployed."
    );
  }

  const documents = readLocalDocuments();
  const errors: string[] = [];

  revokers.forEach((revoker, i) => {
    const cid = revoker.pinataCID;
    const label = `revokers[${i}] ("${revoker.name}")`;

    if (!cid) {
      errors.push(`${label} has no pinataCID — registerRevoker would be sent with empty metadata`);
      return;
    }
    if (!CID_RE.test(cid)) {
      errors.push(
        `${label} pinataCID "${cid}" is not a CIDv1 raw/sha2-256 base32 hash (expected "bafkrei" + 52 chars)`
      );
      return;
    }

    const document = documents.filter((d) => d.cid === cid)[0];
    if (!document) {
      const known = documents.map((d) => `${d.path} -> ${d.cid}`).join("\n        ") || "(none)";
      errors.push(
        `${label} pinataCID ${cid} does not match any document in docs/. The pinned content must be ` +
        `committed so the CID is reproducible and re-pinnable. Documents found:\n        ${known}`
      );
      return;
    }

    // config.json's name/description are no longer what goes on-chain — the pinned document is.
    // They still feed deploy logs and error messages, so hold them to the document.
    if (document.name !== revoker.name) {
      errors.push(
        `${label} name does not match ${document.path}: config has "${revoker.name}", ` +
        `the pinned document has "${document.name}"`
      );
    }
    if (document.description !== revoker.description) {
      errors.push(
        `${label} description does not match ${document.path}: config has "${revoker.description}", ` +
        `the pinned document has "${document.description}"`
      );
    }
  });

  if (errors.length > 0) {
    throw new Error(
      `Revoker metadata config is invalid:\n` +
      errors.map((e) => `  - ${e}`).join("\n") +
      `\n\nNothing has been deployed. Pool has no metadata setter and re-registering a keypair ` +
      `reverts with DuplicateRevoker, so a bad CID would be permanent.`
    );
  }

  console.log(`Revoker metadata validated against docs/ (${revokers.length} revoker(s))`);
};

/**
 * Best-effort check that the CIDs are actually reachable, so an unpinned document is caught before
 * anyone tries to read the event rather than after.
 *
 * Advisory by design: {@link assertRevokerMetadata} has already proven the CID matches a committed
 * document, so a gateway that is down or rate-limiting is a fact about the gateway, not about the
 * deployment — and blocking a deploy on it would be wrong. Content addressing also means a gateway
 * cannot serve *different* bytes under this CID; it can only serve an error page, which is why the
 * response is hashed rather than trusted.
 */
export const checkRevokerMetadataIsPinned = async (revokers: CommonParams["revokers"]) => {
  for (const revoker of revokers) {
    const cid = revoker.pinataCID;
    if (!cid) continue;

    const failures: string[] = [];
    let served = false;

    for (const gateway of GATEWAYS) {
      try {
        const res = await fetch(gateway + cid, {
          signal: AbortSignal.timeout(GATEWAY_TIMEOUT_MS),
        });
        if (!res.ok) {
          failures.push(`${gateway} returned HTTP ${res.status}`);
          continue;
        }
        const body = new Uint8Array(await res.arrayBuffer());
        const servedCid = computeRawCidV1(body);
        if (servedCid !== cid) {
          failures.push(`${gateway} served ${body.length} bytes hashing to ${servedCid}`);
          continue;
        }
        served = true;
        break;
      } catch (e: any) {
        failures.push(`${gateway} failed: ${e.message}`);
      }
    }

    if (served) {
      console.log(`Revoker metadata for "${revoker.name}" resolves: ${cid}`);
    } else {
      console.warn(
        `⚠️  Revoker metadata for "${revoker.name}" (${cid}) could not be fetched from any gateway:\n` +
        failures.map((f) => `      ${f}`).join("\n") +
        `\n      The CID matches the committed document, so the deployment is safe to proceed — but ` +
        `re-pin it before anyone reads RevokerRegistered.`
      );
    }
  }
};
