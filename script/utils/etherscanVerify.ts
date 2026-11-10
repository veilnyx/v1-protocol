import hre from "hardhat";
import { Hex, getAddress } from "viem";

/**
 * Source verification on Etherscan-family explorers (etherscan.io, hyperevmscan.io, ...) through
 * the Etherscan V2 API, for the deploy and upgrade scripts.
 *
 * It calls the API directly instead of going through `hre.run("verify:verify")`:
 * @openzeppelin/hardhat-upgrades overrides both verify:verify and verify:etherscan, and for any
 * ERC-1967 proxy its override looks up the implementation with a V1-style getLogs request that the
 * V2 API rejects ("Missing chainid parameter"). PoolProxy's source was never submitted that way.
 *
 * Constructor arguments are not passed in. They are read from each contract's creation transaction,
 * after checking that the transaction's creation code is exactly this build's bytecode with the
 * given libraries linked. A contract built from other sources is reported, never submitted.
 *
 * Verification only reports: nothing here throws for a single contract. Callers get one result per
 * target and print them with {@link printVerifySummary}.
 *
 * The API key is `etherscan.apiKey` from hardhat.config.ts (ETHERSCAN_API_KEY); the endpoint and
 * the explorer link come from the network's `etherscan.customChains` entry, falling back to the V2
 * endpoint for the network's chain id.
 */

export type VerifyTarget = {
  /** Shown in the logs and the summary. */
  label: string;
  address: Hex;
  /** Artifact name ("Pool") or fully qualified name ("src/core/Pool.sol:Pool"). */
  contract: string;
  /** Library addresses by library name. Only the libraries the artifact links are used. */
  libraries?: Record<string, Hex>;
};

export type VerifyStatus = "verified" | "already-verified" | "failed" | "skipped";
export type VerifyResult = { label: string; address: Hex; status: VerifyStatus; detail?: string };

type Api = { url: string; key: string; browser?: string };

// Free Etherscan keys allow 3-5 calls per second.
const MIN_CALL_SPACING_MS = 400;
// A contract deployed seconds ago may not be indexed yet: getcontractcreation finds nothing and
// verifysourcecode answers "Unable to locate ContractCode".
const INDEX_RETRIES = 12;
const INDEX_RETRY_MS = 5_000;
const STATUS_POLLS = 40;
const STATUS_POLL_MS = 3_000;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const apiConfig = (): Api | undefined => {
  const cfg = (hre.config as any).etherscan ?? {};
  const key = typeof cfg.apiKey === "string" && cfg.apiKey ? cfg.apiKey : process.env.ETHERSCAN_API_KEY;
  if (!key) return undefined;
  const chainId = hre.network.config.chainId;
  const match = (cfg.customChains ?? []).find(
    (c: any) => c.network === hre.network.name || (chainId !== undefined && c.chainId === chainId)
  );
  if (!match && chainId === undefined) return undefined;
  return {
    key,
    url: match?.urls?.apiURL ?? `https://api.etherscan.io/v2/api?chainid=${chainId}`,
    browser: match?.urls?.browserURL,
  };
};

let lastCall = 0;

/** One API call. `chainid` stays in the endpoint's query string for POSTs too. */
const call = async (api: Api, params: Record<string, string>, post = false): Promise<any> => {
  for (let attempt = 0; ; attempt++) {
    const wait = lastCall + MIN_CALL_SPACING_MS - Date.now();
    if (wait > 0) await sleep(wait);
    lastCall = Date.now();

    const url = new URL(api.url);
    const body = new URLSearchParams({ ...params, apikey: api.key });
    let res: Response;
    if (post) {
      res = await fetch(url, { method: "POST", body });
    } else {
      body.forEach((v, k) => url.searchParams.set(k, v));
      res = await fetch(url);
    }
    if (!res.ok) throw new Error(`Etherscan API HTTP ${res.status}`);
    const json = (await res.json()) as any;
    if (/rate limit/i.test(String(json.result)) && attempt < 5) {
      await sleep(1_000);
      continue;
    }
    return json;
  }
};

/** Creation bytecode with library placeholders replaced, plus the solc `libraries` setting for it. */
const linkBytecode = (
  bytecode: string,
  linkReferences: Record<string, Record<string, { start: number; length: number }[]>>,
  libraries: Record<string, Hex>
) => {
  let code = bytecode.slice(2).toLowerCase();
  const settings: Record<string, Record<string, Hex>> = {};
  for (const [file, byName] of Object.entries(linkReferences)) {
    for (const [name, offsets] of Object.entries(byName)) {
      const address = libraries[name];
      if (!address) throw new Error(`no address given for linked library ${name}`);
      (settings[file] ??= {})[name] = getAddress(address);
      for (const o of offsets) {
        code = code.slice(0, o.start * 2) + address.slice(2).toLowerCase() + code.slice((o.start + o.length) * 2);
      }
    }
  }
  return { code, settings };
};

