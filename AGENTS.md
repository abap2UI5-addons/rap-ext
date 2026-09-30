# AGENTS.md — cds-wrapper

Single source of truth for agents working on the **abap2UI5 cds-wrapper**
addon — Fiori-Elements-style floorplans (List Report, Object Page, Worklist,
Value Help, Overview Page, Action Dialog) generated at runtime from CDS
views and their UI annotations, rendered with abap2UI5.

> This entire project is in **English** — code, comments, commit messages,
> PRs, documentation.

## What is where

| Object | Role |
| --- | --- |
| `z2ui5_cl_rap_floorplan` | superclass of every floorplan: reading, filter/search, input controls, value help, writing, texts, extension calls |
| `z2ui5_cl_rap_list_report`, `_worklist` (a subclass of it), `_object_page`, `_overview_page`, `_value_help`, `_action_dialog` | the floorplans - each an abap2UI5 app |
| `z2ui5_cl_rap_util` | the metadata: RTTI, DDIC keys/texts, annotations (`read_entity`, `apply_annotations`), the filter/search syntax - no UI, unit-tested |
| `z2ui5_cl_rap_eml` | the RAP write path - the only class with EML |
| `z2ui5_if_rap_ext` | the extension points (`set_extension( )`) |
| `z2ui5_cl_rap_test`, `z2ui5_dd_rap_test_*` | the demo app and its abstract entities |
| `scripts/` | `core-pin.mjs` (the core release abaplint checks against), `unit.mjs` (the transpiled unit run) |
| `ROADMAP.md` | what is done and what is open |

## Build & verify

Three automated gates, all running offline against cloned dependencies (no
SAP system needed):

```bash
npm ci                          # @abaplint/cli, the transpiler, @abap2ui5/linter
                                # and its render runtime, from the lockfile
npm run lint                    # abaplint - expect 0 issues
npm run unit                    # ABAP Unit tests that need no system, transpiled
npx abap2ui5lint                # views: metadata + headless render
npx abap2ui5lint --no-render    # fast loop, no browser
```

`npm run check` runs all three, exactly as CI does.

- abaplint clones the two dependencies from the URLs in `abaplint.jsonc`
  (the steampunk-2305 API set and the abap2UI5 core repo), so the first run
  needs network access. The core is **pinned to a release tag** (the
  `"branch"` key, abap2UI5 CONVENTIONS §9) - read and move it only with
  `scripts/core-pin.mjs`; `bump-core.yml` moves it weekly after abaplint
  passed on the new tag, and the scheduled run of `check.yml` lints against
  the core's `main` as the canary. Do not drop the key: abaplint then clones
  `main` silently.
- `npm run unit` (`scripts/unit.mjs`) transpiles the classes listed in its
  `UNITS` with open-abap-core and runs their ABAP Unit tests. Today that is
  `z2ui5_cl_rap_util`: the annotation parsing (`apply_annotations`) and the
  filter/search syntax that ends up in dynamic WHERE clauses. Logic that
  needs no system belongs there (static, on plain tables) so it can be
  tested; an SAP object the runtime lacks compiles to a runtime error in the
  code that uses it, so a test must not reach one.
- The **abap2UI5-linter** checks every view the floorplans build: unknown,
  deprecated or too-new controls and members, binding mistakes, malformed
  builder trees, and a real headless `XMLView.create`. Its settings (paths,
  UI5 floor, fail level) live in `abap2ui5lint.jsonc`;
  `abap2ui5lint-baseline.json` records the one accepted finding (the
  overview page's public `mt_card_data`, kept for the public contract and
  explained in `abap2ui5lint.jsonc`), and only shrinks.
- CI (`.github/workflows/check.yml`) runs the three gates on every push and
  PR - a local clean run means CI passes.
