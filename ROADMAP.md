# Roadmap

What the 2026-09 and the two 2026-10 rounds implemented, and what is still
open. Everything marked **done** passes the three offline gates (abaplint,
the transpiled unit tests, the abap2UI5-linter); **none of it has been
clicked through in an SAP system yet** - that is the first open item, and
[docs/system-test.md](docs/system-test.md) is the checklist for it.

## Open

1. **The system test** ([docs/system-test.md](docs/system-test.md)) - first,
   and its findings before anything below. The RAP write path, the draft
   handling, the derived type names (`\ASSOCIATION=...\TYPE=CREATE` for a
   create by association), the host variables in dynamic WHERE clauses, the
   DDL source read and the hand-written sidecar of `z2ui5_t_rap_var` were
   written from documentation.
2. **Feature control** (`GET PERMISSIONS`: actions disabled and fields
   read-only per instance) - blocked by the tooling, see below.
3. **Reading a draft back**: resume a draft of the user's own with its data
   (today the user can discard it and edit anew) - blocked the same way.
4. **Late numbering through `CONVERT KEY`** - blocked the same way. A record
   with `@Semantics.user.createdBy` and `.systemDateTime.createdAt` is found
   again without it (done); one without them still returns to the list.
5. **Flexible column layout** (list and object page side by side) - not
   started: the floorplans are apps of their own, called with
   `nav_app_call`; side by side the object page would have to render into a
   nested view of the list report. A design decision first.
6. **Microcharts** (`sap.suite.ui.microchart`) for the chart cards - the
   cards draw with `sap.m`, because the microchart library is SAPUI5 only and
   the view gate renders with OpenUI5.
7. A **qualified `@UI.lineItem`** for the table card of a presentation
   variant (it shows the unqualified columns today).
8. German through a **translation of the text pool** instead of the built-in
   German texts (needs the I18N part of the sidecar, best exported from a
   system).
9. The **overview page and value help** in the transpiled unit run (the
   overview's test runs in a system only).

### Why 2-4 are blocked

They need EML in its dynamic form - `GET PERMISSIONS ... OPERATIONS`,
`READ ENTITIES OPERATIONS`, `CONVERT KEY` - because the entity is only known
at runtime. abaplint (2.120.65, the newest release on 2026-10-03) parses only
the static forms, so the statements fail the `parser_error` gate, and no
offline tool checks their exact syntax. The ways out, each a maintainer
decision:

- a small class per statement, its `.abap` file in `global.noIssues` of
  `abaplint.jsonc`, called dynamically (`CALL METHOD (class)=>(method)` in a
  `TRY`) so that a system where it does not activate only loses the feature -
  at the price of code no gate reads and an activation error on the pull of
  such a system;
- the grammar contributed to abaplint, then the statements in
  `z2ui5_cl_rap_eml` like the others.

## Done

### 2026-10, second round

- **Database tables read-only by default**: their writes are switched on per
  entity (`z2ui5_if_rap_ext~adjust_capabilities`), and then checked against
  `S_TABU_NAM`, locked (`ENQUEUE_E_TABLE`) and refused when the row changed
  meanwhile. Every write and action is checked on the server, and only
  annotated actions run.
- **Child entities**: written through the BDEF of their root
  (`ty_s_rap_context`); create by association from a composition's table; a
  change of a child of a draft business object edits and activates the root.
- **Associations from the DDL source** (`read_associations`, unit-tested
  parser): the target of a `#LINEITEM_REFERENCE` facet and the ON condition
  of its rows without `resolve_association`.
- **Draft editing across roundtrips**: Edit, Save (into the draft, then
  Activate), Cancel (Discard), Back keeps the draft, an existing own draft
  can be discarded.
- **Keys as typed host variables** (RAW/UUID keys), late numbering by the
  administrative fields, the fields of RAP messages marked in edit mode.
- **`@Consumption.filter`** (mandatory, single value, hidden) and the link
  types of **`@UI.lineItem`** (`#WITH_URL`, `#WITH_NAVIGATION_PATH`, the
  intent-based navigations of the launchpad).
- **Value help**: a filter bar of the value help entity's selection fields;
  suggestions while typing.
- **Deep links**: `z2ui5_cl_rap_start` opens floorplans from a URL (an
  allow-list per subclass), the object page copies a link to its record.
- **Views per user** (`z2ui5_cl_rap_variant`, table `z2ui5_t_rap_var`), a
  columns dialog, the **CSV export**.
- **Overview**: shares (`#DONUT`, `#PIE`) and trends (`#LINE`, `#AREA`) next
  to the bars, cards from `@UI.presentationVariant`.
- **Text pool** for the English texts (translatable in SE63); the list report
  and object page **tested transpiled** against the core's public API.

### 2026-10, first round

- drafts written (Edit, change, Activate in one request), sorting and paging
  in the database, `@UI.selectionVariant` tabs, `@UI.presentationVariant`
  sort, `#DATAPOINT_REFERENCE` header facets, `@UI.textArrangement`, a titled
  group per `@UI.fieldGroup` in the action dialog, the KPI card colored by
  `criticalityCalculation`, `extend_view`, German texts

### 2026-09

- core pinned to its release tag (`bump-core.yml`, the weekly canary),
  linter bumped by hand, unit tests transpiled in CI
- value help: the selection comes back, search in the database,
  multi-select, `additionalBinding`, one value help for every floorplan,
  dropdowns for `sizeCategory #XS`
- action dialog: mandatory fields, date/time formats, the parameter dialog
  of RAP actions
- object page: facets (`#COLLECTION`, `#FIELDGROUP_REFERENCE`,
  `#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE`), Edit/Delete only where
  allowed, value helps in edit mode, open by key
- RAP write path: capabilities from the BDEF derived types, dynamic EML,
  actions with parameters, REPORTED/FAILED messages
- worklist as a subclass of the list report; overview page with `sap.f`
  cards; the extension interface and the shared floorplan superclass
