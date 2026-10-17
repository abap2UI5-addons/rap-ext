# System test

What no offline gate can show: the three gates (abaplint, the transpiled unit
tests, the abap2UI5-linter) prove that the code parses, that the logic on
plain data is right and that every view renders - not that a system answers
the way the code expects. Everything below was written from documentation and
has not been clicked through yet. Run it once per release, on a system with
the /DMO/ flight reference scenario, and note in the PR what was and was not
verified.

Install with abapGit (the package, then the pinned abap2UI5 release), start
`z2ui5_cl_rap_test`.

## 1 · Install

- [ ] every object activates - in particular `z2ui5_cl_rap_eml` (dynamic
      EML), `z2ui5_cl_rap_query` (the query provider interfaces, see 9a),
      `z2ui5_cl_rap_variant` and the table `z2ui5_t_rap_var` (its
      sidecar was written by hand, after the core's exported `z2ui5_t_01`;
      the columns `IS_PUBLIC` and `AUTO_APPLY` were appended in 2026-10,
      third round - an existing table is adjusted, check SE14)
- [ ] the text pool of `z2ui5_cl_rap_floorplan` arrived (SE24 > Goto > Text
      Elements, 98 entries); an English logon shows its texts
- [ ] **unverified syntax**: `z2ui5_cl_rap_eml_perm` (`GET PERMISSIONS
      OPERATIONS ... FAILED ... REPORTED`, operand `ABP_BEHV_PERMISSIONS_TAB`),
      `z2ui5_cl_rap_eml_read` (`READ ENTITIES OPERATIONS ... FAILED ...
      REPORTED`, operand `ABP_BEHV_RETRIEVALS_TAB`) and `z2ui5_cl_rap_eml_key`
      (`COMMIT ENTITIES BEGIN RESPONSES FAILED ... REPORTED ...`, `CONVERT KEY
      OF (entity_name) FROM pid TO key`, `COMMIT ENTITIES END`) were written
      from the keyword documentation and are read by no gate - each activates
      (note the syntax error of one that does not, and correct it); a class
      that does not activate costs only its feature, every other object still
      activates (check that the floorplans run with one of them inactive)
- [ ] the absolute names of the permission types: which of
      `\BDEF=..\ENTITY=..\TYPE=PERMISSIONS_K` / `_I` / `_KEY`, `_Q` /
      `_REQUEST`, `_R` / `_RESULT` can be created (`CREATE DATA ... TYPE
      (name)` in the debugger) - correct `get_permission_type_names` by what
      the system answers; without them feature control is silently off
- [ ] a pull right after the install shows no diffs (if it does: commit what
      abapGit serialized, see the abap-check skill)

## 2 · Metadata

- [ ] `z2ui5_cl_rap_util=>read_raw_annotations( '/DMO/C_TRAVEL_PROCESSOR_M' )-with_metadata_extensions`
      is `abap_true`, and the list report shows the metadata extension's columns
- [ ] `read_entity( )-keys` and the data element labels arrive
- [ ] `z2ui5_cl_rap_util=>get_environment( )` answers `ON_PREMISE`, and
      `read_raw_annotations( ... )-reader` is `DDIC`
- [ ] the XCO reader on premise (if XCO_CP_CDS is there): after
      `set_annotation_reader( cs_anno_reader-xco )` the raw annotations of
      `/DMO/C_TRAVEL_PROCESSOR_M` are the same keys and values as those of
      the DDIC reader (compare both tables; note every difference), and
      `read_associations( )` finds the same associations
- [ ] `z2ui5_cl_rap_anno_xco` activates (it names the XCO API statically -
      on a release without it only this class stays inactive)
- [ ] `read_associations( '/DMO/C_TRAVEL_PROCESSOR_M' )` finds `_BOOKING` with
      its target and ON condition (the source is read from `DDDDLSRC` by name)

## 3 · RAP, managed (`/DMO/C_TRAVEL_PROCESSOR_M`)

