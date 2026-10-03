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
      EML), `z2ui5_cl_rap_variant` and the table `z2ui5_t_rap_var` (its
      sidecar was written by hand, after the core's exported `z2ui5_t_01`)
- [ ] the text pool of `z2ui5_cl_rap_floorplan` arrived (SE24 > Goto > Text
      Elements, 43 entries); an English logon shows its texts
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

## 4 · RAP, draft (`/DMO/C_TRAVEL_A_D`)

- [ ] Edit creates a draft (visible in the draft table), Save activates it,
      no draft is left behind
- [ ] Cancel discards the draft
- [ ] Back while editing keeps the draft with the changes; Edit again answers
      with the business object's message and offers Discard - which discards
      and edits anew
- [ ] a refused activation keeps the draft and the page in edit mode
- [ ] another user's draft: Edit is refused with the business object's message
- [ ] a change and a create of a booking edit and activate the root
- [ ] create of a travel: the draft is created and activated in one request

## 5 · Keys and numbering

- [ ] a business object with a RAW (UUID) key: a row opens, the record is read
      again after a save (how the core's JSON carries a RAW decides the value
      `create_host` receives - hex digits are expected)
- [ ] late numbering: after a create the page shows the new record when the
      entity has `@Semantics.user.createdBy` and `.systemDateTime.createdAt`,
      and returns to the list otherwise

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

## 8 · Value help

- [ ] the selection (single and multi) comes back into the dialog, the filter
      bar and the object page
- [ ] a value help entity with `@UI.selectionField` shows its filter bar; Go
      and confirm work
- [ ] typing into an input with a value help suggests values; picking one
      fills the input

## 9 · Overview page

- [ ] table, KPI and chart cards; a `#DONUT` chart shows shares, a `#LINE`
      chart a trend
- [ ] a card with `presentation_variant` shows that variant's chart or its
      sorted, sized table

## 10 · Deep links

- [ ] `?app_start=z2ui5_cl_rap_test_start&floorplan=OBJECT_PAGE&entity=I_COUNTRY&Country=DE`
      opens Germany, and `entity=I_LANGUAGE` is refused
- [ ] the object page's link button copies a link that opens the record again
      (the app state link without `get_start_app`, the start app's with it)