- The overview page's ABAP Unit test
  (`z2ui5_cl_rap_overview_page.clas.testclasses.abap`) drives a table card
  through the core's client, and a draft roundtrip through its handler. It
  runs in a system, not in `npm run unit` (it needs the core). It uses the
  same core internals as the core's own app tests (`z2ui5_cl_ui5_action`,
  `z2ui5_cl_ui5_handler`, `z2ui5_cl_ui5_client`, `z2ui5_cl_ui5_app_cont`), so
  when a core refactor turns `npm run lint` red there, follow what the core's
  tests did.
  Everything else is verified by hand: install via abapGit in a system with
  CDS views (and the /DMO/ flight scenario for the RAP paths), run the demo
  class `z2ui5_cl_rap_test`, and click through the floorplans. State in the
  PR what was and was not verified that way - **the RAP write path
  (`z2ui5_cl_rap_eml`, actions, capabilities) and the metadata-extension
  reading (`GET_ANNOS`) were written without a system** and are the first
  things to verify.

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
- Annotations are read with `CL_DD_DDL_ANNOTATION_SERVICE=>GET_ANNOS`
  (metadata extensions included), called **dynamically** with its parameter
  types taken from RTTI (`read_annos_effective`); when that fails, the
  direct annotations are read as before (`read_annos_direct`). Keep the
  dynamic call - a static one would pin the service's type names, which
  are not released.
- **`z2ui5_cl_rap_eml` is the only class with EML statements** (dynamic
  `MODIFY ENTITIES OPERATIONS`, `COMMIT ENTITIES RESPONSES`, `ROLLBACK
  ENTITIES`). Every call into it is guarded by
  `z2ui5_cl_rap_floorplan=>eml_available( )`, which answers from RTTI, so a
  system that cannot activate it still runs every floorplan read-only. Keep
  EML out of every other class. BDEF derived types are created from their
  absolute names (`\BDEF=...\ENTITY=...\TYPE=...`); whether an operation
  exists is whether its type can be created (`get_capabilities`).
- `z2ui5_cl_rap_util` reads types via **classic RTTI** (`cl_abap_typedescr`),
  not the XCO library. Do not rewrite RTTI to XCO or swap the annotation API
  "for cloud readiness" — that changes the supported platform and is a
  maintainer decision, not a cleanup.
- Views are built with the core's generic builder
  **`z2ui5_cl_ui5_view_builder`** (`ele`/`tag`/`a`/`end`/`stringify`), which
  lives in `src/02` and is part of the released API. The frozen fluent
  builder `z2ui5_cl_xml_view` is gone from this repo — do not reintroduce it,
  and do not invent a local builder name: a previous pass wrote
  `z2ui5_cl_ai_xml`, which exists in no repository, and the whole addon
  stopped compiling.
  Two traps when editing a view:
  **(a)** `a( )` targets the LAST CHILD once the node has children, so write
  a control's attributes immediately after its `ele`/`tag`;
  **(b)** an `abap_bool` goes into the attribute's **`b =`** parameter, not
  `v =` — a raw `abap_false` through `v =` renders as an empty string, which
  UI5 reads as true.

## What the view gate can and cannot see here