- [ ] Create, Edit, Delete; an action with and one without a parameter
- [ ] a rejected save shows the business object's messages, and the field a
      message names is marked in edit mode (`%element`)
- [ ] the bookings table of a travel lists the travel's bookings (the ON
      condition, compared with typed host variables)
- [ ] a booking opens; Edit and Delete of the booking go through the BDEF of
      the travel (`\BDEF=<root>\ENTITY=<child>`)
- [ ] Create in the bookings table: a create by association - the derived type
      `\BDEF=...\ENTITY=<parent>\ASSOCIATION=_BOOKING\TYPE=CREATE` exists (else
      the button does not show at all), and the new booking belongs to the travel
- [ ] the actions offered are only the annotated ones; an event that names
      another is ignored

- [ ] a static action (`static action` in the BDEF, e.g. one added to the
      demo BO): the derived type `\ACTION=...\TYPE=IMPORTING` has no `%KEY`,
      the toolbar button runs it without a selected row, and `%cid` is
      accepted
- [ ] a factory action (`factory action copyTravel [1]` of the flight
      scenario, and a static factory one): the created record's object page
      opens with the keys `MAPPED` returned - for a draft business object the
      created instance may be a draft the page cannot read yet (ROADMAP 3);
      note what it shows
- [ ] an action with `invocationGrouping: #ISOLATED` on two rows, one of them
      refused: the other one is changed, the refusal's message is shown
- [ ] `#FOR_ACTION_GROUP` with `actionGroupId`: the menu button opens, its
      items run their actions; the annotation names (`id` or `actionGroupId`
      of the group entry) arrive as `GET_ANNOS` hands them over
- [ ] `criticality` of a `#FOR_ACTION` entry: a literal colors the button
      (Accept, Reject, Emphasized), a field on the object page by the
      record's value
- [ ] an action of a qualified `@UI.identification` and a `@UI.fieldGroup`
      `#FOR_ACTION` entry: the button sits above its section, not in the
      header
- [ ] a `@UI.lineItem` action of the bookings: the bookings table of a travel
      is selectable, the action runs on the selected bookings through the
      travel's BDEF, and both the travel and the table are read again
- [ ] after an action on the object page (with and without a parameter) the
      child tables show the changed rows

## 3a · Feature control (`GET PERMISSIONS`)

Needs a business object with `features : instance` / `global`, static
field control and an internal operation (the /DMO/ travel scenarios have
instance feature control on `acceptTravel` / `rejectTravel` and Edit).

- [ ] `z2ui5_cl_rap_eml=>get_permissions( )` answers (`answered`), the
      result has `GLOBAL` and `INSTANCES`, and `%ACTION`, `%FIELD`, `%ASSOC`,
      `%CREATE`, `%UPDATE`, `%DELETE` arrive with the values of
      `IF_ABAP_BEHV=>PERM-O` / `PERM-F` (a combined field value, e.g.
      `mandatory : create` with `readonly : update`, decodes right)
- [ ] list report: an inline action of a row whose feature control disables
      it is disabled; a toolbar action is disabled as soon as a selected row
      does not allow it (the view is built again on the selection change -
      check that the selection stays); an action sent anyway is refused
- [ ] object page: Edit and Delete hidden where the instance disables them,
      a disabled action shown disabled, a field read-only or mandatory by
      `field ( readonly )`, `readonly : update` (editable on create only),
      `mandatory : create` and instance field control; a key with managed or
      early numbering (and a UUID key) is not inputtable on create
- [ ] global feature control / authorization: Create hidden; an `internal
      create` / `internal action` is not offered - note what GET PERMISSIONS
      reports for an internal operation (if it is "enabled", A6 is open)
