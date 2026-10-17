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
      Elements, 86 entries); an English logon shows its texts
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
