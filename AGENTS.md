# AGENTS.md — cds-wrapper

Single source of truth for agents working on the **abap2UI5 cds-wrapper**
addon — Fiori-Elements-style floorplans (List Report, Object Page, Worklist,
Value Help, Overview Page, Action Dialog) generated at runtime from CDS
views and their UI annotations, rendered with abap2UI5.

> This entire project is in **English** — code, comments, commit messages,
> PRs, documentation.

## Build & verify

There is exactly one automated verification, and it runs offline against
cloned dependencies (no SAP system needed):

```bash
npx --yes @abaplint/cli@latest abaplint.jsonc     # expect 0 issues
```

- abaplint clones the two dependencies from the URLs in `abaplint.jsonc`
  (the steampunk-2305 API set and the abap2UI5 core repo), so the first run
  needs network access.
- CI (`.github/workflows/abaplint.yml`) runs the same command on every push
  and PR — a local 0-issue run means CI passes.
- **There is no unit test suite and no transpiled runtime here.** The only
  end-to-end verification is manual: install via abapGit in a system with
  CDS views, run the demo class `z2ui5_cl_cds_test`, and click through the
  floorplans. State in the PR what was and was not verified that way.

## Target platform — do not "modernize"

- Syntax level is **v758**; the abaplint dependency is the steampunk-2305 API
  set, but the wrapper deliberately uses **on-prem DDIC APIs**
  (`cl_dd_ddl_annotation_service`, `DDSTRUCOBJNAME`) to read CDS annotations —
  these are not released for ABAP Cloud, which is why
  `abaplint.jsonc` sets `errorNamespace: "^Z"` (unknown SAP-standard objects
  are void; the own namespace stays fully checked).
- `z2ui5_cl_cds_util` reads types via **classic RTTI** (`cl_abap_typedescr`),
  not the XCO library. Do not rewrite RTTI to XCO or swap the annotation API
  "for cloud readiness" — that changes the supported platform and is a
  maintainer decision, not a cleanup.
- Views are built with the framework's fluent builder **`z2ui5_cl_xml_view`**
  (frozen in core, but the supported builder for downstream code like this
  addon). Do not migrate the addon to `z2ui5_cl_ai_xml` as a refactoring —
  same reason.

## Consequence: the ecosystem's AI tooling does NOT apply here

The [abap2UI5-linter](https://github.com/abap2UI5/abap2UI5-linter) only picks
up classes built with `z2ui5_cl_ai_xml` (`collectFiles` matches on
`z2ui5_cl_ai_xml=>factory`), and the [ai-mcp](https://github.com/abap2UI5/ai-mcp)
deploy/run loop targets `z2ui5_if_app` port classes in ai-demokit. **Neither
can validate or run this repo's code** — do not spend a loop trying, and do
not "fix" this code to fit those tools. abaplint (above) is the gate.

## Public contract — the escape hatch is API

The floorplans are deliberately **not FINAL**: subclasses redefine the
`PROTECTED` render/event/data steps listed in `README.md` ("Overridable
steps per floorplan" — `render_page`, `render_table`, `render_toolbar`,
`on_event`, `load_data`, `save_data`, …). Downstream apps inherit from these
classes, so those method names and signatures are a **public contract**:

- Do not rename, remove, or narrow any `PROTECTED` render/event/data-step
  method, and do not make a floorplan class `FINAL`.
- Do not change existing method signatures; additive optional parameters are
  fine.
- The `cs_event` constants and the constructor signatures
  (`cds_view_name = …`) are part of the same contract.
- New steps are welcome — extract them as new `PROTECTED` methods so they
  become overridable too, and list them in the README.

## abapGit conventions

- The repo is an abapGit project (`.abapgit.xml`, `STARTING_FOLDER=/src/`,
  `FOLDER_LOGIC=PREFIX`). Every `.clas.abap` needs its `.clas.xml` sidecar.
- `*.ddls.baseinfo` files are **abapGit serialization artifacts — never
  hand-edit** them; they change only when the CDS sources are re-serialized
  from a system.
- Line endings are **LF only** (a CRLF import once broke the `.asddls`
  round-trip — enforced by `.gitattributes`), UTF-8, final newline.
- Class names stay in the `Z2UI5_CDS_` / `Z2UI5_CL_CDS_` namespace.

## Related repositories

| Repository | Relation |
| --- | --- |
| [abap2UI5](https://github.com/abap2UI5/abap2UI5) | Core framework — consumed classes: `z2ui5_if_app`, `z2ui5_if_client`, `z2ui5_cl_xml_view`, popups. Resolved as an abaplint dependency; there is no version pin, so keep to long-stable core API only |
| [samples](https://github.com/abap2UI5/samples) | Sample applications |
| `z2ui5_cl_fp_list_report` (core) | The RTTI-based sibling for non-CDS data — cds-wrapper is the annotation-driven counterpart (note: verify the class exists in current core `main` before referencing it; it has been removed and re-added before) |