- [ ] a child table: Create hidden when the parent's `%assoc` disables it
- [ ] a change of a read-only field sent anyway is refused ("These fields
      cannot be changed")
- [ ] optimistic check (managed BO without draft, e.g.
      `/DMO/C_TRAVEL_PROCESSOR_M`): two sessions open the same record, the
      second save is refused with "changed meanwhile"; check that the field
      compared (`@Semantics.systemDateTime.localInstanceLastChangedAt`, else
      `.lastChangedAt`) is the BDEF's `etag master`

## 3b · Messages, action dialogs, files

- [ ] a save with an error on a field and a warning: the dialog lists both
      with their types and the field's label, the field is marked in edit
      mode; a save that only reports success shows a toast; a success next
      to an error is not shown
- [ ] a message of `%other` (a validation that reports without an
      instance, `APPEND VALUE #( %msg = ... ) TO reported-%other`): it is
      listed - note how the dynamic `REPORTED` carries it (an entry that is
      the message, or a table in the response row; `collect_messages`
      reads both)
- [ ] two messages of different entities (the travel and a booking): the
      view groups them by entity
- [ ] the Close button closes the message dialog (a frontend event,
      nothing reaches the server)
- [ ] an action with `default function GetDefaultsFor<Action>` in its BDEF:
      the dialog opens with the function's values - for an instance action
      of the selected row (and of the object page's record, also of its
      draft), for a static one without a row. Note which derived types exist
      (`\BDEF=..\ENTITY=..\FUNCTION=<name>\TYPE=IMPORTING` / `RESULT`, or
      `\ACTION=`), that `IF_ABAP_BEHV=>OP-R-EXECUTE` and the `SUB_NAME` of
      `ABP_BEHV_RETRIEVALS_TAB` exist, and that RAP names the function
      `GetDefaultsFor` + the action (else `get_default_function_name`)
- [ ] an abstract entity with an abstract BDEF and `field ( mandatory )`:
      does `GET PERMISSIONS` answer for it (the field is required in the
      dialog)? If not, the mandatory parameter is only checked by RAP - note
      it (ROADMAP 12)
- [ ] a `@Semantics.largeObject` field: Upload opens the dialog, a file is
      taken (MIME type and file name filled), Save writes it (also through a
      draft); the link downloads it with its name; a file over the limit and
      one of a type not in `acceptableMimeTypes` are refused; check the
      MIME type the browser hands over for a PDF and an image
- [ ] a list report of the entity: its rows carry no file content (the
      browser's JSON), the object page shows the file after a row press
- [ ] a file parameter of an action (a `@Semantics.largeObject` field in
      the abstract entity): upload in the dialog, the action receives it
- [ ] the size of a file the roundtrip carries (a data URI in JSON): a 5 MB
      file arrives - note the limit the ICF service or the core sets

## 4 · RAP, draft (`/DMO/C_TRAVEL_A_D`)

- [ ] Edit creates a draft (visible in the draft table), Save activates it,
      no draft is left behind
- [ ] Cancel discards the draft; Back while editing asks "keep or
      discard": Keep leaves the draft (the list shows "Draft"), Discard
      discards it
- [ ] a record with an own draft opens in edit mode with the draft's data
      (`READ ENTITIES OPERATIONS` with `%is_draft`), and Save activates it
- [ ] Edit on a record whose draft another app left: "Resume draft" continues
      it with its data, "Discard draft" edits anew
- [ ] another user's draft: the object page shows "Locked by <user>" (the
      draft's `@Semantics.user.lastChangedBy` - check that another user's
      draft can be read at all, and note the user shown), no Edit or Delete
- [ ] list report: the editing status column shows "Draft" / "Locked by
      ..." per row, the filter All / Own draft / Locked by another user /
      Unchanged selects the rows (applied to the rows read - the count is
      theirs); an entity with `HASDRAFTENTITY` / `DRAFTENTITYLASTCHANGEDBY`
      elements uses them instead
- [ ] a factory action that creates a draft (`copyTravel` of the draft
      scenario): the created record opens in edit mode from its draft
- [ ] a draft left by another app (the RAP Fiori app): Edit answers with the
      business object's message and offers Discard - which discards and edits
      anew
- [ ] a refused activation keeps the draft and the page in edit mode
- [ ] another user's draft: Edit is refused with the business object's message
- [ ] a change and a create of a booking edit and activate the root
- [ ] create of a travel: the draft is created and activated in one request

## 4a · Object page: 1:n children, child tables, side effects, sections

Needs a draft business object with a 1:n composition annotated by an
association path (e.g. a travel's bookings: `@UI.fieldGroup: [{ qualifier:
'General', value: '_Booking.BookingID' }]` on `_Booking` in a metadata
extension), a non-draft one (`/DMO/C_TRAVEL_PROCESSOR_M`) and an extension
for the custom sections and the change documents.

- [ ] **unverified names**: the derived types of a read by association
      (`\BDEF=..\ENTITY=<parent>\ASSOC=<assoc>\TYPE=READ_I` / `READ_R`,
      else `\ASSOCIATION=`) and `IF_ABAP_BEHV=>OP-R-READ_BA` - in edit mode
      of a draft the child tables and the tokens show the draft's children
      (`z2ui5_cl_rap_eml=>read_by_association`); when they do not, the page
      falls back to the active children and a child created in the draft is
      missing until Save - correct the type names by what the system answers
- [ ] the entry with the association path shows a MultiInput with a token
      per child (display: not editable), the element's own field group
      entries are not affected
- [ ] edit mode of a draft: a value typed + Enter creates the child in the
      draft (`MODIFY ... CREATE BY \assoc` with `%is_draft`, no Edit/Activate
      of the root); its value help adds the value chosen; deleting a token
      deletes the child in the draft; Save activates both, Cancel discards
      them
- [ ] the same without draft: tokens wait for Save, then each child is
      created and deleted (its own commit after the record); Cancel forgets
      them
- [ ] a child the feature control does not allow (`association _X { create
      ( features : instance ) }` disabled, a child that may not be deleted)
      offers no new token / no delete, and an event sent anyway is refused
- [ ] child tables in edit mode: inputs in the cells the row may change
      (instance feature control of the child, `@UI.updateHidden`, static
      `field ( readonly )`), keys only in a new row, a delete button per row
      (disabled where the instance may not be deleted), Create adds a row;
      draft: written into the draft at once (add, delete, a changed cell),
      without draft: written on Save - a refused child keeps edit mode with
      its message, the record itself is saved
- [ ] side effects: in a draft a changed field (on change, not per keystroke)
      is written into the draft, a determination's result shows in the other
      fields and the child tables; the field control after it is the
      draft's; an extension's `get_side_effect_fields` restricts it
      (`STATUS` only - other fields wait for Save) or turns it off (empty)
- [ ] a custom section of `get_custom_sections` appears before / after the
      facet it names, at the end without an anchor; its content is what
      `extend_view` adds at `CUSTOM_SECTION` with its `section_id`; the
      `HEADER_CONTENT` spot adds controls behind the header facets
- [ ] "Change Information": the `@Semantics.user.createdBy`,
      `.systemDateTime.createdAt`, `.user.lastChangedBy`, `.lastChangedAt`
      fields (also `@UI.hidden` ones), time stamps in the user's format and
      time zone; not shown on create, nor when one of them is in a field
      group
- [ ] a change documents entity named by `get_change_documents`: a
      read-only table of its rows of the record (the record's keys, or the
      filter given), no navigation, no edit

## 5 · Keys and numbering

- [ ] a business object with a RAW (UUID) key: a row opens, the record is read
      again after a save (how the core's JSON carries a RAW decides the value
      `create_host` receives - hex digits are expected)
- [ ] late numbering: after a create the page shows the new record by the
      key `CONVERT KEY` returned (`z2ui5_cl_rap_eml_key`, between `COMMIT
      ENTITIES BEGIN` and `END`, from the `%pid` of `MAPPED`); with that class
      inactive, by `@Semantics.user.createdBy` and `.systemDateTime.createdAt`,
      and back to the list otherwise
- [ ] a create by association: `\ASSOC=` (documented) or `\ASSOCIATION=` -
      note which absolute name the system knows

## 6 · Database tables

- [ ] a list report on a table offers no Create, Edit or Delete
- [ ] with an extension that allows the writes (`adjust_capabilities`): a user
      without `S_TABU_NAM` (activity 02) for the table is refused
- [ ] two sessions change the same row: the second save is refused ("changed
      meanwhile"), and a row locked in SM12 is refused as locked

## 7 · List report, worklist

- [ ] a mandatory filter (`@Consumption.filter.mandatory`): no rows until it
      has a value, Go without it warns
- [ ] a `#SINGLE` filter's value help selects one value
- [ ] sorting, "more", the worklist tabs of a `@UI.selectionVariant`
- [ ] a `#WITH_URL` column opens the URL, a `#WITH_NAVIGATION_PATH` column the
      associated record's object page
