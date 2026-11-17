#!/usr/bin/env node
/*
 * pin-deps.mjs - the sibling repositories an addon builds on, at the commit
 * its .github/deps.json names instead of the moving tip of their main.
 *
 * Part of the shared CI template of abap2UI5-addons (.github/ci/README.md).
 * The reusable workflows check this file out at the commit the caller pinned
 * them to (job.workflow_sha), so a fix here lands in every addon with the next
 * bump of that pin - nobody copies it.
 *
 * .github/deps.json of the addon:
 *
 *   {
 *     "abap2UI5-addons/layout-management": { "branch": "main", "sha": "<40 hex>" },
 *     "abap2UI5-addons/range-filter":      { "branch": "main", "sha": "<40 hex>" }
 *   }
 *
 * How a pin reaches the three places that resolve a sibling:
 *
 *   abaplint  - a dependency is read from its local "folder" (relative to the
 *               config) when that folder holds files, and cloned from "url"
 *               only when it does not (@abaplint/cli loadDependencies). So
 *               every dependency whose url is pinned, and whose "branch" is
 *               absent or the pinned branch, gets its folder filled with the
 *               pinned checkout. The configs stay as they are; a dependency
 *               on another branch (702) is left alone.
 *   rename    - .github/scripts/rename.mjs takes RENAME_DEPS_FROM=<out>
 *               (<out>/<repository name> per sibling).
 *   unit      - the addon's .github/scripts/unit.mjs reads deps.json itself.
 *
 *   node pin-deps.mjs                  fetch every pin into .deps/ and fill
 *                                      the abaplint dependency folders
 *   node pin-deps.mjs --tip            the same at the tip of each branch -
 *                                      the scheduled canary
 *   node pin-deps.mjs clean            remove what the last run filled
 *   node pin-deps.mjs bump [--summary <file>]
 *                                      move every sha to the tip of its
 *                                      branch (bump-deps)
 *
 * Options: --deps <file> (default .github/deps.json), --out <dir> (default
 * .deps), --root <dir> (default the current directory). No deps.json: nothing
 * to do, exit 0.
 */
import { execFileSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync, appendFileSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : def;
};
const mode = ["clean", "bump"].find((m) => args.includes(m)) ?? "pin";
const ROOT = resolve(opt("--root", "."));
const DEPS_FILE = resolve(ROOT, opt("--deps", ".github/deps.json"));
const OUT = resolve(ROOT, opt("--out", ".deps"));
const STATE = join(OUT, "filled.json");
const TIP = args.includes("--tip");
// where owner/repo is fetched from - another base only for the tests
const BASE = process.env.PIN_DEPS_GIT_BASE ?? "https://github.com";

const fail = (msg) => {
  console.error(`::error::pin-deps: ${msg}`);
  process.exit(1);
};
const git = (argv, cwd) => execFileSync("git", argv, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] }).trim();
const keyOf = (url) => (url ?? "").toLowerCase().replace(/^.*github\.com[/:]/, "").replace(/\.git$/, "").replace(/\/$/, "");

// JSON with comments and trailing commas, as the abaplint configs are written
function readJsonc(file) {
  const text = readFileSync(file, "utf8");
  let out = "";
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      let j = i + 1;
      while (j < text.length && text[j] !== '"') j += text[j] === "\\" ? 2 : 1;
      out += text.slice(i, j + 1);
      i = j;
    } else if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      out += "\n";
    } else if (c === "/" && text[i + 1] === "*") {
      i = text.indexOf("*/", i + 2) + 1;
    } else {
      out += c;
    }
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g, "$1"));
}

// ------------------------------------------------------------------ clean
function clean() {
  if (!existsSync(STATE)) return;
  for (const t of JSON.parse(readFileSync(STATE, "utf8"))) rmSync(resolve(ROOT, t), { recursive: true, force: true });
  rmSync(OUT, { recursive: true, force: true });
  console.log("pin-deps: removed the filled folders and " + relative(ROOT, OUT));
}
if (mode === "clean") {
  clean();
  process.exit(0);
}

if (!existsSync(DEPS_FILE)) {
  console.log(`pin-deps: no ${relative(ROOT, DEPS_FILE)} - nothing is pinned`);
  process.exit(0);
}
const raw = JSON.parse(readFileSync(DEPS_FILE, "utf8"));
const pins = new Map();
for (const [repo, p] of Object.entries(raw)) {
  if (repo.startsWith("$") || repo.startsWith("_")) continue; // $comment
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) fail(`${repo}: the key is owner/repository`);
  if (!p || typeof p.branch !== "string" || !/^[0-9a-f]{40}$/.test(p.sha ?? "")) {
    fail(`${repo}: needs { "branch": "<name>", "sha": "<40 hex>" }`);
  }
  pins.set(repo.toLowerCase(), { repo, ...p });
}

