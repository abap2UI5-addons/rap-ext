# Roadmap

What the 2026-09 and the three 2026-10 rounds implemented, and what is still
open. Everything marked **done** passes the three offline gates (abaplint,
the transpiled unit tests, the abap2UI5-linter); **none of it has been
clicked through in an SAP system yet** - that is the first open item, and
[docs/system-test.md](docs/system-test.md) is the checklist for it.

## Open

1. **The system test** ([docs/system-test.md](docs/system-test.md)) - first,
   and its findings before anything below. The RAP write path, the draft
   handling, the derived type names (`\ASSOC=` or `\ASSOCIATION=...\TYPE=CREATE`
   for a create by association), the host variables in dynamic WHERE clauses, the
   DDL source read and the hand-written sidecar of `z2ui5_t_rap_var` were
   written from documentation.
2. **The three dynamic EML classes** (`z2ui5_cl_rap_eml_perm`, `_read`,
   `_key`) in a system: their syntax, the absolute names of the
   permission types (`\TYPE=PERMISSIONS_K` / `_Q` / `_R` are guesses, see
   `z2ui5_cl_rap_util=>get_permission_type_names`), the components of the
   permission result (`GLOBAL`, `INSTANCES`, `%ACTION`, `%FIELD`, `%ASSOC`).
   The features are written; whether they work is the system test's.
3. **The etag master field of the BDEF**: the optimistic check compares the
   local last-changed field, not the field the BDEF names as `etag master` -
   no table to read a BDEF source from is known here, and `GET PERMISSIONS`
   does not report it.
4. **Drafts that were never activated** do not appear in the list report (it
   reads the active entity with ABAP SQL); they are opened through a factory
   action or Edit only. And whose draft a row has is decided by the draft's
   `@Semantics.user.lastChangedBy` - the draft administrative data (in
   process by user) is not read.
5. **What the tree, the analytical list and the column layout cannot do
   yet** (the flexible column layout, the former item 5, is done - 2026-10,
   third round): the tree reads every node at once (up to `max_rows`), not
   the children of a node when it is expanded, applies no `start where` of
   the CDS hierarchy, takes one field pair of the parent association (a
   composite node key is not compared) and is a responsive table only;
   the analytical list sums an amount over every currency (no group per
   unit) and an `AVG` into an integer field is computed from the rows; the
   column layout keeps no column of its own in a bookmark (a restored host
   shows its list), offers no full-screen button of its own (the layout's
   arrows resize) and needs `z2ui5_cl_rap_fcl_client` extended when the
   pinned core's `z2ui5_if_client` grows.
6. **Microcharts** (`sap.suite.ui.microchart`) for the chart cards - the
   cards draw with `sap.m`, because the microchart library is SAPUI5 only and
   the view gate renders with OpenUI5.
7. **What the list's personalisation cannot do yet** (the qualified
   `@UI.lineItem` of a presentation variant, the former item 7, is done):
   a group header shows the group's value only - "Label: value" needs a
   group header factory, which an XML view cannot name; another user's
   public view cannot be a user's default (the default is a flag of the
   user's own row); the define conditions dialog offers every operator for
   every type; a text association is shown, not edited, and not searched.
8. German through a **translation of the text pool** instead of the built-in
   German texts (needs the I18N part of the sidecar, best exported from a
   system).
