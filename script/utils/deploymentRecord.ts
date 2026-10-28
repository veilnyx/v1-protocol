import { existsSync, mkdirSync, readdirSync, writeFileSync } from "fs";
import { join } from "path";

/**
 * Naming and writing of the records in `deployments/`.
 *
 * A record is `deployments/<name>-<YYYY-MM-DD>.json` (UTC date of the write) and its first key is
 * `purpose`, a sentence saying why the deployment or upgrade happened. The chain id is a field
 * inside the record, not part of the name: a dry run against a mainnet fork shares mainnet's chain
 * id, so the id never told a real record from a rehearsal anyway.
 *
 * Real records are never overwritten: a second deployment under the same name on the same day has
 * to pick a new name. Rehearsals and dry runs (a `suffix` such as `-fork-rehearsal`) are scratch
 * output and are replaced on every run.
 *
 * Callers run {@link assertRecordWritable} before deploying anything, so a missing purpose, a bad
 * name or an existing record fails the run while it is still free.
 */

export const DEPLOYMENTS_DIR = join(__dirname, "..", "..", "deployments");

const NAME_RE = /^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$/;
const DATE_RE = "\\d{4}-\\d{2}-\\d{2}";

const today = () => new Date().toISOString().slice(0, 10);

export type RecordTarget = { name: string; purpose: string; suffix?: string };

export const recordPath = (name: string, suffix = "", date = today()) =>
  join(DEPLOYMENTS_DIR, `${name}-${date}${suffix}.json`);

/** Throws unless `target` names a record that {@link writeRecord} could write right now. */
export const assertRecordWritable = ({ name, purpose, suffix = "" }: RecordTarget) => {
  if (!NAME_RE.test(name)) {
    throw new Error(`deployment name "${name}" must be letters, digits and single hyphens (e.g. queue-stable-batch)`);
  }
  if (new RegExp(`-${DATE_RE}$`).test(name)) {
    throw new Error(`deployment name "${name}" must not carry a date; the record's file name adds one`);
  }
  if (!purpose.trim()) {
    throw new Error("a deployment record needs a purpose (DEPLOYMENT_PURPOSE): say why this deployment happens");
  }
  const file = recordPath(name, suffix);
  if (!suffix && existsSync(file)) {
    throw new Error(`${file} already exists; deployment records are never overwritten, so pick another name`);
  }
  return file;
};

/** Writes `{ purpose, ...body }` and returns the path. */
export const writeRecord = (target: RecordTarget, body: Record<string, unknown>) => {
  const file = assertRecordWritable(target);
  mkdirSync(DEPLOYMENTS_DIR, { recursive: true });
  writeFileSync(file, JSON.stringify({ purpose: target.purpose, ...body }, null, 2));
  return file;
};

/** The single record `<name>-<date><suffix>.json`, whatever day it was written on. */
export const findRecord = (name: string, suffix = "") => {
  const re = new RegExp(`^${name}-${DATE_RE}${suffix}\\.json$`);
  const hits = existsSync(DEPLOYMENTS_DIR) ? readdirSync(DEPLOYMENTS_DIR).filter(f => re.test(f)) : [];
  if (hits.length !== 1) {
    throw new Error(
      `expected one deployments/${name}-<date>${suffix}.json, found ${hits.length ? hits.join(", ") : "none"}`
    );
  }
  return join(DEPLOYMENTS_DIR, hits[0]);
};