- [ ] in the launchpad: `#WITH_INTENT_BASED_NAVIGATION` and
      `#FOR_INTENT_BASED_NAVIGATION` navigate; outside it the user is told so
- [ ] views: save one, make it the default, restart the app (it applies),
      switch to Standard, delete it
- [ ] the columns dialog hides and shows columns; the export downloads the
      visible columns of every matching row, and Excel opens it with umlauts

- [ ] a `@UI.selectionVariant` with `OR` and parentheses selects the same
      rows as the condition written out in SQL
- [ ] the filter bar: a boolean filter is a list (Yes, No, all - No finds
      the initial value), a date one a date picker (`#SINGLE`) or a date
      range (the range arrives as `2024-01-01 .. 2024-01-31` - check how
      `DateRangeSelection` writes its value with `displayFormat
      yyyy-MM-dd` and the delimiter `..` on the release), a value help
      field a MultiInput: the value help adds tokens, Enter turns the typed
      text into a token, a token's delete removes it (the `Token.delete`
      event and its `${KEY}` argument in a nested binding)
- [ ] define conditions: every operator, include and exclude, between
      with two values, empty; OK writes the filter, the dialog opens again
      with it; excluding and including together select `( a OR b ) AND NOT
      c`
- [ ] Go without a mandatory filter marks it red (valueState), a value
      clears it