// solc's CBOR metadata IPFS hash (a2 64 "ipfs" 58 22 <34 bytes>), the part of the bytecode that
// changes with any source edit that leaves the executable code alone.
const maskMetadata = (hex: string) => hex.replace(/a264697066735822[0-9a-f]{68}/g, (m) => "0".repeat(m.length));
const PARTIAL_MATCH_NOTE =
  "partial match: only the metadata hash differs (an imported file changed since the deploy); " +
  "verify from the deploy commit for an exact match";

/** Input data of the transaction that deployed `address`, without the 0x prefix. */
const creationInput = async (api: Api, address: Hex): Promise<string> => {
  for (let i = 0; ; i++) {
    const j = await call(api, { module: "contract", action: "getcontractcreation", contractaddresses: address });
    if (Array.isArray(j.result) && j.result.length) {
      const txHash = j.result[0].txHash;
      const tx = await hre.network.provider.send("eth_getTransactionByHash", [txHash]);
      if (!tx) throw new Error(`creation transaction ${txHash} not found on the RPC`);
      if (tx.to) throw new Error(`created by a call to ${tx.to}, not by a deployment transaction`);
      return (tx.input as string).slice(2).toLowerCase();
    }
    if (i >= INDEX_RETRIES) {
      throw new Error(`the explorer has not indexed the contract's creation: ${JSON.stringify(j.result ?? j.message)}`);
    }
    await sleep(INDEX_RETRY_MS);
  }
};

/**
 * Everything verifysourcecode needs for `target`: the minimal standard-JSON input (the sources in
 * the contract's metadata and this build's settings, with the libraries linked) and the constructor
 * arguments taken from its creation transaction. Throws if that transaction did not deploy this build.
 * Exported for dry runs: it submits nothing.
 */
export const prepareVerification = async (target: VerifyTarget, api: Api | undefined = apiConfig()) => {
  if (!api) throw new Error("ETHERSCAN_API_KEY or the network's chain id is not set");
  const artifact = await hre.artifacts.readArtifact(target.contract);
  const fqn = `${artifact.sourceName}:${artifact.contractName}`;
  const { code, settings: libraries } = linkBytecode(
    artifact.bytecode,
    artifact.linkReferences as any,
    target.libraries ?? {}
  );

  const input = await creationInput(api, target.address);
  const deployed = input.slice(0, code.length);
  // The metadata hash covers every imported source file, comments included, so a contract whose
  // own code is unchanged still differs there once any import changes (IPool.sol did after the
  // first 999 deploy). Etherscan verifies that as a partial match; anything else is a different build.
  const metadataOnly = deployed !== code;
  if (metadataOnly && maskMetadata(deployed) !== maskMetadata(code)) {
    throw new Error(`creation code is not this build's ${fqn} (different sources, compiler settings or libraries)`);
  }

  const buildInfo = await hre.artifacts.getBuildInfo(fqn);
  if (!buildInfo) throw new Error(`no build info for ${fqn}; run \`npx hardhat compile\``);
  const metadata = JSON.parse(
    (buildInfo.output.contracts[artifact.sourceName][artifact.contractName] as any).metadata
  );
  const sources = Object.fromEntries(
    Object.keys(metadata.sources).map((s) => [s, { content: buildInfo.input.sources[s].content }])
  );
  // Hardhat compiles libraries unlinked and links afterwards, and solc's metadata records the
  // `libraries` setting, so only the unlinked input reproduces the deployed metadata hash (an exact
  // match). The linked input is the fallback for an explorer that will not fill in placeholders: it
  // compiles to the deployed code with a different metadata hash (a partial match).
  const unlinked = { language: "Solidity", sources, settings: buildInfo.input.settings };
  const inputs = Object.keys(libraries).length
    ? [unlinked, { ...unlinked, settings: { ...buildInfo.input.settings, libraries } }]
    : [unlinked];

  return {
    fqn,
    compilerVersion: `v${buildInfo.solcLongVersion}`,
    constructorArgs: input.slice(code.length),
    /** Standard-JSON inputs to submit, preferred first. */
    inputs,
    /** Set when only the metadata hash differs: the source shown will be this build's, not the deploy commit's. */
    note: metadataOnly ? PARTIAL_MATCH_NOTE : undefined,
  };
};

const isVerified = async (api: Api, address: Hex) => {
  const j = await call(api, { module: "contract", action: "getsourcecode", address });
  return Array.isArray(j.result) && !!j.result[0]?.SourceCode;
};

type Prepared = Awaited<ReturnType<typeof prepareVerification>>;

