#!/usr/bin/env node
/*
 * unit — the ABAP Unit tests that need no SAP system, run transpiled.
 *
 * Transpiled with open-abap-core as the runtime library:
 *   - UNITS, the classes of this repository the tests need. Their test
 *     classes run: z2ui5_cl_rap_util (annotations, filter syntax, the DDL
 *     association parser, export and URL helpers) and, since 2026-10, the
 *     list report and the object page (the steps that decide order, filters,
 *     views, columns, sections and the place of a child in its business
 *     object - on metadata set by hand, no row read).
 *   - CORE, the public API of the abap2UI5 release abaplint.jsonc pins
 *     (src/02: the app and client interfaces, the view builder) - what the
 *     floorplans are written against. Its own test classes are left out.
 *
 * z2ui5_cl_rap_eml is not part of it: the transpiler has no EML. A class
 * that is not transpiled, and an SAP object the runtime does not know (the
 * annotation service, DDIC types, a CDS view), compiles to a runtime error
 * in the code that uses it (unknownTypes: runtimeError), so a test must not
 * reach one - none of the listed tests does. The overview page's test runs
 * in a system only (it drives the core's handler).
 *
 *   node scripts/unit.mjs      (npm run unit)
 */
import { cpSync, mkdirSync, rmSync, writeFileSync, readdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const WORK = join(ROOT, '.unit');
const UNITS = [
  'z2ui5_cl_rap_util',
  'z2ui5_if_rap_ext',
  'z2ui5_cl_rap_floorplan',
  'z2ui5_cl_rap_list_report',
  'z2ui5_cl_rap_object_page',
  'z2ui5_cl_rap_value_help',
  'z2ui5_cl_rap_action_dialog',
  'z2ui5_cl_rap_variant',
  'z2ui5_cl_rap_start',
];
const CORE_URL = 'https://github.com/abap2UI5/abap2UI5';
const CORE = ['z2ui5_if_app', 'z2ui5_if_client', 'z2ui5_cl_ui5_view_builder'];

// the release abaplint.jsonc pins - the same line scripts/core-pin.mjs reads
function corePin() {
  const text = readFileSync(join(ROOT, 'abaplint.jsonc'), 'utf8');
  const at = text.indexOf(`"url": "${CORE_URL}"`);
  const m = text.slice(at, text.indexOf('}', at)).match(/"branch":\s*"([^"]+)"/);
  if (at < 0 || !m) throw new Error('abaplint.jsonc: no pinned core dependency');
  return m[1];
}

rmSync(WORK, { recursive: true, force: true });
mkdirSync(join(WORK, 'src'), { recursive: true });
for (const file of readdirSync(join(ROOT, 'src'))) {
  if (UNITS.some((u) => file.startsWith(`${u}.`))) {
    cpSync(join(ROOT, 'src', file), join(WORK, 'src', file));
  }
}

const coreDir = join(WORK, 'core');
execFileSync('git', ['clone', '--quiet', '--depth', '1', '--branch', corePin(), CORE_URL, coreDir], { stdio: 'inherit' });
for (const file of readdirSync(join(coreDir, 'src', '02'))) {
  if (CORE.some((c) => file.startsWith(`${c}.`)) && !file.includes('.testclasses.')) {
    cpSync(join(coreDir, 'src', '02', file), join(WORK, 'src', file));
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
