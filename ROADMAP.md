# Roadmap

What the 2026-09 and the three 2026-10 rounds implemented, and what is still
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
3. **Reading a draft back**: resume a draft of the user's own with its data,
   and with it keep the draft when the user leaves the page (today leaving
   discards it, and a draft left by another app can only be discarded) -
   blocked the same way.
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
10. **`@ObjectModel.filter.transformedBy`** of a virtual element: its
    `IF_SADL_EXIT_FILTER_TRANSFORM` builds conditions with SADL condition
    objects (`IF_SADL_SIMPLE_COND_FACTORY`) that the abaplint API set does
    not have - a virtual element stays no filter field. Likewise a
    **fuzzy search** (`@Search.fuzzinessThreshold`, HANA only) and
    **parameters of a custom entity** (`get_parameters` answers none).

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

### 2026-10, third round

- **Qualified `@UI.identification`**: every entry is read with its
  qualifier and label; a `#IDENTIFICATION_REFERENCE` facet with a
  `targetQualifier` shows only its fields, the header only the unqualified
  ones.
- **Static and factory actions**: a static action (no `%KEY` in its derived
  type) runs without selected rows, with a `%cid`; after a factory action the
  object page of the created record opens, by the keys `MAPPED` returns.
- **Actions**: `#FOR_ACTION_GROUP` / `actionGroupId` as a menu button,
  criticality as the button type (Accept, Reject, Emphasized), sorted by
  position, at a section (qualified `@UI.identification`, `@UI.fieldGroup`
  `#FOR_ACTION`), on the child tables of the object page (their selected
  rows), and `invocationGrouping: #ISOLATED` - one request per row - next to
  the change set.
- **After an action** the object page reads its child tables again.
- **`@EndUserText.quickInfo`** as the tooltip of labels and column headers,
  **`@UI.headerInfo.imageUrl` / `typeImageUrl`** as the object page's avatar.
- **`@UI.selectionVariant` filters** with OR and parentheses.
- **`@UI.createHidden` / `updateHidden` / `deleteHidden`**: `true`, or a
  field of the record on the object page.
- **Custom entities** (`@ObjectModel.query.implementedBy`): read through
  the query provider (`z2ui5_cl_rap_query`, an own `IF_RAP_QUERY_REQUEST` /
  `_RESPONSE` / `_FILTER` / `_PAGING` / `_AGGREGATION`) - filter as SQL
  string and ranges, search, sort, paging, requested elements, count - in
  every floorplan, value help and card; aggregates computed from the rows; a
  failed read is an error message, not an empty list.
- **Virtual elements** (`@ObjectModel.virtualElementCalculatedBy`):
  calculated after every read (`IF_SADL_EXIT_CALC_ELEMENT_READ`, dynamic),
  left out of the SELECT list, the WHERE and the ORDER BY, no filter field;
  sortable through `@ObjectModel.sort.transformedBy`
  (`IF_SADL_EXIT_SORT_TRANSFORM`).
- **Search** over `STRING` fields and hidden `@Search.defaultSearchElement`
  fields; `@Search.fuzzinessThreshold` read, the search stays a `LIKE`.

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
  Activate - a refused activation keeps the draft and the edit mode),
  Cancel and Back discard, an existing own draft can be discarded.
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