/** Submits one standard-JSON input and waits for the explorer's verdict. */
const submit = async (
  api: Api,
  address: Hex,
  p: Prepared,
  input: object
): Promise<{ status: "verified" | "already-verified" | "failed"; msg: string }> => {
  let guid: string | undefined;
  for (let i = 0; !guid; i++) {
    const j = await call(
      api,
      {
        module: "contract",
        action: "verifysourcecode",
        contractaddress: address,
        sourceCode: JSON.stringify(input),
        codeformat: "solidity-standard-json-input",
        contractname: p.fqn,
        compilerversion: p.compilerVersion,
        constructorArguements: p.constructorArgs, // sic: the API's spelling
      },
      true
    );
    const msg = String(j.result);
    if (j.status === "1") guid = msg;
    else if (/already verified/i.test(msg)) return { status: "already-verified", msg };
    else if (/unable to locate contractcode/i.test(msg) && i < INDEX_RETRIES) await sleep(INDEX_RETRY_MS);
    else return { status: "failed", msg };
  }

  for (let i = 0; i < STATUS_POLLS; i++) {
    await sleep(STATUS_POLL_MS);
    const j = await call(api, { module: "contract", action: "checkverifystatus", guid });
    const msg = String(j.result);
    if (/pending/i.test(msg)) continue;
    if (/already verified/i.test(msg)) return { status: "already-verified", msg };
    return { status: j.status === "1" ? "verified" : "failed", msg };
  }
  return { status: "failed", msg: `still pending after ${(STATUS_POLLS * STATUS_POLL_MS) / 1000}s (guid ${guid})` };
};

const verifyOne = async (api: Api, target: VerifyTarget): Promise<VerifyResult> => {
  const result = (status: VerifyStatus, detail?: string): VerifyResult => ({
    label: target.label,
    address: target.address,
    status,
    detail,
  });
  try {
    if (await isVerified(api, target.address)) return result("already-verified");
    const p = await prepareVerification(target, api);

    const failures: string[] = [];
    for (const [i, input] of p.inputs.entries()) {
      const r = await submit(api, target.address, p, input);
      if (r.status === "already-verified") return result("already-verified");
      if (r.status === "verified") {
        // Only the first input can reproduce the deployed metadata hash.
        const note = i > 0 ? "partial match: verified with the libraries linked at compile time" : p.note;
        return result("verified", note);
      }
      failures.push(r.msg);
    }
    return result("failed", failures.join(" / then, with libraries linked: "));
  } catch (e: any) {
    return result("failed", e?.message ?? String(e));
  }
};

/** Verifies each target in turn; already-verified contracts are skipped, so reruns are cheap. */
export const verifyOnEtherscan = async (targets: VerifyTarget[]): Promise<VerifyResult[]> => {
  const api = apiConfig();
  if (!api) {
    console.warn("Etherscan: ETHERSCAN_API_KEY or the network's chain id is not set, skipping verification");
    return targets.map((t) => ({ label: t.label, address: t.address, status: "skipped", detail: "no API config" }));
  }
  console.log(`Etherscan: verifying ${targets.length} contract(s) through ${api.url}`);
  const results: VerifyResult[] = [];
  for (const t of targets) {
    const r = await verifyOne(api, t);
    console.log(`Etherscan: ${t.label.padEnd(28)} ${t.address}  ${r.status}${r.detail ? `: ${r.detail}` : ""}`);
    results.push(r);
  }
  return results;
};

/**
 * Registers `proxy` as a proxy of `implementation` on the explorer (the Read/Write as Proxy tabs).
 * Explorers check the implementation slot, so run this after the upgrade has landed.
 */
export const linkProxyOnEtherscan = async (proxy: Hex, implementation: Hex): Promise<VerifyResult> => {
  const label = "proxy -> implementation";
  const result = (status: VerifyStatus, detail?: string): VerifyResult => ({ label, address: proxy, status, detail });
  const api = apiConfig();
  if (!api) return result("skipped", "no API config");
  try {
    const submit = await call(
      api,
      { module: "contract", action: "verifyproxycontract", address: proxy, expectedimplementation: implementation },
      true
    );
    if (submit.status !== "1") return result("failed", String(submit.result));
    const guid = String(submit.result);
    for (let i = 0; i < STATUS_POLLS; i++) {
      await sleep(STATUS_POLL_MS);
      const j = await call(api, { module: "contract", action: "checkproxyverification", guid }, true);
      const msg = String(j.result);
      if (/pending/i.test(msg)) continue;
      if (j.status === "1" || /already verified/i.test(msg)) {
        console.log(`Etherscan: ${label.padEnd(28)} ${proxy}  linked to ${implementation}`);
        return result("verified", `implementation ${implementation}`);
      }
      return result("failed", msg);
    }
    return result("failed", `still pending after ${(STATUS_POLLS * STATUS_POLL_MS) / 1000}s (guid ${guid})`);
  } catch (e: any) {
    return result("failed", e?.message ?? String(e));
  }
};

/** Prints one line per result with its explorer link; returns how many failed. */
export const printVerifySummary = (results: VerifyResult[]): number => {
  const browser = apiConfig()?.browser?.replace(/\/$/, "");
  console.log("\nEtherscan verification:");
  for (const r of results) {
    const link = browser && r.status !== "failed" && r.status !== "skipped" ? `  ${browser}/address/${r.address}#code` : "";
    const detail = r.detail ? `  (${r.detail})` : "";
    console.log(`  ${r.status.toUpperCase().padEnd(16)} ${r.label.padEnd(28)} ${r.address}${link}${detail}`);
  }
  const failed = results.filter((r) => r.status === "failed").length;
  if (failed) console.error(`\x1b[1;31m✖ ${failed} contract(s) failed Etherscan verification\x1b[0m`);
  return failed;
};
