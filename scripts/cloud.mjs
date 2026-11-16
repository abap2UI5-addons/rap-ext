#!/usr/bin/env node
/*
 * cloud — builds the ABAP Cloud version of rap-ext into build/cloud and
 * checks it. That tree is what the workflow cloud-branch.yaml publishes to
 * the branch `cloud`, the one to link in an ABAP Cloud system.
 *
 * Why a branch of its own: the ABAP Cloud syntax check reports an
 * unreleased object even where the code only names it by a literal in a
 * dynamic statement (CALL METHOD (`CL_DD_DDL_ANNOTATION_SERVICE`)=>...,
 * CREATE DATA ... TYPE (`DDFIELDS`), AUTHORITY-CHECK OBJECT lv_object) - so
 * "every on-premise object is named dynamically only" did not activate in
 * ABAP Cloud. Everything on-premise now lives in z2ui5_cl_rap_platform; on
 * main it is the on-premise version, and here every file in cloud/
 * replaces the file of the same name in src/.
 *
 * The build:
 *   build/cloud/.abapgit.xml   from main
 *   build/cloud/src/           src/ with the files of cloud/ in place
 *   build/cloud/README.md      what the branch is and where it comes from
 *   build/cloud/LICENSE
 *
 * The checks (exit 1 on a finding):
 *   - every file in cloud/ replaces a file in src/ - a stray one is a
 *     typo or a leftover;
 *   - an ABAP class replaced from cloud/ keeps the PUBLIC SECTION of its
 *     on-premise version, word for word - the other classes are compiled
 *     against both;
 *   - no ABAP code in the build names an on-premise object of FORBIDDEN,
 *     comments left out - the part abaplint cannot see (it checks static
 *     references only; abaplint-cloud.jsonc then checks the build).
 *
 *   node scripts/cloud.mjs      (part of npm run lint:cloud)
 */
import { cpSync, mkdirSync, rmSync, writeFileSync, readdirSync, readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const OUT = join(ROOT, 'build', 'cloud');
const OVERRIDES = join(ROOT, 'cloud');

// the on-premise objects rap-ext uses - all of them belong in the
// on-premise version of z2ui5_cl_rap_platform and nowhere else
const FORBIDDEN = [
  'CL_DD_DDL_ANNOTATION_SERVICE',
  'GET_ANNOS',
  'GET_DIRECT_ANNOS_4_ENTITY',
  'GET_DIRECT_ANNOS_4_ELEMENT',
  'GET_DDIC_FIELD_LIST',
  'GET_DDIC_FIXED_VALUES',
  'DDFIELDS',
  'DFIES',
  'DDFIXVALUES',
  'DD02L',
  'DD07L',
  'DD07T',
  'DDDDLSRC',
  'DDLDEPENDENCY',
  'S_TABU_NAM',
  'ENQUEUE_E_TABLE',
  'DEQUEUE_E_TABLE',
  // a CDS entity not in the released API set (steampunk-2305)
  'I_MESSAGESEVERITY',
];

const findings = [];

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
cpSync(join(ROOT, 'src'), join(OUT, 'src'), { recursive: true });
cpSync(join(ROOT, '.abapgit.xml'), join(OUT, '.abapgit.xml'));
cpSync(join(ROOT, 'LICENSE'), join(OUT, 'LICENSE'));

for (const file of readdirSync(OVERRIDES)) {
  if (file === 'README.md') continue;
  const target = join(ROOT, 'src', file);
  if (!existsSync(target)) {
    findings.push(`cloud/${file}: replaces nothing - there is no src/${file}`);
    continue;
  }
  if (file.endsWith('.clas.abap')) {
    const onPremise = publicSection(readFileSync(target, 'utf8'));
    const cloud = publicSection(readFileSync(join(OVERRIDES, file), 'utf8'));
    if (onPremise !== cloud) {
      findings.push(`cloud/${file}: its PUBLIC SECTION differs from src/${file} - change both`);
    }
  }
  cpSync(join(OVERRIDES, file), join(OUT, 'src', file));
}

const pattern = new RegExp(`(^|[^A-Z0-9_/])(${FORBIDDEN.join('|')})(?![A-Z0-9_])`, 'i');
for (const file of readdirSync(join(OUT, 'src'))) {
  if (!file.endsWith('.abap') && !file.endsWith('.asddls')) continue;
  const lines = readFileSync(join(OUT, 'src', file), 'utf8').split('\n');
  lines.forEach((line, i) => {
    const code = file.endsWith('.abap') ? stripAbapComment(line) : stripDdlComment(line);
    const m = code.match(pattern);
    if (m) {
      findings.push(`src/${file}:${i + 1}: names ${m[2].toUpperCase()} - not released in ABAP Cloud, move it into z2ui5_cl_rap_platform`);
    }
  });
}

writeFileSync(join(OUT, 'README.md'), `# rap-ext for ABAP Cloud

This branch is **built** - do not change it here. It is
[rap-ext](https://github.com/abap2UI5-addons/rap-ext) \`main\` with the files
of \`cloud/\` in place of the files of the same name in \`src/\`
(\`scripts/cloud.mjs\`, published by \`.github/workflows/cloud-branch.yaml\`
on every push to \`main\`).

Link this branch in an ABAP Cloud system (SAP BTP ABAP environment, S/4HANA
Cloud Public Edition). Link \`main\` on premise.

What differs in ABAP Cloud - the annotations through XCO, a database table
read-only - is in the README of \`main\`, section "ABAP Cloud".
`);

if (findings.length > 0) {
  console.log(findings.join('\n'));
  console.log(`\ncloud: ${findings.length} finding(s) - build/cloud is not what the branch cloud may carry`);
  process.exit(1);
}
console.log('cloud: build/cloud built and checked - 0 findings');

// from PUBLIC SECTION to the next section or the end of the definition
function publicSection(text) {
  const start = text.search(/^\s*PUBLIC SECTION\./mi);
  if (start < 0) return '';
  const rest = text.slice(start);
  const end = rest.search(/^\s*(PROTECTED SECTION|PRIVATE SECTION|ENDCLASS)\./mi);
  return rest.slice(0, end < 0 ? undefined : end).trim();
}

// the code of one ABAP line: a * line is a comment, " starts one outside
// of a literal (' ', ` `, | |)
function stripAbapComment(line) {
  if (line.startsWith('*')) return '';
  let quote = '';
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) {
      if (c === quote) quote = '';
      continue;
    }
    if (c === "'" || c === '`' || c === '|') quote = c;
    else if (c === '"') return line.slice(0, i);
  }
  return line;
}

function stripDdlComment(line) {
  const at = line.indexOf('//');
  return at < 0 ? line : line.slice(0, at);
}
