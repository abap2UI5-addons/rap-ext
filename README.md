![ABAP](https://img.shields.io/badge/ABAP-7.58%20%E2%86%92%20Standard-blue)
[![namespace](https://img.shields.io/badge/namespace-z2ui5__cl__rap-blue)](abaplint.jsonc)
[![dependency](https://img.shields.io/badge/dependency-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fbadges%2Fabap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check-abap2ui5.yaml)
<br><br>
[![abap-standard](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/abap-standard.yaml/badge.svg)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/abap-standard.yaml)
<br>
[![check-abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fbadges%2Fcheck-abap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check-abap2ui5.yaml)
[![unit](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/unit.yaml/badge.svg)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/unit.yaml)

# rap-extension

Display RAP and CDS artifacts with abap2UI5 - Fiori-Elements-style floorplans
generated at runtime from a CDS entity and its UI annotations (metadata
extensions included), rendered with abap2UI5, writing through RAP.

| Floorplan | Class |
| --- | --- |
| List Report | `z2ui5_cl_rap_list_report` |
| Worklist | `z2ui5_cl_rap_worklist` |
| Object Page | `z2ui5_cl_rap_object_page` |
| Overview Page | `z2ui5_cl_rap_overview_page` |
| Value Help | `z2ui5_cl_rap_value_help` |
| Action Dialog (popup) | `z2ui5_cl_rap_action_dialog` |

All of them inherit from `z2ui5_cl_rap_floorplan`, which holds what they share
(reading, the filter syntax, the control for a field, value helps, writing,
texts, extension points). `z2ui5_cl_rap_util` reads the metadata,
`z2ui5_cl_rap_eml` writes through RAP.

### The Escape Hatch

Every floorplan in this addon is deliberately **not FINAL**: all rendering
and event steps are `PROTECTED` methods a subclass can redefine with
ordinary abap2UI5 view code, and events the floorplan does not know are
routed to the `on_event` hook. Breaking out of a floorplan is not a
breakout — it is just another view method.

> **Builder change (breaking for subclasses).** The floorplans build their
> views with the core's generic builder
> **`z2ui5_cl_ui5_view_builder`** (`src/02`, the released API) instead of the
> frozen `z2ui5_cl_xml_view`. Every render hook that takes a builder handle
> (`io_page`, `io_table`, `io_columns`, `io_cells`, `io_op`, `io_actions`,
> `io_parent`, `io_container`) types it
> `TYPE REF TO z2ui5_cl_ui5_view_builder`, and a redefining subclass has to
> be updated to the verbs `ele` / `tag` / `a` / `end` shown below. Parameter
> names and the set of hooks are unchanged. In return the views are now
> checkable without an SAP system — see "Validate".
>
> An earlier version of this note named the builder `z2ui5_cl_ai_xml` and the
> verbs `open` / `leaf` / `shut`. No such class ever shipped in the core, so
> the repository did not compile against it; the names here are the ones
> `abap2UI5/abap2UI5` actually releases.

```abap
CLASS zcl_my_report DEFINITION PUBLIC
  INHERITING FROM z2ui5_cl_rap_list_report CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor.
  PROTECTED SECTION.
    METHODS render_toolbar REDEFINITION.
    METHODS on_event REDEFINITION.
ENDCLASS.

CLASS zcl_my_report IMPLEMENTATION.

  METHOD constructor.
    super->constructor( cds_view_name = `I_COUNTRY` ).
  ENDMETHOD.

  METHOD render_toolbar.
    "replace the generated toolbar with your own - plain abap2UI5 view code
    DATA(lo_toolbar) = io_table->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).

    lo_toolbar->tag( `Title`
        )->a( n = `text`
              v = mv_title && ` (` && client->_bind( mv_count ) && `)` ).

    lo_toolbar->tag( `ToolbarSpacer` ).

    lo_toolbar->tag( `Button`
        )->a( n = `text`  v = `Approve`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `APPROVE` ) ).

    lo_toolbar->tag( `Button`
        )->a( n = `icon`  v = `sap-icon://refresh`
        )->a( n = `press` v = client->_event( cs_event-refresh ) ).
  ENDMETHOD.

  METHOD on_event.
    "custom events land here - exactly like a hand-written app
    IF client->check_on_event( `APPROVE` ).
      client->message_toast_display( `Approved` ).
      RETURN.
    ENDIF.
    super->on_event( client ).
  ENDMETHOD.

ENDCLASS.
```

Overridable steps per floorplan:
- **List Report**: `render_page`, `render_filter_bar`, `render_table`, `render_toolbar`, `render_column`, `render_cell`, `on_row_press`, `on_create`, `on_action`, `execute_action`, `on_navigated`, `load_data`, `get_where_clause`, `get_line_item_fields`, `get_selection_fields`, `get_row_key_fields`, `get_line_item_actions`, `get_line_item_intents`, `get_visible_columns`, `get_missing_filters`, `on_nav_path`, `on_intent`, `on_export`, `render_export_button`, `init_variants`, `render_variant_controls`, `render_variant_popup`, `render_column_popup`, `on_variant_event`, `capture_variant`, `apply_variant`, `on_event`
- **Worklist**: everything of the list report (it is a subclass of it), plus `load_segments`
- **Object Page**: `render_page`, `render_header_title`, `render_actions`, `render_header_content`, `render_sections`, `render_section_content`, `render_section_form`, `render_section_fields`, `render_section_table`, `get_sections`, `save_data`, `delete_data`, `reload_data`, `load_child_rows`, `get_association_target`, `get_child_filter`, `get_child_context`, `on_child_create`, `get_bdef`, `get_root_keys`, `get_own_keys`, `start_draft`, `save_draft`, `find_created_record`, `get_link`, `on_action`, `execute_action`, `on_child_row`, `format_value`, `on_event`
- **Overview Page**: `render_page`, `render_table_card`, `render_kpi_card`, `render_chart_card`, `render_card_link`, `load_all_cards`, `load_kpi_value`, `load_chart_rows`, `collect_card_rows`, `display`, `on_card`, `on_card_row`, `on_event`
- **Value Help**: `render_dialog`, `render_filter_dialog`, `load_data`, `get_where_clause`, `on_confirm`, `on_event`
- **Action Dialog**: `render_action_dialog`, `get_control_for_field`, `render_value_help`, `handle_value_help_confirm`, `apply_default_values`, `get_missing_fields`, `on_event`
- **Every floorplan** (`z2ui5_cl_rap_floorplan`): `select_rows`, `count_rows`, `build_filter_condition`, `build_search_condition`, `build_key_condition`, `create_host`, `render_field_input`, `prepare_value_lists`, `load_suggestions`, `open_value_help`, `apply_value_help`, `get_entity_capabilities`, `write_row`, `write_table_row`, `is_draft_enabled`, `write_draft`, `run_draft_action`, `run_action`, `navigate_to_intent`, `read_association_target`, `get_text`, ...

### Extension points without a subclass

`z2ui5_if_rap_ext` changes a floorplan's data, metadata, texts and events;
hand an implementation to any floorplan with `set_extension( )`. Every method
is `DEFAULT IGNORE` - implement only what you need. The floorplans pass the
extension on to the apps they call (object page, value help, action dialog).

```abap
CLASS zcl_my_ext DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_rap_ext.
ENDCLASS.

CLASS zcl_my_ext IMPLEMENTATION.

  METHOD z2ui5_if_rap_ext~adjust_entity.
    "hide a field, rename another - without touching the CDS view
    entity-fields[ name = `CREATEDBY` ]-is_hidden = abap_true.
    entity-fields[ name = `COUNTRY` ]-label = `Land`.
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~adjust_where.
    "only the user's own travels - every read passes here, the value
    "helps' included, so look at the entity first
    IF entity_name <> `/DMO/C_TRAVEL_PROCESSOR_M`.
      RETURN.
    ENDIF.
    where = COND #( WHEN where IS INITIAL THEN |CREATEDBY = '{ sy-uname }'|
                    ELSE |{ where } AND CREATEDBY = '{ sy-uname }'| ).
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~get_text.
    IF key = z2ui5_cl_rap_floorplan=>cs_text-create.
      text = `Anlegen`.
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~resolve_association.
    "the target of a #LINEITEM_REFERENCE facet
    IF association = `_BOOKING`.
      target = `/DMO/C_BOOKING_PROCESSOR_M`.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

```abap
DATA(lo_report) = NEW z2ui5_cl_rap_list_report( cds_view_name = `/DMO/C_TRAVEL_PROCESSOR_M` ).
lo_report->set_extension( NEW zcl_my_ext( ) ).
client->nav_app_call( lo_report ).
```

| Method | When |
| --- | --- |
| `adjust_entity` | after the metadata is read - labels, hidden fields, positions, field groups, value helps, actions |
| `adjust_where` | before every read - the dynamic WHERE clause |
| `after_load` | after every read - the rows |
| `before_save` / `after_save` | around create, update, delete and actions - `cancel` stops one |
| `on_event` | every event, before the floorplan - return `abap_true` to take it over |
| `get_text` | every text (keys in `z2ui5_cl_rap_floorplan=>cs_text`) - translation |
| `resolve_association` | the target entity of a `#LINEITEM_REFERENCE` facet - decided before the DDL source is asked |
| `adjust_capabilities` | what may be written: switch on the writes of a database table, withhold an operation of a business object |
| `get_start_app` | the `z2ui5_cl_rap_start` subclass whose links the object page copies (see "Deep links") |
| `extend_view` | add controls at fixed places (`z2ui5_cl_rap_floorplan=>cs_spot`): the table toolbar, the object page's header actions and sections, the dialog's content, the overview's cards - their events arrive in `on_event` first |

The built-in texts are German for a German logon (`sy-langu` `D`) and
otherwise the text pool of `z2ui5_cl_rap_floorplan` (English, translatable in
SE63); `get_text` changes any of them.

The extension travels with the app through the abap2UI5 draft: the interface
includes `if_serializable_object`, so keep its attributes serializable.

Scope: this addon renders from **CDS annotations**. For a list report over a
plain internal table there is no counterpart in the abap2UI5 core today — an
RTTI-based `z2ui5_cl_fp_list_report` existed there briefly and was removed
again, so do not rely on it; build such a view with `z2ui5_cl_ui5_view_builder`
directly.

### Validate

Three gates run offline, no SAP system needed (CI runs the same on every push
and PR):

```bash
npm ci                          # the pinned toolchain, linter and render runtime
npm run lint                    # abaplint: syntax/style, 0 issues expected
npm run unit                    # ABAP Unit tests that need no system, transpiled -
                                # the util and the list report and object page
npx abap2ui5lint                # every generated view: UI5 metadata + headless render
npx abap2ui5lint --no-render    # fast loop, no browser
npm run check                   # all three
```

abaplint checks against the abap2UI5 release pinned in `abaplint.jsonc`
(`scripts/core-pin.mjs`, moved weekly by `bump-core.yml`); the weekly run of
`abap-standard.yaml` is the canary against the core's `main`.

End-to-end still needs a system: install via abapGit and run
`z2ui5_cl_rap_test`.

### Metadata

`z2ui5_cl_rap_util=>read_entity( )` reads the fields (RTTI), the keys and the
data element texts (DDIC), the associations and every annotation - through
`CL_DD_DDL_ANNOTATION_SERVICE=>GET_ANNOS`, so **metadata extensions** are
included (RAP objects keep their `@UI` annotations there). Annotation arrays
and qualifiers are read per entry:

| Annotation | Used for |
| --- | --- |
| `@UI.headerInfo` | titles, object page header |
| `@UI.lineItem` | columns (position, label, importance, criticality); `type: #FOR_ACTION` entries are actions (`inline: true` per row); `#WITH_URL` a link to the URL in another field, `#WITH_NAVIGATION_PATH` the object page of the record the association (`targetElement`) leads to, `#WITH_INTENT_BASED_NAVIGATION` and `#FOR_INTENT_BASED_NAVIGATION` a navigation in the Fiori launchpad (`semanticObject`, `semanticObjectAction`) |
| `@UI.selectionField` | filter bar |
| `@UI.identification` | object page header attributes; `#FOR_ACTION` entries are header actions |
| `@UI.fieldGroup` | object page forms - a field can sit in several groups |
| `@UI.facet` | object page sections: `#COLLECTION`, `#FIELDGROUP_REFERENCE`, `#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE` - on the entity or on an element; with `purpose: #HEADER` (`#DATAPOINT_REFERENCE`, `#FIELDGROUP_REFERENCE`) the object page header |
| `@UI.dataPoint` | status with criticality, KPI cards; `criticalityCalculation` (`#MAXIMIZE`, `#MINIMIZE`, `#TARGET` with tolerance/deviation values) colors a KPI card |
| `@UI.presentationVariant` | the default sort order (`sortOrder`) of list report and worklist; an overview card's content (`visualizations`, `sortOrder`, `maxItems`) |
| `@UI.selectionVariant` | worklist tabs - one per variant, its `filter` string (`Status EQ O AND Priority GE 3`; EQ NE GT GE LT LE) |
| `@UI.textArrangement` | how value and text are shown: `#TEXT_FIRST` (default), `#TEXT_LAST`, `#TEXT_ONLY`, `#TEXT_SEPARATE` |
| `@UI.chart` | chart cards (first dimension, first measure); `chartType` `#BAR`/`#COLUMN` bars, `#DONUT`/`#PIE` shares, `#LINE`/`#AREA` a trend |
| `@UI.hidden`, `@UI.multiLineText`, `@UI.defaultValue` | visibility, text areas, dialog defaults |
| `@ObjectModel.text.element` | "Text (Value)" cells, value help descriptions |
| `@ObjectModel.semanticKey` | the key when the DDIC has none |
| `@ObjectModel.mandatory` / `.readOnly` | required fields (checked before save/confirm), read-only inputs |
| `@ObjectModel.resultSet.sizeCategory: #XS` | a dropdown instead of a value help |
| `@Consumption.valueHelpDefinition` | value helps, with `additionalBinding` (usage `#FILTER` and `#RESULT`) |
| `@Consumption.filter` | filter bar: `defaultValue`, `mandatory` (no rows until it has a value), `selectionType: #SINGLE` / `multipleSelections: false` (the value help selects one), `hidden` |
| `@Search.searchable`, `@Search.defaultSearchElement` | the search field and what it searches |
| `@Semantics.amount.currencyCode`, `.quantity.unitOfMeasure`, `.booleanIndicator` | numbers with units, Yes/No |
| `@Semantics.user.createdBy`, `.systemDateTime.createdAt` | a record created with late numbering is found again by them |
| `@EndUserText.label` / `.quickInfo` | labels, tooltips |

The **associations** come from the entity's DDL source (`DDDDLSRC`, read by
name): `association [..] to X as _A on ...`, `association to parent`,
`composition [..] of X as _A`, the 7.58 forms (`of many to one`) and in a
projection `_A : redirected to [composition child | parent] X`. A projection
takes what it does not redirect from its base, and a composition takes its
ON condition from the child's association to parent. The object page reads
the rows of a `#LINEITEM_REFERENCE` table by that ON condition (else by the
keys under the same names), and `resolve_association` still decides first.

### Writing - RAP, tables, read-only

What an entity lets the user do is asked from its BDEF
(`z2ui5_cl_rap_floorplan=>get_capabilities`): a business object whose root is
the entity is written through **dynamic EML** (`MODIFY ENTITIES OPERATIONS`,
`COMMIT ENTITIES`), and only the operations its BDEF defines are offered
(Create, Edit, Delete, and the `#FOR_ACTION` actions - with a parameter
dialog when the action has a parameter). The messages of `REPORTED` and
`FAILED` are shown. A CDS view that is no business object is read-only: no
Create, Edit or Delete.

A **transparent table is read-only too, unless an extension allows its
writes** - up to 2026-10 every table a floorplan was opened on could be
changed and deleted by anyone who reached the app:

```abap
METHOD z2ui5_if_rap_ext~adjust_capabilities.
  IF entity_name = `ZMY_TABLE`.
    caps-can_create = abap_true.
    caps-can_update = abap_true.
    caps-can_delete = abap_true.
  ENDIF.
ENDMETHOD.
```

A table write then checks the authorization `S_TABU_NAM` (activity `02`)
for the table, locks the row (`ENQUEUE_E_TABLE`), and refuses an update or
delete when the row in the database is no longer the one the user saw. It is
committed right after the write (`COMMIT WORK`) - the abap2UI5 core rolls
back the LUW of every non-sticky app after `main( )`. `adjust_capabilities`
can also withhold an operation of a business object; it cannot add one its
BDEF lacks. Every write and action is checked against these capabilities on
the server, not only by hiding the buttons, and only the actions the
annotations offer can be run.
After a RAP create the page reads the record again by the keys `MAPPED`
returns; a business object that assigns its key only on save (late
numbering) hands none back, and the page then returns to the list.

A **draft-enabled** business object (its BDEF has the draft action Edit) is
written the way its own UI does: a change is Edit (a draft of the active
instance), the change of the draft, Activate; a create is a draft that is
activated. All of it runs before the one `COMMIT ENTITIES`, and a failed step
rolls the request back - no draft is left behind.

A **child entity** is written through the BDEF of its root: the object page
of a child carries its place in the business object
(`z2ui5_cl_rap_floorplan=>ty_s_rap_context` - the BDEF, the root's keys, the
parent), and a table of a composition offers Create - a create by
association (`%target`) under the record. A change of a child of a draft
business object edits and activates the root.

On the object page, a **draft business object is edited in a draft that spans
roundtrips**: Edit creates it (committed), Save writes the changes into it
and activates it, and Cancel or leaving the page discards it. When the
activation is refused the draft keeps the changes and the page stays in edit
mode. A draft that exists already (another user's, or one left by another
app) is the business object's message; one of the user's own can be
discarded - resuming it needs the draft read back, which is open.

Keys are compared with **typed host variables**, not literals, so a RAW key
(a UUID) reads the record again. A record created with **late numbering**
(no key in `MAPPED`) is found again by `@Semantics.user.createdBy` and
`@Semantics.systemDateTime.createdAt`; without them the page returns to the
list. The fields a RAP message names (`%element`) are marked in edit mode.

Not yet: feature control (`GET PERMISSIONS`) and reading a draft back -
see [ROADMAP.md](ROADMAP.md).

### Filter syntax

The filter bar (and `build_filter_condition`) understands:

| Input | Meaning |
| --- | --- |
| `abc` | contains (text fields), equals (other types) |
| `a*c` | pattern |
| `=abc` | equals |
| `!abc` | not |
| `a..z` | between |
| `>x` `>=x` `<x` `<=x` | compare |
| `a;b` | several, ORed |

Dates can be typed as `2024-01-15`. A value help in the filter bar fills
exact values (`=US;=DE`).

### CDS Action Dialog (Popup)

Renders a popup dialog for an abstract CDS entity, driven by its annotations (labels, tooltips, default values, value helps, dropdowns, multiline texts, hidden and mandatory fields). The list report and the object page use it for the parameter of a RAP action.

##### Popup Definition
```cds
@EndUserText.label: 'Entity for popup'
define abstract entity z2ui5_dd_rap_test_popup
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
  @EndUserText.label: 'Country'
  SearchCountry : land1;
  @EndUserText.label: 'Valid To'
  @UI.defaultValue: '99991231'
  NewDate       : abap.dats;
  @EndUserText.label: 'Message Type'
  MessageType   : abap.int4;
  @EndUserText.label: 'Update data'
  FlagUpdate    : abap.char(1);
  @EndUserText.label: 'Show Messages'
  FlagMessage   : abap_boolean;
}
```

##### abap2UI5 Popup Call
```abap
  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog(
        val   = VALUE z2ui5_dd_rap_test_popup( searchcountry = `US` )
        title = `Enter Parameters` ).
      client->nav_app_call( lo_dialog ).
      RETURN.

    ENDIF.

    lo_dialog = CAST #( client->get_app_prev( ) ).
    IF lo_dialog->was_confirmed( ).
      DATA(ls_cds_result) = CONV z2ui5_dd_rap_test_popup( lo_dialog->result( )->* ).
    ENDIF.

  ENDMETHOD.
```

### CDS Value Help

Renders a table select dialog for any CDS view. Visible columns come from the
entity metadata; `@ObjectModel.text.element` adds description columns. The
search field searches the database. `multi_select` lets the user pick several
rows, `filters` restricts the rows (name/value pairs). An entity with
`@UI.selectionField` fields gets a filter bar of its own (the list report's
filter syntax).

An input with a value help (object page, action dialog) **suggests values
while the user types**: the rows whose element starts with the text or whose
text fields contain it.

##### abap2UI5 Value Help Call
```abap
  DATA(lo_vh) = NEW z2ui5_cl_rap_value_help(
    cds_view_name = `I_COUNTRY`
    element       = `Country`
    title         = `Select Country` ).
  client->nav_app_call( lo_vh ).
```

On return, read the selection:
```abap
  lo_vh = CAST #( client->get_app_prev( ) ).
  IF lo_vh->was_confirmed( ).
    DATA(lv_country) = lo_vh->result_value( ).     "the element of the first row
    DATA(lt_countries) = lo_vh->result_values( ).  "of every selected row
    DATA(lr_rows) = lo_vh->result_table( ).        "the selected rows
  ENDIF.
```

### CDS List Report

Renders a Fiori-Elements-style list report for any CDS view, driven entirely by its annotations:
- Columns from `@UI.lineItem` (position, label, importance-based responsive popin)
- Filter bar from `@UI.selectionField` - filter syntax above, value helps, defaults; a search field for `@Search.searchable` views
- Criticality columns from `@UI.lineItem.criticality` / `@UI.dataPoint.criticality`
- Amount/quantity columns from `@Semantics.amount.currencyCode` / `@Semantics.quantity.unitOfMeasure`, "Text (Value)" for `@ObjectModel.text.element`
- Title from `@UI.headerInfo.typeNamePlural`, the count of all matching rows
- Sorting in the database - a select of the columns and a direction button, the default from `@UI.presentationVariant`; "More" loads the next rows from the database
- Actions from `@UI.lineItem` `#FOR_ACTION` (toolbar on the selected rows, or inline per row); links and launchpad navigations from `#WITH_URL`, `#WITH_NAVIGATION_PATH`, `#WITH_INTENT_BASED_NAVIGATION` and `#FOR_INTENT_BASED_NAVIGATION`
- Mandatory and single-value filters from `@Consumption.filter`
- Views per user (filters, search, sort order, hidden columns; one the default), a columns dialog, and the export of every matching row as a CSV file
- Create where the entity allows it; row navigation to a generated object page

##### abap2UI5 List Report Call
```abap
client->nav_app_call( NEW z2ui5_cl_rap_list_report(
  cds_view_name = `I_COUNTRY`
  title         = `Countries`
  max_rows      = 500 ) ).
```

### CDS Object Page

Renders an object page for a single record of a CDS entity:
- Header title/description from `@UI.headerInfo`
- Header from the `@UI.facet` entries with `purpose: #HEADER`, else attributes from `@UI.identification` (fallback: first visible fields)
- Status attributes with criticality from `@UI.dataPoint`
- Sections from `@UI.facet`: collections with subsections, field groups, identification, tables of an association (`#LINEITEM_REFERENCE` - the target and the rows from the DDL source's association, or from `resolve_association`); Create in a composition's table
- Edit/Save/Delete and the `@UI.identification` actions where the entity allows them; keys read-only on change, required fields checked, value helps, suggestions and dropdowns in edit mode, the fields of a save's messages marked; a draft business object edited in its draft
- A button that copies a link to the record (see "Deep links")
- User-format dates/times, Yes/No booleans, amounts/quantities with unit via `@Semantics`

##### abap2UI5 Object Page Call
```abap
"val: any structure typed after the CDS entity
client->nav_app_call( NEW z2ui5_cl_rap_object_page( val = ls_row ) ).

"or read by key
client->nav_app_call( NEW z2ui5_cl_rap_object_page(
  cds_view_name = `I_COUNTRY`
  keys          = VALUE #( ( name = `Country` value = `DE` ) ) ) ).
```

### Deep links

`z2ui5_cl_rap_start` opens a floorplan from its URL - or the startup
parameters of a launchpad tile - so a link outlives the abap2UI5 draft:

```
...?app_start=zcl_my_rap_start&floorplan=OBJECT_PAGE&entity=I_COUNTRY&Country=DE
```

`floorplan` is `OBJECT_PAGE` (the default when keys are given),
`LIST_REPORT` or `WORKLIST`; every other parameter is a key. A URL can name
any entity, so `z2ui5_cl_rap_start` opens none by itself - a subclass lists
the entities it may open:

```abap
CLASS zcl_my_rap_start DEFINITION PUBLIC INHERITING FROM z2ui5_cl_rap_start
  FINAL CREATE PUBLIC.
  PROTECTED SECTION.
    METHODS get_allowed_entities REDEFINITION.
ENDCLASS.

CLASS zcl_my_rap_start IMPLEMENTATION.
  METHOD get_allowed_entities.
    result = VALUE #( ( `I_COUNTRY` ) ( `/DMO/C_TRAVEL_PROCESSOR_M` ) ).
  ENDMETHOD.
ENDCLASS.
```

`get_extension` hands the floorplan an extension, and
`z2ui5_cl_rap_start=>get_link( )` builds such a link. The object page's link
button copies one when `z2ui5_if_rap_ext~get_start_app` names the subclass,
else the link of the app's current state (valid while its draft lives).

### CDS Worklist

The items to work through: a table with `@UI.lineItem` columns, a search
field, sorting, the actions and row navigation. With `segment_field`, a tab
per value of that field with its count; without it, a tab per
`@UI.selectionVariant` of the entity:

```abap
client->nav_app_call( NEW z2ui5_cl_rap_worklist(
  cds_view_name = `/DMO/I_TRAVEL_U`
  title         = `Travels`
  segment_field = `Status` ) ).
```

### CDS Overview Page

Renders a grid of cards for multiple CDS views - `TABLE` (the first rows), `KPI`
(an aggregated number) or `CHART` (the first `@UI.chart`: bars for `#BAR` and
`#COLUMN`, shares of the total for `#DONUT` and `#PIE`, a trend for `#LINE` and
`#AREA` - drawn with `sap.m` controls, which every UI5 runtime has; the card's
`chart_type` overrides it). A card with `presentation_variant` shows that
`@UI.presentationVariant`: its chart, or the table sorted and sized as the
variant says. Every card links to the list report of its view; a table row
opens its object page.

```abap
client->nav_app_call( NEW z2ui5_cl_rap_overview_page(
  title = `Business Overview`
  cards = VALUE #(
    ( cds_view_name = `I_COUNTRY`  title = `Countries`  card_type = `TABLE` max_rows = 5 )
    ( cds_view_name = `I_LANGUAGE` title = `Languages`  card_type = `KPI` )
    ( cds_view_name = `ZC_SALES`   title = `Revenue`    card_type = `KPI`
      kpi_field = `NetAmount` kpi_aggregation = `SUM` kpi_unit = `EUR` )
    ( cds_view_name = `ZC_SALES`   title = `By region`  card_type = `CHART` ) ) ) ).
```

A KPI card aggregates `kpi_field` (`SUM`, `AVG`, `MIN`, `MAX`), else the first
numeric `@UI.dataPoint` field, else counts the rows.

The cards bind their rows through the public `mr_card_rows`: after
`load_all_cards( )` has filled `mt_card_data`, `collect_card_rows( )` moves
each card's rows into a component of it (`CARD_1`, `CARD_2`, ... by position)
and points the card's `data_ref` there. A redefined `render_table_card` binds
`is_card-data_ref->*` the way the shipped one does, and a redefined
`load_all_cards` only has to fill `mt_card_data`.

### Changes in 2026-09

Additive for callers and subclasses, with these exceptions a subclass may notice:

- The floorplans have a superclass, `z2ui5_cl_rap_floorplan`. A subclass that
  declared a method of the same name as one of its new protected methods has
  to rename it.
- `z2ui5_cl_rap_worklist` is a subclass of `z2ui5_cl_rap_list_report`; its
  `cs_event` is the list report's (same values for `refresh` and `back`), and
  the list report's events (`GO`, `SEARCH`, `CREATE`, `ACTION`, `ROW_PRESS`,
  `FILTER_VALUE_HELP`) no longer reach a worklist subclass's `on_event`.
- Create, Edit and Delete appear only where the entity is writable (see
  "Writing").
- When the list report has actions, `mr_data` rows carry the selection column
  `ZZSELKZ`; `to_entity_row( )` drops it.
- The action dialog calls `z2ui5_cl_rap_value_help` for a value help instead
  of rendering its own popup; `mt_vh_data` holds the rows the value help
  returned.
- The overview page's cards are `sap.f.Card`s in a `sap.f.GridContainer`
  instead of panels and tiles in a layout grid; `count` is the number of rows
  of the view.

### Changes in 2026-10

- New protected members in the floorplans (`render_sort_controls`,
  `get_order_by`, `render_header_facets`, `get_display_text`,
  `render_dialog_field`, `render_extension`, ...) - the same rename rule as
  above applies to a subclass.
- `z2ui5_if_rap_ext` has a new method, `extend_view` - `DEFAULT IGNORE`, so
  existing implementations keep compiling.
- A draft-enabled business object is written through its draft (see
  "Writing").
- The list report sorts in the database, and its "more" button loads rows
  instead of the table growing over the loaded ones; the object page header
  follows the header facets when there are any.

### Changes in 2026-10, second round

- **A database table is read-only** until an extension allows its writes
  (`adjust_capabilities`, see "Writing") - an app that changed a table through
  a floorplan needs one now.
- New protected members in the floorplans (see the lists above) - the rename
  rule applies to a subclass. `render_cell` has a new optional `client`.
- `z2ui5_if_rap_ext` has the new methods `adjust_capabilities` and
  `get_start_app` - `DEFAULT IGNORE`.
- Appended components: `ty_s_result` (`details`), `ty_s_field_info`,
  `ty_s_entity_info`, `ty_s_action`, the list report's `ty_s_filter`, the
  object page's `ty_s_child`, the overview's `ty_s_card`, `ty_s_card_data` and
  `ty_s_chart_row` grew at their end. New optional parameters (`context`,
  `host`, `with_selection`, `value_state`) leave every call as it was.
- New objects: `z2ui5_cl_rap_start` (deep links), `z2ui5_cl_rap_variant` and
  the table `z2ui5_t_rap_var` (views), `z2ui5_cl_rap_test_start` (the demo's
  deep links).
- The object page of a draft business object edits in a committed draft; the
  value help of an entity with selection fields is a `sap.m.Dialog`.

### Demo

See `z2ui5_cl_rap_test` for a demo app that showcases all components, and
`z2ui5_cl_rap_test_start` for its deep links. The checklist of what to click
through in a system is [docs/system-test.md](docs/system-test.md).
