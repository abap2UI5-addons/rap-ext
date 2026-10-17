#!/usr/bin/env node
/*
 * core-pin — which abap2UI5 this repository is checked against.
 *
 * abaplint resolves the core as a git dependency (abaplint.jsonc), and
 * without a "branch" key it clones the DEFAULT branch - so this addon used to
 * be linted against the framework's development tip while every user of it
 * installs a RELEASE. CONVENTIONS §9 of abap2UI5 names that gap: code that
 * only works on main passes here, and a framework change reddens this
 * repository without a commit of its own.
 *
 * So the dependency names a release tag, and this script is the one place
 * that reads or moves it:
 *
 *   node scripts/core-pin.mjs get           print the pinned ref
 *   node scripts/core-pin.mjs set <ref>     pin a tag (or `main` for the canary)
 *   node scripts/core-pin.mjs latest        print the newest release tag
 *
 * `set main` is what the weekly canary run in abap-standard.yaml does in its own
 * checkout - it is never committed. bump-core.yml moves the pin to `latest`
 * after the gates passed on it.
 *
 * abaplint-cloud.jsonc (npm run lint:cloud) names the same release: `set`
 * moves it there too, `get` reads abaplint.jsonc and fails when the two
 * differ.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const FILE = new URL('../abaplint.jsonc', import.meta.url);
const CLOUD_FILE = new URL('../abaplint-cloud.jsonc', import.meta.url);
const CORE = 'https://github.com/abap2UI5/abap2UI5';
// the one line the pin lives on - kept on its own line next to the core URL
const PIN = /("branch":\s*")([^"]+)(")/;

function read(file = FILE) {
  const text = readFileSync(file, 'utf8');
  const at = text.indexOf(`"url": "${CORE}"`);
  if (at < 0) throw new Error(`abaplint.jsonc: no dependency on ${CORE}`);
  const block = text.slice(at, text.indexOf('}', at));
  const m = block.match(PIN);
  if (!m) throw new Error('abaplint.jsonc: the core dependency has no "branch" key');
  return { text, at, block, ref: m[2] };
}

const [cmd, arg] = process.argv.slice(2);

if (cmd === 'get') {
  const { ref } = read();
  const cloud = read(CLOUD_FILE).ref;
  if (cloud !== ref) throw new Error(`abaplint-cloud.jsonc pins ${cloud}, abaplint.jsonc ${ref}`);
  console.log(ref);
} else if (cmd === 'set') {
  if (!arg) throw new Error('usage: core-pin.mjs set <ref>');
  for (const file of [FILE, CLOUD_FILE]) {
    const { text, at, block } = read(file);
    const next = block.replace(PIN, `$1${arg}$3`);
    writeFileSync(file, text.slice(0, at) + next + text.slice(at + block.length));
  }
  console.log(`core pinned to ${arg}`);
} else if (cmd === 'latest') {
  // plain release tags only - `1.146.0`, not the downported `1.146.0-702`
  const out = execFileSync('git', ['ls-remote', '--tags', '--refs', CORE], { encoding: 'utf8' });
  const tags = out.split('\n')
    .map((l) => l.split('refs/tags/')[1])
    .filter((t) => t && /^\d+\.\d+\.\d+$/.test(t))
    .sort((a, b) => {
      const pa = a.split('.').map(Number);
      const pb = b.split('.').map(Number);
      return pa[0] - pb[0] || pa[1] - pb[1] || pa[2] - pb[2];
    });
  if (!tags.length) throw new Error('no release tag found');
  console.log(tags[tags.length - 1]);
} else {
  console.error('usage: core-pin.mjs get | set <ref> | latest');
  process.exit(1);
}
