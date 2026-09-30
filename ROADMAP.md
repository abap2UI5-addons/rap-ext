# Roadmap

What the 2026-09 round implemented, and what is still open. Everything marked
**done** passes the three offline gates (abaplint, the transpiled unit tests,
the abap2UI5-linter); none of it has been clicked through in an SAP system yet
— that is the first open item.

## 0 · Verify in a system (open, first)

Install via abapGit on a system with the /DMO/ flight reference scenario and
click through `z2ui5_cl_rap_test`. In this order, because these were written
without a system:

1. `GET_ANNOS` answers (`z2ui5_cl_rap_util=>read_raw_annotations( )-with_metadata_extensions`
   is `abap_true`) and a RAP projection shows its metadata-extension columns
2. DDIC keys and data element texts arrive (`read_entity( )-keys`)
3. `/DMO/C_TRAVEL_PROCESSOR_M`: Create, Edit, Delete, an action with and one
   without parameter - messages of a rejected save
4. the value help returns its selection (single and multi) into the dialog,
   the filter bar and the object page
5. a `#LINEITEM_REFERENCE` facet with `resolve_association`

## 1 · Hygiene — done

- core pinned to its release tag, `bump-core.yml`, the weekly canary against `main`
- linter 0.8.5, `bump-linter.yml`
- unit tests transpiled in CI (`npm run unit`)

## 2 · Value help — done

- the selection comes back (it never did: the confirm read an argument that was not sent)
- search in the database, multi-select, `additionalBinding` with usage FILTER and RESULT
- one value help for every floorplan: filter bar, object page (edit), action dialog
- dropdown for `sizeCategory #XS`, bound to a public attribute

Open: a value help with its own filter fields (`@Consumption.valueHelpDefinition`
with a view that has selection fields), typeahead (suggestions while typing).

## 3 · Popup / action dialog — done

- mandatory fields checked before confirm, date/time value formats
- the parameter dialog of RAP actions

Open: `@UI.fieldGroup` layout inside the dialog for large parameter entities.

## 4 · Detail page (object page) — done

- facets: `#COLLECTION` with subsections, `#FIELDGROUP_REFERENCE`,
  `#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE` (child table, row → child page)
- Edit/Delete only where allowed, keys read-only on change, required fields,
  value helps in edit mode, reload after save, open by key

Open:
- the target entity of an association is not read from the system — it comes
  from `resolve_association` (extension or subclass); find it automatically
- `#DATAPOINT_REFERENCE` header facets, `@UI.textArrangement`
- a deep link / bookmark (the page can be opened by key — the URL part is missing)

## 5 · RAP write path — done (root entities, non-draft)

- capabilities from the BDEF derived types, dynamic EML create/update/delete,
  actions (toolbar, inline, header) with parameters, REPORTED/FAILED messages

Open:
- **draft** (EDIT / ACTIVATE / DISCARD, `%is_draft`) — a draft-enabled BO is written as active instances today
- child entities (create by association, update of items)
- the key a BO assigns on create (`MAPPED`) — the page cannot reload such a record yet
- feature control (`GET PERMISSIONS`: disabled actions, read-only fields per instance)

## 6 · Worklist — done

- a subclass of the list report: search, segments (`segment_field`), actions, navigation

Open: segments from `@UI.selectionVariant` / `@UI.presentationVariant` instead of a parameter.

## 7 · Overview page — done

- `sap.f` cards, aggregated KPI (SUM/AVG/MIN/MAX/COUNT), chart card from `@UI.chart`, navigation

Open: more chart types (the bars are one type for all), `@UI.dataPoint.criticality`
thresholds on KPI cards, cards from `@UI.presentationVariant`.

## 8 · Extension points — done

- `z2ui5_if_rap_ext` (`set_extension( )`): metadata, WHERE, rows, save, events, texts, associations
- `z2ui5_cl_rap_floorplan`: shared protected steps for every floorplan

Open: a hook to add content to a generated view without redefining the render
step (e.g. an extra toolbar button).

## Cross-cutting — open

- server-side sorting and paging (the tables sort and grow on the loaded rows)
- i18n of the built-in texts (the keys exist: `cs_text`; a text pool/OTR default is missing)
- unit tests for more than `z2ui5_cl_rap_util` (the floorplans need the core in the transpiled run)