- [ ] adapt filters: add a field (also a boolean, a date, one with fixed
      values), remove it; save a view with it and open the view again
- [ ] the columns dialog: hide, move up and down, a width (`12`, `8rem`,
      `20%`; `abc` is ignored), group by a field: the rows come grouped
      with a header per value; a view keeps it; `cssDefault.width` is the
      default width
- [ ] `@UI.presentationVariant.groupBy` groups at the start; a
      `@UI.selectionPresentationVariant` starts with its presentation
      variant (sort, group, a qualified `@UI.lineItem` from its
      `visualizations`) and its selection variant's values in the filter
      bar (`selectOptions` as `GET_ANNOS` hands them over -
      `SELECTOPTIONS$1$.RANGES$1$.LOW`; an OR in `filter` restricts without
      a filter value)
- [ ] views: a public view of user A is listed for user B as "name (A)",
      B cannot delete it and saves changes as a view of their own; a view
      without "apply automatically" sets its filters and waits for Go (the
      table says so); `initial_load = DISABLED` starts without rows,
      `ENABLED` always reads
- [ ] criticality: the entity's `@UI.lineItem.criticality` highlights the
      rows (child tables too), a criticality column shows its icon,
      `#WITHOUT_ICON` none, 5 is blue (Information); check
      `sap-icon://sys-enter-2`, `error`, `alert`, `message-information`
      on the release
- [ ] an `#AS_FIELDGROUP` column shows its group's fields; `hidden:
      #(Field)` empties the cell of a row whose field is true; an
      `iconUrl` column, an `@Semantics.imageUrl` column (Avatar); the
      semantic key is bold, also in the popin of a narrow screen
- [ ] `@ObjectModel.text.association` (e.g. a status with a text view
      `_StatusText`): the list shows the text in the logon language (the
      target's `@Semantics.text` and `@Semantics.language` fields - check
      the DDL association's ON condition was read), the object page too
- [ ] `@Consumption.hidden`: no column, no filter, not in adapt filters
- [ ] in the launchpad: a `@Consumption.semanticObject` link (list and
      object page) passes the value under the name of
      `semanticObjectMapping`; a `#FOR_INTENT_BASED_NAVIGATION` with
      `semanticObjectBinding` takes the selected rows' values (several
      rows: an array - check the target app reads it)