Since the migration to `z2ui5_cl_ui5_view_builder` the
[abap2UI5-linter](https://github.com/abap2UI5/linter) reconstructs
these views statically, including the parts built in the render hooks: a hook
that takes a builder handle (`io_table`, `io_op`, `io_container`, …) is
replayed against the handle it is passed. What it cannot follow is a view
assembled through a mechanism it has no way to resolve statically — a handle
stored in an instance attribute, or a hook called through a dynamic
dispatch. When a change makes the linter report *fewer* documents than the
class actually builds, that is the signal.

Four things learned the hard way with the floorplan base class:

- **The shared input controls are invisible to it.**
  `z2ui5_cl_rap_floorplan->render_field_input( )` lives in a class that is no
  app, so the edit-mode controls of the object page and the action dialog
  (DatePicker, ComboBox, Input with value help, ...) are not judged. Check a
  change there by hand against the UI5 API of the 1.77 floor.
- **A builder call inside a parameter** (`io_container = lo_card->ele( ... )`)
  makes it skip the whole document's render gate ("built in helper
  methods"). Put the handle in a variable first.
- **An expression binding built from runtime names** (`{= ${ ... } }` with a
  field name from the metadata) replays with the names empty and fails the
  render - which is right: it is what the browser gets when the name is
  empty. Bind fixed paths instead (the overview's chart rows have fixed
  columns for that reason).
- **An inherited `cs_event` is taken for the client's frontend actions**
  (`frontend-action-as-backend-event`) in a class that does not declare its
  own - the worklist reads its events into a local `ls_event` for that
  reason. A branch-exclusive attribute (`IF ... a( mode ) ELSE a( mode )`) is
  seen as set twice; compute the value into a variable, which it resolves.

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
  `TYPE REF TO z2ui5_cl_ui5_view_builder`. Changing that type again is a breaking
  change for every subclass — the migration off `z2ui5_cl_xml_view` already
  was one, and is recorded in the README.
- Do not change existing method signatures; additive optional parameters are
  fine.
- The `cs_event` constants and the constructor signatures
  (`cds_view_name = …`) are part of the same contract.
- New steps are welcome — extract them as new `PROTECTED` methods so they
  become overridable too, and list them in the README.
- The same holds for the `PROTECTED` methods of `z2ui5_cl_rap_floorplan`,
  which every floorplan inherits, and for the public types of
  `z2ui5_cl_rap_util` (`ty_s_field_info`, `ty_s_entity_info`, ...):
  components are appended, never removed or reordered.
- `z2ui5_if_rap_ext` is implemented downstream: a new method must be
  `DEFAULT IGNORE`, or every implementation stops compiling. It includes
  `if_serializable_object` because the extension travels through the draft.
- **A generic `REF TO data` whose target has an RTTI-created type must be a
  PUBLIC attribute.** The core detaches public data references before the
  draft is serialized and re-creates them from S-RTTI; a protected one is
  serialized as it is, which an anonymous type does not survive. That is
  why `mr_data`, `mr_value_lists`, `mr_card_rows`, `mr_child_rows` and the
  value help's `mr_result_table` are public, and why a protected reference
  (the value help's `mr_selected`) is created with the entity's named type.
  Only public attributes can be bound at all.

## abapGit conventions

- The repo is an abapGit project (`.abapgit.xml`, `STARTING_FOLDER=/src/`,
  `FOLDER_LOGIC=PREFIX`). Every `.clas.abap` needs its `.clas.xml` sidecar.
- `*.ddls.baseinfo` files are **abapGit serialization artifacts — never
  hand-edit** them; they change only when the CDS sources are re-serialized
  from a system.
- Line endings are **LF only** (a CRLF import once broke the `.asddls`
  round-trip — enforced by `.gitattributes`), UTF-8, final newline.
- `z2ui5_cl_rap_util.clas.xml` carries `WITH_UNIT_TESTS` - a class that gets
  a `.testclasses.abap` needs it in its sidecar too.
- Every artifact carries the `Z2UI5_<type>_RAP_` prefix — the same scheme the
  [samples](https://github.com/abap2UI5/samples) repo uses with its `SMP` token
  (`Z2UI5_CL_SMP_…`, `Z2UI5_T_SMP_…`). Here: `Z2UI5_CL_RAP_…` for classes,
  `Z2UI5_DD_RAP_…` for DDLS, `Z2UI5_IF_RAP_…` for interfaces. New objects follow it; nothing stays on the old
  `Z2UI5_CDS_` / `Z2UI5_CL_CDS_` names.
  Note that this is the *object* namespace only — the `cds_view_name`
  constructor parameter and the `CDS` wording in descriptions are part of the
  public contract / prose and are deliberately untouched.

## Related repositories

| Repository | Relation |
| --- | --- |
| [abap2UI5](https://github.com/abap2UI5/abap2UI5) | Core framework — consumed classes: `z2ui5_if_app`, `z2ui5_if_client`, `z2ui5_cl_ui5_view_builder`. Resolved as an abaplint dependency pinned to a release tag (`scripts/core-pin.mjs`); keep to API that release has |
| [samples](https://github.com/abap2UI5/samples) | Sample applications |
| `z2ui5_cl_fp_list_report` (core) | **Does not exist in core `main`** — added in core #2505 and removed again days later by an abapGit sync. Do not reference it as available; re-check before ever citing it again |
