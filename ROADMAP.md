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
6. `/DMO/C_TRAVEL_A_D` (draft): a change and a create go through Edit/Activate and
   leave no draft behind; a change while another user holds a draft is refused with
   the business object's message
7. sorting and "more" in the list report, the worklist tabs of a `@UI.selectionVariant`

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

- 2026-10: a titled group per `@UI.fieldGroup`

## 4 · Detail page (object page) — done

- facets: `#COLLECTION` with subsections, `#FIELDGROUP_REFERENCE`,
  `#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE` (child table, row → child page)
- Edit/Delete only where allowed, keys read-only on change, required fields,
  value helps in edit mode, reload after save, open by key

Open:
- the target entity of an association is not read from the system — it comes
  from `resolve_association` (extension or subclass); find it automatically
- ~~`#DATAPOINT_REFERENCE` header facets, `@UI.textArrangement`~~ — done 2026-10
- a deep link / bookmark (the page can be opened by key — the URL part is missing)

## 5 · RAP write path — done (root entities, draft included)

- capabilities from the BDEF derived types, dynamic EML create/update/delete,
  actions (toolbar, inline, header) with parameters, REPORTED/FAILED messages

Open:
- ~~draft~~ — done 2026-10: Edit → change the draft → Activate, create a draft → Activate, one commit
- draft *editing* in the UI (keep a draft across roundtrips, Discard, "unsaved changes" of another user) —
  today a change is drafted and activated within one request
- child entities (create by association, update of items)
- late numbering: the key a BO assigns only on save is not read back (`CONVERT KEY`) —
  the page returns to the list instead (early numbering is read from `MAPPED`)
- RAW (UUID) keys: `reload_data` compares them with a character literal in a dynamic
  WHERE — verify in a system, a host variable may be needed
- feature control (`GET PERMISSIONS`: disabled actions, read-only fields per instance)

## 6 · Worklist — done

- a subclass of the list report: search, segments (`segment_field`), actions, navigation

- 2026-10: tabs from `@UI.selectionVariant` when no `segment_field` is given, sort from `@UI.presentationVariant`

## 7 · Overview page — done

- `sap.f` cards, aggregated KPI (SUM/AVG/MIN/MAX/COUNT), chart card from `@UI.chart`, navigation

- 2026-10: KPI card colored by `@UI.dataPoint.criticalityCalculation`

Open: more chart types (the bars are one type for all), cards from `@UI.presentationVariant`.

## 8 · Extension points — done

- `z2ui5_if_rap_ext` (`set_extension( )`): metadata, WHERE, rows, save, events, texts, associations
- `z2ui5_cl_rap_floorplan`: shared protected steps for every floorplan

- 2026-10: `extend_view` adds controls at fixed places (`cs_spot`) without a subclass

## Cross-cutting — open

- ~~server-side sorting and paging~~ — done 2026-10 (list report and worklist)
- i18n of the built-in texts: English and German are built in (2026-10); other
  languages through `get_text` — a text pool would make them translatable in SE63
- unit tests for more than `z2ui5_cl_rap_util` (the floorplans need the core in the transpiled run)