9. The **overview page and value help** in the transpiled unit run (the
   overview's test runs in a system only).
10. **`@ObjectModel.filter.transformedBy`** of a virtual element: its
    `IF_SADL_EXIT_FILTER_TRANSFORM` builds conditions with SADL condition
    objects (`IF_SADL_SIMPLE_COND_FACTORY`) that the abaplint API set does
    not have - a virtual element stays no filter field. Likewise the
    **parameters of a custom entity** (`get_parameters` answers none). The
    **fuzzy search** (`@Search.fuzzinessThreshold`, HANA only) is a hook
    since 2026-10, third round: `CONTAINS ... FUZZY` is no ABAP SQL, so
    an extension runs it through ADBC or an AMDP
    (`z2ui5_if_rap_ext~build_search_condition`,
    `z2ui5_cl_rap_util=>build_fuzzy_search`) - nothing is shipped that
    runs native SQL.
11. **XLSX export** next to the CSV export: no spreadsheet writer is part of
    every release - `CL_XLSX_DOCUMENT` is on-premise only and
    `XCO_CP_XLSX` is not in the API set abaplint checks against, so either
    would be a dynamic call no gate reads; the CSV (UTF-8 with BOM) opens in
    every spreadsheet. A decision first.
12. **What RAP answers for the newer dynamic paths** (docs/system-test.md,
    3b): the derived types of a default function (`\FUNCTION=` or
    `\ACTION=`, `IF_ABAP_BEHV=>OP-R-EXECUTE`, the `SUB_NAME` of a retrieval),
    how `%other` arrives in a dynamic `REPORTED`, and whether `GET
    PERMISSIONS` answers `field ( mandatory )` of an abstract BDEF - no
    other way to read it is known here (the BDEF source has no readable
    table, open item 3).

13. **What the object page's children cannot do yet** (2026-10, third
    round): an `@UI.lineItem` entry with an association path is read but is
    no column of the list report (it would read the children of every
    row); a cell of a child table has no value help and no per-instance
    field control of its own field (the row's update permission decides); a
    child table and the MultiInput read the draft's children through
    `READ ENTITIES BY` association, whose derived type names are unverified
    (docs/system-test.md, 4a); without draft the children are written after
    the record, each in its own commit, not in one LUW with it; the BDEF's
    `side effects` are not read (no table holds a BDEF source) - the fields
    are configured (`get_side_effect_fields`).

### How the dynamic EML statements were unblocked

`GET PERMISSIONS ... OPERATIONS`, `READ ENTITIES OPERATIONS` and
`CONVERT KEY` are needed in their dynamic form, because the entity is only
known at runtime, and abaplint parses only the static forms. A maintainer
decision of 2026-10 (third round) took the first way out: one small class
per statement (`z2ui5_cl_rap_eml_perm`, `_read`, `_key`), its `.abap` file
in `global.noIssues` of `abaplint.jsonc`, called dynamically from
`z2ui5_cl_rap_eml` (`CALL METHOD (class)=>(method)` in a `TRY`), so that a
system where one does not activate only loses its feature - at the price of
code no gate reads (docs/system-test.md, 1). The other way out - the
grammar contributed to abaplint, then the statements in `z2ui5_cl_rap_eml`
like the others - is still the better one; the classes go when it lands.

## Done

### 2026-10, third round

- **Tree** (`z2ui5_cl_rap_tree`): the nodes of a hierarchy - from
  `@Hierarchy.parentChild` (`recurse`, `recurseBy`, `siblingsOrder`),
  `@ObjectModel.hierarchy.association`, the CDS hierarchy of
  `@OData.hierarchy.recursiveHierarchy` (its DDL source parsed:
  `source`, `child to parent association`, `start where`,
  `siblings order by`) or a parent association of the entity to itself -
  in a responsive table, indented under their parents, expanded and
  collapsed by a roundtrip, read at once up to `max_rows`; Create child,
  Delete with a configurable delete mode (subtree, children moved up, leaf
  only - constructor, `z2ui5_if_rap_ext~adjust_hierarchy`,
  `get_delete_mode`); the object page by row press.
- **Analytical list** (`analytical = abap_true`): `@Aggregation.default`
  (`#SUM`, `#MIN`, `#MAX`, `#AVG`, `#COUNT_DISTINCT`) aggregated by
  `GROUP BY` in the database (from the rows for a custom entity, a virtual
  element or a refused aggregate - `aggregate_rows`, which learned
  `COUNT_DISTINCT`), a group header row with the subtotals per value of
  the group field ("Label: value" - the former limit of item 7 for this
  mode) and a total row.
- **Grid table** (`table_type = GRID`): a `sap.ui.table.Table` for long
  lists, no annotation needed - selection by check box, navigation column,
  inline actions, the toolbar in its extension.
- **Flexible column layout** (formerly open item 5, `z2ui5_cl_rap_fcl`):
  a host app with a `sap.f.FlexibleColumnLayout` - the list report, its
  object page, a child's object page side by side. The floorplans are not
  changed: the host calls them with a client of its own
  (`z2ui5_cl_rap_fcl_client`) that keeps their views, names the column in
  their events, opens an object page in the next column and closes a
  column on its back button; the views become one view. The
  `nav_app_call` path stays the default. The decision is described in the
  README ("Flexible Column Layout").
- **Fuzzy search** as a hook (see open item 10).

- **Object page, children**: an entry whose `value` is an association
  path (`'_Tags.TagId'`) is a `MultiInput` of the 1:n child's values -
  tokens in display and edit mode, a token typed or chosen in the child's
  value help creates a child by association, a deleted token deletes it
  (EML, in the draft at once, without draft on Save; feature control of
  the association and the child). **Child tables in edit mode**: inputs
  where the row may be changed (instance feature control, static field
  control, `@UI.updateHidden`), rows added and deleted, written into the
  draft or on Save, every write checked on the server.
- **Side effects**: in a draft a changed field (on `change`, not
  `liveChange`) is written into the draft, the draft, its field control
  and its children read back - which fields is
  `get_side_effect_fields` / `z2ui5_if_rap_ext~get_side_effect_fields`
  (default every field with draft, none without; the BDEF's
  `side effects` cannot be read).
- **Sections**: custom sections of an extension placed before or after a
  facet (`get_custom_sections`, `extend_view` with `section_id`), the
  header content spot, the section "Change Information" from the
  administrative `@Semantics` fields, a change documents section from the
  entity an extension names (`get_change_documents`).

- **Filter bar**: a control per type - a list for a boolean (Yes, No,
  all), fixed values and a dropdown value help, a date picker or a date
  range, a `MultiInput` with tokens for a value help with several values;
  **define conditions** (equal, not equal, between, greater, less, contains,
  starts with, ends with, empty - each including or excluding) in the
  filter syntax; the error state of a missing mandatory filter; **adapt
  filters** (any visible field), kept in the views. An excluding filter
  part is ANDed.
- **Table personalisation**: column order and width in the columns dialog
  (`@UI.lineItem.cssDefault.width` the default), grouping by
  `@UI.presentationVariant.groupBy` or the user's choice (ordered in the
  database, a group header per value), all kept in the views.
