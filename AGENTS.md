# AGENTS.md — cds-wrapper

Single source of truth for agents working on the **abap2UI5 cds-wrapper**
addon — Fiori-Elements-style floorplans (List Report, Object Page, Worklist,
Value Help, Overview Page, Action Dialog) generated at runtime from CDS
views and their UI annotations, rendered with abap2UI5.

> This entire project is in **English** — code, comments, commit messages,
> PRs, documentation.

## Build & verify

Two automated gates, both running offline against cloned dependencies (no
SAP system needed):

```bash
npx --yes @abaplint/cli@latest abaplint.jsonc     # expect 0 issues
npx --yes github:abap2UI5/abap2UI5-linter         # views: metadata + headless render
npx --yes github:abap2UI5/abap2UI5-linter --no-render   # fast loop, no browser
```

- abaplint clones the two dependencies from the URLs in `abaplint.jsonc`
  (the steampunk-2305 API set and the abap2UI5 core repo), so the first run
  needs network access.
- The **abap2UI5-linter** checks every view the floorplans build: unknown,
  deprecated or too-new controls and members, binding mistakes, malformed
  builder trees, and a real headless `XMLView.create`. Its settings (paths,
  UI5 floor, fail level) live in `abap2ui5lint.jsonc`.
- CI (`.github/workflows/check.yml`) runs both gates on every push and PR —
  a local clean run means CI passes.
- **There is no unit test suite and no transpiled runtime here.** The only
  end-to-end verification is manual: install via abapGit in a system with
  CDS views, run the demo class `z2ui5_cl_rap_test`, and click through the
  floorplans. State in the PR what was and was not verified that way.

## Target platform — do not "modernize"

- **UI5 floor is 1.77** (`abap2ui5lint.jsonc`), not the framework's 1.71: the
  object page uses `sap.uxap.ObjectPageSubSection.showTitle` (@since 1.77) to
  render one subsection per section without a duplicate title. Keep the floor
  at the oldest release the code actually needs — raising it further silently
  stops the gate from reporting members missing on real systems.
- Syntax level is **v758**; the abaplint dependency is the steampunk-2305 API
  set, but the wrapper deliberately uses **on-prem DDIC APIs**
  (`cl_dd_ddl_annotation_service`, `DDSTRUCOBJNAME`) to read CDS annotations —
  these are not released for ABAP Cloud, which is why
  `abaplint.jsonc` sets `errorNamespace: "^Z"` (unknown SAP-standard objects
  are void; the own namespace stays fully checked).
- `z2ui5_cl_rap_util` reads types via **classic RTTI** (`cl_abap_typedescr`),
  not the XCO library. Do not rewrite RTTI to XCO or swap the annotation API
  "for cloud readiness" — that changes the supported platform and is a
  maintainer decision, not a cleanup.
- Views are built with the generic builder **`z2ui5_cl_ai_xml`**
  (`open`/`leaf`/`a`/`shut`/`stringify`). The frozen fluent builder
  `z2ui5_cl_xml_view` is gone from this repo — do not reintroduce it.
  Two traps when editing a view:
  **(a)** `a( )` targets the LAST CHILD once the node has children, so write
  a control's attributes immediately after its `open`/`leaf`;
  **(b)** an `abap_bool` fed into an attribute must go through
  `z2ui5_cl_ai_xml=>as_bool( )` — a raw `abap_false` renders as an empty
  string, which UI5 reads as true.

## What the view gate can and cannot see here

Since the migration to `z2ui5_cl_ai_xml` the
[abap2UI5-linter](https://github.com/abap2UI5/abap2UI5-linter) reconstructs
these views statically, including the parts built in the render hooks: a hook
that takes a builder handle (`io_table`, `io_op`, `io_container`, …) is
replayed against the handle it is passed. What it cannot follow is a view
assembled through a mechanism it has no way to resolve statically — a handle
stored in an instance attribute, or a hook called through a dynamic
dispatch. When a change makes the linter report *fewer* documents than the
class actually builds, that is the signal.

The gate judges the view, not the data: which columns the CDS annotations
produce at runtime is invisible to it, so a wrong annotation reading is still
only caught in a system.

## Public contract — the escape hatch is API

The floorplans are deliberately **not FINAL**: subclasses redefine the
`PROTECTED` render/event/data steps listed in `README.md` ("Overridable
steps per floorplan" — `render_page`, `render_table`, `render_toolbar`,
`on_event`, `load_data`, `save_data`, …). Downstream apps inherit from these
classes, so those method names and signatures are a **public contract**:

- Do not rename, remove, or narrow any `PROTECTED` render/event/data-step
  method, and do not make a floorplan class `FINAL`.
- The builder-handle parameters (`io_page`, `io_table`, `io_columns`,
  `io_cells`, `io_op`, `io_actions`, `io_parent`, `io_container`) are typed
  `TYPE REF TO z2ui5_cl_ai_xml`. Changing that type again is a breaking
  change for every subclass — the migration off `z2ui5_cl_xml_view` already
  was one, and is recorded in the README.
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
- Every artifact carries the `Z2UI5_<type>_RAP_` prefix — the same scheme the
  [samples](https://github.com/abap2UI5/samples) repo uses with its `SMP` token
  (`Z2UI5_CL_SMP_…`, `Z2UI5_T_SMP_…`). Here: `Z2UI5_CL_RAP_…` for classes,
  `Z2UI5_DD_RAP_…` for DDLS. New objects follow it; nothing stays on the old
  `Z2UI5_CDS_` / `Z2UI5_CL_CDS_` names.
  Note that this is the *object* namespace only — the `cds_view_name`
  constructor parameter and the `CDS` wording in descriptions are part of the
  public contract / prose and are deliberately untouched.

## Related repositories

| Repository | Relation |
| --- | --- |
| [abap2UI5](https://github.com/abap2UI5/abap2UI5) | Core framework — consumed classes: `z2ui5_if_app`, `z2ui5_if_client`, `z2ui5_cl_ai_xml`, popups. Resolved as an abaplint dependency; there is no version pin, so keep to long-stable core API only |
| [samples](https://github.com/abap2UI5/samples) | Sample applications |
| `z2ui5_cl_fp_list_report` (core) | **Does not exist in core `main`** — added in core #2505 and removed again days later by an abapGit sync. Do not reference it as available; re-check before ever citing it again |
