#!/usr/bin/env node
/*
 * unit — the ABAP Unit tests that need no SAP system, run transpiled.
 *
 * Only the classes listed in UNITS are transpiled (with open-abap-core as
 * the runtime library): their tests drive code that works on plain data.
 * The floorplans need the abap2UI5 core and a system's DDIC and are not part
 * of this run - the overview page's test runs in a system (AGENTS.md).
 *
 * An SAP object the runtime does not know (the annotation service, DDIC
 * types) compiles to a runtime error in the code that uses it
 * (unknownTypes: runtimeError), so a test that reached it would fail - none
 * of the listed tests does.
 *
 *   node scripts/unit.mjs      (npm run unit)
 */
import { cpSync, mkdirSync, rmSync, writeFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const WORK = join(ROOT, '.unit');
const UNITS = ['z2ui5_cl_rap_util'];

rmSync(WORK, { recursive: true, force: true });
mkdirSync(join(WORK, 'src'), { recursive: true });
for (const file of readdirSync(join(ROOT, 'src'))) {
  if (UNITS.some((u) => file.startsWith(`${u}.`))) {
    cpSync(join(ROOT, 'src', file), join(WORK, 'src', file));
  }
}

writeFileSync(join(WORK, 'abap_transpile.json'), JSON.stringify({
  input_folder: 'src',
  output_folder: 'output',
  libs: [{ url: 'https://github.com/open-abap/open-abap-core', folder: '/deps/open-abap-core' }],
  write_unit_tests: true,
  write_source_map: true,
  options: {
    ignoreSyntaxCheck: false,
    addFilenames: true,
    addCommonJS: true,
    unknownTypes: 'runtimeError',
  },
}, null, 2));

const bin = (name) => join(ROOT, 'node_modules', '.bin', name);
execFileSync(bin('abap_transpile'), ['abap_transpile.json'], { cwd: WORK, stdio: 'inherit' });
execFileSync(process.execPath, [join(WORK, 'output', 'index.mjs')], { cwd: WORK, stdio: 'inherit' });