- **Views**: public views (`IS_PUBLIC` in `z2ui5_t_rap_var`), "apply
  automatically" (`AUTO_APPLY`) apart from the default; the start from
  `@UI.selectionPresentationVariant` - the presentation variant's sort,
  group and qualified `@UI.lineItem` (formerly open item 7, also for the
  overview's table card), the selection variant's `selectOptions` and
  filter as filter values; `initial_load` (auto, enabled, disabled).
- **Criticality**: the row highlight from the entity's `@UI.lineItem`,
  `criticalityRepresentation` (`#WITH_ICON` / `#WITHOUT_ICON`), 5 as
  Information and 0 as neutral, the criticality of `@UI.identification`
  and `@UI.fieldGroup` entries on the object page.
- **Display**: `#AS_FIELDGROUP` columns (`valueQualifier`), `hidden:
  #(Field)` per row (`@UI.lineItem`) and per record (field group,
  identification), `@Semantics.imageUrl` and `iconUrl`, the text of
  `sizeCategory #XS` dropdown entries, the text beside an input in edit
  mode, `@ObjectModel.text.association`, `@Consumption.hidden`, the
  semantic key bold and of HIGH importance, the importance of field group
  and identification entries.
- **Navigation**: `@Consumption.semanticObject` with
  `semanticObjectMapping` as a link; `semanticObjectBinding` of
  `#FOR_INTENT_BASED_NAVIGATION` with the selected rows' values (several
  as an array) and of `#WITH_INTENT_BASED_NAVIGATION`.
- **Value help from domain fixed values** where no value help is annotated
  (`GET_DDIC_FIXED_VALUES`, called dynamically).

- **Messages by severity**: success and information as a toast, a single
  message of the floorplan as a message box, everything else in a
  `sap.m.MessageView` dialog - each message with its type, its fields and
  its entity; a success is left out when there is an error; the fields keep
  their value state. The messages of `REPORTED` without an entity
  (`%other`) are collected too.
- **Action dialogs**: the default values of a BDEF `default function
  GetDefaultsFor<Action>` (executed for the first selected row, the record,
  or statically), mandatory parameters by `GET PERMISSIONS` on the abstract
  entity where RAP answers it.
- **Files** (`@Semantics.largeObject`, `@Semantics.mimeType`): download link,
  upload dialog with the core's upload control in the object page and the
  action dialog, MIME type and file name filled, size and type checked on
  the server; the list report keeps files on the server.
- **Inbound navigation**: `z2ui5_cl_rap_start` hands its parameters to the
  list report and the worklist as filter values (case-insensitive, unknown
  ones ignored, `z2ui5_if_rap_ext~map_inbound_parameter` maps them), and
  `mode=edit` opens the object page in edit mode.
- **Feature control** (`GET PERMISSIONS`, formerly open item 2): global,
  static and instance permissions - Create, Edit, Delete, create by
  association, actions (disabled buttons; per row in the list report, by
  the selected rows for the toolbar), the field control in edit mode
  (`field ( readonly )`, `readonly : update`, `mandatory`,
  `mandatory : create`, instance field control), keys not typed in on
  create when the business object numbers them; checked on the server for
  every update, delete and action; internal operations not offered where
  the permissions report them.
- **Reading a draft back** (formerly open item 3): an own draft opens to be
  edited further, Edit offers to resume a draft left by another app,
  leaving asks to keep or discard the draft, another user's draft shows
  "locked by"; the list report shows the editing status per row and
  filters by it (All, Own draft, Locked by another user, Unchanged); a
  record a factory action created as a draft opens.
- **Late numbering through `CONVERT KEY`** (formerly open item 4).
- **Optimistic check** before an update or delete without a draft, by the
  local last-changed field.

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