- [ ] a field without a value help whose domain has fixed values: a
      dropdown in edit mode and the action dialog, a list in the filter
      bar (`CL_ABAP_ELEMDESCR->GET_DDIC_FIXED_VALUES` with `P_LANGU` and
      `P_FIXED_VALUES` of type `DDFIXVALUES` - check the signature)
- [ ] `@UI.createHidden: true` hides Create; `@UI.updateHidden` /
      `.deleteHidden` with a field (`#(...)`) hide Edit / Delete per record -
      check how `GET_ANNOS` hands a path over (`#(Field)`, `'Field'`)

## 8 · Value help

- [ ] the selection (single and multi) comes back into the dialog, the filter
      bar and the object page
- [ ] a value help entity with `@UI.selectionField` shows its filter bar; Go
      and confirm work
- [ ] typing into an input with a value help suggests values; picking one
      fills the input

## 8a · Object page display

- [ ] a `#IDENTIFICATION_REFERENCE` facet with `targetQualifier` shows only
      that qualifier's fields (with their labels), the header only the
      unqualified ones
- [ ] `@UI.headerInfo.imageUrl`: the avatar shows the record's image, and
      `typeImageUrl` (`sap-icon://...` or a URL) when it has none
- [ ] `@EndUserText.quickInfo`: the tooltip of the label in a form, in the
      action dialog and of a column header
- [ ] a `@UI.fieldGroup` / `@UI.identification` entry with `criticality`
      (a field and a literal) shows an ObjectStatus with its icon (not
      with `#WITHOUT_ICON`); `importance: #LOW` is gone on a phone and a
      tablet, `#MEDIUM` on a phone (the classes `sapUiHideOnPhone` /
      `sapUiHideOnTablet`); `hidden: #(Field)` hides the entry for a
      record whose field is true
- [ ] a dropdown (`sizeCategory #XS`) lists the text with the key beside
      it; an input of a field with `@ObjectModel.text.element` shows the
      text beside it (`description`) in edit mode

## 9 · Overview page

- [ ] table, KPI and chart cards; a `#DONUT` chart shows shares, a `#LINE`
      chart a trend
- [ ] a card with `presentation_variant` shows that variant's chart or its
      sorted, sized table

## 9a · Custom entities, virtual elements, search

Needs a custom entity with a query provider (e.g. one written for the test
on the flight tables, `@ObjectModel.query.implementedBy: 'ABAP:ZCL_...'`)
and a projection with a virtual element
(`@ObjectModel.virtualElementCalculatedBy`).

- [ ] `z2ui5_cl_rap_query` activates. It implements every method of the
      `IF_RAP_QUERY_*` interfaces abaplint knows (the steampunk-2305 API set):
      on a release without one of them (`IF_RAP_QUERY_FILTER~GET_AS_TREE`,
      `IF_RAP_QUERY_REQUEST~GET_ENTITY_ID` and
      `CX_RAP_QUERY_FILTER_NO_RANGE=>NOT_EXPRESSABLE_AS_RANGE` are the
      likely candidates) the class does not activate - note which, and only
      the custom entities are affected; every other read stays ABAP SQL
- [ ] the list report of the custom entity shows its rows, the count, "more"
      (the provider is asked for rows and, separately, for the count)
- [ ] a filter bar value arrives in `get_as_ranges` (EQ, CP for `*`, BT for
      `a..z`, E for `!`) and in `get_as_sql_string`; a provider that asks for
      the ranges of an OR over two fields gets `CX_RAP_QUERY_FILTER_NO_RANGE`
- [ ] the search arrives in `get_search_expression`, not in the filter
- [ ] sorting arrives in `get_sort_elements`, the page size in `get_paging`
- [ ] the object page of a custom entity opens by key (the key arrives as a
      literal and as an EQ range), its child tables and a value help on a
      custom entity read through the provider
