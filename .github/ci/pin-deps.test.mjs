// node --test ".github/ci/*.test.mjs" - pin-deps.mjs against throwaway git repositories
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), "pin-deps.mjs");
const git = (args, cwd) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd, encoding: "utf8" }).trim();

function write(file, text) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
}

// a "GitHub" of bare repositories: <base>/<owner>/<repo>; returns the commits
function sibling(base, repo, versions) {
  const work = mkdtempSync(join(tmpdir(), "pin-deps-src-"));
  git(["init", "-q", "-b", "main"], work);
  const shas = versions.map((v) => {
    write(join(work, "src", "zcl_x.clas.abap"), v);
    git(["add", "-A"], work);
    git(["commit", "-qm", v], work);
    return git(["rev-parse", "HEAD"], work);
  });
  const bare = join(base, repo);
  mkdirSync(dirname(bare), { recursive: true });
  git(["clone", "-q", "--bare", work, bare], tmpdir());
  git(["config", "uploadpack.allowAnySHA1InWant", "true"], bare);
  return shas;
}

function addon(deps, configs) {
  const root = mkdtempSync(join(tmpdir(), "pin-deps-addon-"));
  git(["init", "-q", "-b", "main"], root);
  write(join(root, "src", "zcl_mine.clas.abap"), "mine");
  if (deps) write(join(root, ".github", "deps.json"), JSON.stringify(deps, null, 2));
  for (const [file, text] of Object.entries(configs)) write(join(root, file), text);
  git(["add", "-A"], root);
  git(["commit", "-qm", "init"], root);
  return root;
}

const run = (root, base, ...args) =>
  spawnSync(process.execPath, [SCRIPT, ...args], { cwd: root, encoding: "utf8", env: { ...process.env, PIN_DEPS_GIT_BASE: base, GITHUB_ENV: "" } });

const cfg = (deps) => JSON.stringify({ global: { files: "/src/**/*.*" }, dependencies: deps });
const dep = (repo, folder, branch) => ({ url: `https://github.com/${repo}`, folder, files: "/src/**/*.*", ...(branch ? { branch } : {}) });

test("fills the folder of every pinned dependency with the pinned commit, leaves 702 and others alone", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [old] = sibling(base, "abap2UI5-addons/layout-management", ["v1", "v2"]);
  const root = addon(
    { "$comment": "x", "abap2UI5-addons/layout-management": { branch: "main", sha: old } },
    {
      "abaplint.jsonc": "// comment\n" + cfg([dep("abap2UI5/abap2UI5", "/abap2UI5", "main"), dep("abap2UI5-addons/layout-management", "/layout-management")]),
      ".github/abaplint/abap_cloud.jsonc": cfg([dep("abap2UI5-addons/Layout-Management.git", "/lm")]),
      ".github/abaplint/abap_702.jsonc": cfg([dep("abap2UI5-addons/layout-management", "/lm-702", "702")]),
    },
  );
  const r = run(root, base);
  assert.equal(r.status, 0, r.stderr + r.stdout);
  assert.equal(readFileSync(join(root, "layout-management/src/zcl_x.clas.abap"), "utf8"), "v1");
  assert.equal(readFileSync(join(root, ".github/abaplint/lm/src/zcl_x.clas.abap"), "utf8"), "v1");
  assert.ok(!existsSync(join(root, ".github/abaplint/lm-702")), "a dependency on another branch is not filled");
  assert.ok(!existsSync(join(root, "abap2UI5")), "an unpinned dependency is not filled");
  assert.ok(existsSync(join(root, ".deps/layout-management/src")), "the RENAME_DEPS_FROM folder");

  const tip = run(root, base, "--tip");
  assert.equal(tip.status, 0, tip.stderr);
  assert.equal(readFileSync(join(root, "layout-management/src/zcl_x.clas.abap"), "utf8"), "v2");

  assert.equal(run(root, base, "clean").status, 0);
  assert.ok(!existsSync(join(root, "layout-management")) && !existsSync(join(root, ".deps")));
});

test("an unclosed block comment in a config is an error, not an endless loop", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [sha] = sibling(base, "abap2UI5-addons/popups", ["v1"]);
  const root = addon({ "abap2UI5-addons/popups": { branch: "main", sha } }, { "abaplint.jsonc": cfg([dep("abap2UI5-addons/popups", "/popups")]) + "\n/* never closed\n" });
  const r = spawnSync(process.execPath, [SCRIPT], { cwd: root, encoding: "utf8", timeout: 20000, env: { ...process.env, PIN_DEPS_GIT_BASE: base, GITHUB_ENV: "" } });
  assert.equal(r.signal, null, "pin-deps hung");
  assert.equal(r.status, 1);
  assert.match(r.stderr, /abaplint\.jsonc: a \/\* comment is never closed/);
});

test("refuses a folder a 702 dependency shares with a pinned one", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [sha] = sibling(base, "abap2UI5-addons/popups", ["v1"]);
  const root = addon(
    { "abap2UI5-addons/popups": { branch: "main", sha } },
    {
      ".github/abaplint/abap_cloud.jsonc": cfg([dep("abap2UI5-addons/popups", "/popups")]),
      ".github/abaplint/abap_702.jsonc": cfg([dep("abap2UI5-addons/popups", "/popups", "702")]),
    },
  );
  const r = run(root, base);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /folder .*popups for different sources/);
});

test("two unpinned dependencies may share a folder name", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [sha] = sibling(base, "abap2UI5-addons/popups", ["v1"]);
  const root = addon(
    { "abap2UI5-addons/popups": { branch: "main", sha } },
    {
      "abaplint.jsonc": cfg([dep("abapedia/steampunk-2305-api", "/deps"), dep("abap2UI5-addons/popups", "/popups")]),
      ".github/abaplint/x.jsonc": cfg([dep("abapedia/steampunk-2305-api-intersect-702", "/../../deps")]),
    },
  );
  assert.equal(run(root, base).status, 0);
});

test("refuses a folder on the repository's own sources", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [sha] = sibling(base, "abap2UI5-addons/popups", ["v1"]);
  const root = addon({ "abap2UI5-addons/popups": { branch: "main", sha } }, { "abaplint.jsonc": cfg([dep("abap2UI5-addons/popups", "/src")]) });
  const r = run(root, base);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /own sources/);
});

test("a malformed pin fails, no deps.json passes", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  assert.equal(run(addon(null, { "abaplint.jsonc": cfg([]) }), base).status, 0);
  const r = run(addon({ "abap2UI5-addons/popups": { branch: "main", sha: "main" } }, {}), base);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /40 hex/);
});

test("bump moves every sha to the tip and writes a summary", () => {
  const base = mkdtempSync(join(tmpdir(), "pin-deps-gh-"));
  const [old, tip] = sibling(base, "abap2UI5-addons/range-filter", ["v1", "v2"]);
  const root = addon({ "abap2UI5-addons/range-filter": { branch: "main", sha: old } }, {});
  const summary = join(root, "summary.md");
  const r = run(root, base, "bump", "--summary", summary);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(JSON.parse(readFileSync(join(root, ".github/deps.json"), "utf8"))["abap2UI5-addons/range-filter"].sha, tip);
  assert.match(readFileSync(summary, "utf8"), /range-filter.*main/);
  rmSync(summary);
  assert.equal(run(root, base, "bump", "--summary", summary).status, 0);
  assert.ok(!existsSync(summary), "nothing moved, nothing written");
});