// ------------------------------------------------------------------- bump
if (mode === "bump") {
  const lines = [];
  for (const p of pins.values()) {
    const out = git(["ls-remote", `${BASE}/${p.repo}`, `refs/heads/${p.branch}`], ROOT);
    const sha = out.split(/\s/)[0];
    if (!/^[0-9a-f]{40}$/.test(sha)) fail(`${p.repo}: no branch ${p.branch}`);
    if (sha !== p.sha) {
      lines.push(`- \`${p.repo}\` ${p.branch}: ${p.sha.slice(0, 7)} → ${sha.slice(0, 7)} ([diff](https://github.com/${p.repo}/compare/${p.sha}...${sha}))`);
      raw[Object.keys(raw).find((k) => k.toLowerCase() === p.repo.toLowerCase())].sha = sha;
    }
  }
  writeFileSync(DEPS_FILE, JSON.stringify(raw, null, 2) + "\n");
  console.log(`pin-deps: ${lines.length} pin(s) moved`);
  const summary = opt("--summary");
  if (summary && lines.length) appendFileSync(summary, ["**Sibling repositories** (`.github/deps.json`)", "", ...lines, ""].join("\n") + "\n");
  process.exit(0);
}

// -------------------------------------------------------------------- pin
clean();
mkdirSync(OUT, { recursive: true });
for (const p of pins.values()) {
  const dir = join(OUT, p.repo.split("/")[1]);
  mkdirSync(dir, { recursive: true });
  git(["init", "--quiet"], dir);
  git(["remote", "add", "origin", `${BASE}/${p.repo}`], dir);
  git(["fetch", "--quiet", "--depth", "1", "origin", TIP ? `refs/heads/${p.branch}` : p.sha], dir);
  git(["-c", "advice.detachedHead=false", "checkout", "--quiet", "FETCH_HEAD"], dir);
  p.dir = dir;
  p.at = git(["rev-parse", "HEAD"], dir);
  console.log(`pin-deps: ${p.repo} ${TIP ? `${p.branch} tip` : "pinned"} @ ${p.at}`);
  rmSync(join(dir, ".git"), { recursive: true, force: true });
}

// every tracked abaplint config: abaplint*.json(c) at the root and the ones
// under .github/abaplint/
let tracked;
try {
  tracked = git(["ls-files"], ROOT).split("\n");
} catch {
  tracked = [];
}
const configs = tracked.filter((f) => /^abaplint[\w.-]*\.jsonc?$/.test(f) || /^\.github\/abaplint\/[^/]+\.jsonc?$/.test(f));

const filled = new Map(); // absolute target -> { repo, config }
const claims = new Map(); // absolute target -> what each config wants there
const used = new Set();
for (const cfg of configs) {
  let json;
  try {
    json = readJsonc(join(ROOT, cfg));
  } catch (e) {
    fail(`${cfg}: ${e.message}`);
  }
  for (const d of json.dependencies ?? []) {
    if (!d.folder) continue;
    const target = resolve(ROOT, dirname(cfg), "." + d.folder);
    const p = pins.get(keyOf(d.url));
    const pinned = p && (d.branch === undefined || d.branch === p.branch);
    const want = pinned ? `pinned ${p.repo}` : `${d.url ?? "local"}${d.branch ? `@${d.branch}` : ""}`;
    // only a filled folder can be read by the wrong config - two unpinned
    // dependencies sharing a folder name are both cloned, as before
    for (const prev of claims.get(target) ?? []) {
      if (prev.want !== want && (pinned || prev.want.startsWith("pinned "))) {
        fail(`${cfg} and ${prev.cfg} use the folder ${relative(ROOT, target)} for different sources (${want} / ${prev.want}) - give one of them a folder of its own`);
      }
    }
    claims.set(target, [...(claims.get(target) ?? []), { want, cfg }]);
    if (!pinned) continue;
    if (target === ROOT || (target + sep).startsWith(join(ROOT, "src") + sep) || ROOT.startsWith(target + sep)) {
      fail(`${cfg}: the folder ${d.folder} of ${p.repo} lies on the repository's own sources`);
    }
    if (!filled.has(target)) {
      if (tracked.some((f) => resolve(ROOT, f).startsWith(target + sep))) {
        fail(`${cfg}: the folder ${relative(ROOT, target)} of ${p.repo} holds tracked files`);
      }
      rmSync(target, { recursive: true, force: true });
      cpSync(p.dir, target, { recursive: true });
      filled.set(target, { repo: p.repo, cfg });
      console.log(`pin-deps: ${cfg} ${p.repo} -> ${relative(ROOT, target)}`);
    }
    used.add(p.repo);
  }
}
writeFileSync(STATE, JSON.stringify([...filled.keys()].map((t) => relative(ROOT, t)), null, 2) + "\n");
for (const p of pins.values()) {
  if (!used.has(p.repo)) console.log(`::warning::pin-deps: no abaplint config depends on ${p.repo} - it is pinned for rename/unit only`);
}
// GitHub Actions: the folder rename.mjs reads the siblings from
if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, `RENAME_DEPS_FROM=${OUT}\n`);
console.log(`pin-deps: ${filled.size} abaplint dependency folder(s) filled; RENAME_DEPS_FROM=${relative(ROOT, OUT) || "."}`);