- [ ] a worklist with a `segment_field`, a KPI and a chart card on a custom
      entity: the counts and sums are the rows' (at most 5000 read)
- [ ] a provider that raises: the list shows the load error with the
      exception's text, not an empty list
- [ ] a virtual element: its column shows the calculated value (the calc
      class is called with the table of the entity in both `it_original_data`
      and `ct_calculated_data`); it is no filter field and is not searched;
      the list sorts by it only with `@ObjectModel.sort.transformedBy`, by the
      elements `MAP_ELEMENT` returns
- [ ] a virtual element is selected out (`SELECT` with a field list) - check
      that a projection with one still reads, and that a calc class that
      raises leaves the column empty and the rows shown
- [ ] the search finds a value in a `STRING` field (`UPPER( ) LIKE` on a
      string column - check it is allowed on the release) and in a
      `@UI.hidden` `@Search.defaultSearchElement` field

## 10 · Deep links

- [ ] `?app_start=z2ui5_cl_rap_test_start&floorplan=OBJECT_PAGE&entity=I_COUNTRY&Country=DE`
      opens Germany, and `entity=I_LANGUAGE` is refused
- [ ] `...&floorplan=LIST_REPORT&entity=/DMO/C_TRAVEL_PROCESSOR_M&agencyid=070001`
      opens the list filtered by the agency (`=070001` in the filter);
      `&unknown=1` is ignored; a launchpad tile's startup parameters arrive
      the same way (`t_comp_params`)
- [ ] `...&entity=/DMO/C_TRAVEL_A_D&TravelUUID=...&mode=edit` opens the
      record in edit mode in a draft; another user's draft opens it in
      display mode
- [ ] the object page's link button copies a link that opens the record again
      (the app state link without `get_start_app`, the start app's with it)

## 11 · Tree, analytical list, grid table, column layout (2026-10, third round)

Needs an entity with a hierarchy - e.g. a view with `@Hierarchy.parentChild`
or `@OData.hierarchy.recursiveHierarchy` and its `define hierarchy` - and
one with `@Aggregation.default` fields.

- [ ] `z2ui5_cl_rap_util=>read_hierarchy( )` of the entity names the node
      and the parent field: from `@Hierarchy.parentChild` (note the keys
      `GET_ANNOS` hands over for `recurse.parent`, `recurseBy`,
      `siblingsOrder` - the reading assumes `HIERARCHY.PARENTCHILD$1$...`),
      from the CDS hierarchy's DDL source (`DDDDLSRC` holds a `define
      hierarchy` like a view's source?) and from a parent association
- [ ] `z2ui5_cl_rap_tree`: the nodes are indented under their parents, the
      expand button opens and closes a node without a read (the
      `ColumnListItem`'s `visible` bound to `ZZROW_VISIBLE` hides the
      rows; the label's `width` bound to the indent), Expand all and
      Collapse all work, a node whose parent is filtered away is a root
- [ ] Create child opens the object page with the parent field filled; the
      new node appears under its parent after the save
- [ ] Delete with each delete mode on a RAP BO and on a table whose writes
      are allowed: `SUBTREE` deletes the descendants first (check a
      composition or a foreign key that refuses the order), `MOVE_UP`
      updates the children's parent field and deletes the node, `LEAF`
      refuses a node with children; a refused write stops and its message
      is shown
- [ ] analytical list report (`analytical = abap_true`, a group field
      chosen): the dynamic `SELECT ... GROUP BY` with `SUM( X ) AS X`,
      `COUNT( DISTINCT Y ) AS Y`, `AVG( Z ) AS Z` runs (`INTO CORRESPONDING
      FIELDS` of a table of the entity) - note which aggregate the release
      refuses for which type (an `AVG` into an integer, a `SUM` of a
      `CURR` field) and that the fallback from the rows then shows the
      value; a group header row shows "Label: value" with the subtotals, the
      total row the totals of every matching row (not only the loaded ones)
- [ ] group and total rows: not navigable (`type` Inactive), an action or
      an intent with one of them selected ignores it
- [ ] the analytical list on a custom entity: the aggregates are computed
      from at most 5000 rows
- [ ] grid table (`table_type = GRID`): `sap.ui.table` loads (the
      `xmlns:table` of the view), the check box selects a row for the
      toolbar actions (the toolbar follows the selection), the navigation
      column opens the object page, the "More" button and `noData` work, the
      columns keep their widths
- [ ] `z2ui5_cl_rap_fcl` with `/DMO/C_TRAVEL_A_D` (demo app button): the
      list in the first column, a row opens the object page in the second
      (`TwoColumnsMidExpanded`), a booking row the third; every event
      reaches its column (Edit, Save, the filter bar's Go, a value help in
      the first and in the second column, an action dialog)
- [ ] the bindings of the columns resolve through the host's public
      attributes (`MO_BEGIN->MR_DATA`, `MO_MID->...`) - typed `REF TO
      z2ui5_if_app`; check that the core dissolves them (else the columns
      are empty)
- [ ] the object page's back button closes its column, and after a save
      the list in the first column is read again; a new row press replaces
      the second column and closes the third
- [ ] the draft: reload the browser on an open object page - the host is
      restored with its columns (or note what is lost)
- [ ] a fuzzy search: an extension implementing
      `z2ui5_if_rap_ext~build_search_condition` with
      `z2ui5_cl_rap_util=>build_fuzzy_search` through `CL_SQL_STATEMENT` on
      HANA - the native `CONTAINS( ( "F" ), 'text', FUZZY( 0.8 ) )` runs
      against the entity's SQL view or table and its keys filter the list

## 12 · ABAP Cloud (2026-10, third round)

In an SAP BTP ABAP environment (or S/4HANA Cloud with developer
extensibility), with the abap2UI5 core and this repository pulled by
abapGit and a RAP business object with UI annotations in metadata
extensions (e.g. the flight reference scenario).

- [ ] every class activates under ABAP for Cloud Development - note the
      syntax warnings (the system fields `sy-uname`, `sy-datum`,
      `sy-zonlo`) and every error
- [ ] `z2ui5_cl_rap_util=>get_environment( )` answers `CLOUD`
      (`CL_DD_DDL_ANNOTATION_SERVICE` unknown to RTTI, or
      `CX_SY_RTTI_TYPE_NOT_RELEASED`), `read_raw_annotations( ... )-reader`
      is `XCO`
- [ ] the keys: `UI.LINEITEM$1$.POSITION` / `10`, `UI.HEADERINFO.TYPENAME`
      / `'Travel'`, `UI.LINEITEM$2$.TYPE` / `#FOR_ACTION` - i.e. the
      visitor reports `visit_name` before each member of a record and the
      property of an annotation is its full name (`UI.lineItem`) or its
      first part (`UI`); either gives the same keys, anything else does not
- [ ] metadata extensions: an annotation that is only in the extension
      arrives (`with_metadata_extensions` true); one in the entity and the
      extension comes from the extension; a whole `@UI.lineItem` of the
      extension replaces the entity's
- [ ] two extensions of different layers (CORE and CUSTOMER) on one entity:
      the CUSTOMER value wins - XCO's merge, note if not
- [ ] propagation: a projection view without own `@EndUserText.label` on a
      field shows the base view's label; with
      `@Metadata.ignorePropagatedAnnotations: true` it does not
- [ ] keys (`read_entity( )-keys`) and the data element labels arrive
      through `ddic_fields`
- [ ] associations: `read_associations( )` of the projection finds its
      redirected compositions with the child's ON condition (the child's
      association to parent as XCO prints it), the object page lists the
      children
- [ ] a field with a domain with fixed values gets the dropdown
- [ ] list report, object page (display, edit through RAP, actions,
      draft), value help, action dialog, overview page, worklist, tree (with
      `@Hierarchy.parentChild`), column layout: as on premise
- [ ] a database table: read-only, no Edit, `write_table_row` answers
      "read-only"
- [ ] the texts of the text pool arrive (English and the built-in German)
