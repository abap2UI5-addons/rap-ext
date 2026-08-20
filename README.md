![ABAP](https://img.shields.io/badge/ABAP-Standard%20(Steampunk)-blue)
[![namespace](https://img.shields.io/badge/namespace-z2ui5__cl__rap-blue)](abaplint.jsonc)
[![dependency](https://img.shields.io/badge/dependency-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fmain%2F.github%2Fbadges%2Fabap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check.yml)
<br><br>
[![check-abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fmain%2F.github%2Fbadges%2Fcheck-abap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check.yml)
[![check](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check.yml/badge.svg)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check.yml)

# rap-extension

Display RAP and CDS artifacts with abap2UI5

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
- **List Report**: `render_page`, `render_filter_bar`, `render_table`, `render_toolbar`, `render_column`, `render_cell`, `on_row_press`, `on_create`, `load_data`, `get_where_clause`, `on_event`
- **Object Page**: `render_page`, `render_header_title`, `render_actions`, `render_header_content`, `render_sections`, `render_section_form`, `save_data`, `delete_data`, `format_value`, `on_event`
- **Worklist / Value Help / Overview Page / Action Dialog**: their render and data-loading steps plus `on_event`

Scope: this addon renders from **CDS annotations**. For a list report over a
plain internal table there is no counterpart in the abap2UI5 core today — an
RTTI-based `z2ui5_cl_fp_list_report` existed there briefly and was removed
again, so do not rely on it; build such a view with `z2ui5_cl_ui5_view_builder`
directly.

### Validate

Both gates run offline, no SAP system needed (settings live in
`abap2ui5lint.jsonc`; CI runs the same two on every push and PR):

```bash
npx --yes @abaplint/cli@latest abaplint.jsonc          # syntax/style, 0 issues expected
npx --yes github:abap2UI5/abap2UI5-linter              # every generated view: UI5
                                                       # metadata + headless render
npx --yes github:abap2UI5/abap2UI5-linter --no-render  # fast loop, no browser
```

End-to-end still needs a system: install via abapGit and run
`z2ui5_cl_rap_test`.

### CDS Action Dialog (Popup)

Renders a popup dialog for an abstract CDS entity, driven by its annotations (labels, tooltips, default values, value helps, multiline texts, hidden fields).

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
      client->nav_app_call( CAST #( lo_dialog ) ).
      RETURN.

    ENDIF.

    lo_dialog = CAST #( client->get_app_prev( ) ).
    IF lo_dialog->was_confirmed( ).
      DATA(ls_cds_result) = CONV z2ui5_dd_rap_test_popup( lo_dialog->result( )->* ).
    ENDIF.

  ENDMETHOD.
```

### CDS Value Help

Renders a table select dialog for any CDS view. Visible columns come from the entity metadata; `@ObjectModel.text.element` adds description columns.

##### abap2UI5 Value Help Call
```abap
  DATA(lo_vh) = NEW z2ui5_cl_rap_value_help(
    cds_view_name = `I_COUNTRY`
    element       = `Country`
    title         = `Select Country` ).
  client->nav_app_call( CAST #( lo_vh ) ).
```

On return, read the selection:
```abap
  lo_vh = CAST #( client->get_app_prev( ) ).
  IF lo_vh->was_confirmed( ).
    DATA(lv_country) = lo_vh->result_value( ).
  ENDIF.
```

### CDS List Report

Renders a Fiori-Elements-style list report for any CDS view, driven entirely by its annotations:
- Columns from `@UI.lineItem` (position, label, importance-based responsive popin)
- Filter bar from `@UI.selectionField` (contains-search for text fields, `*` wildcards supported)
- Criticality columns from `@UI.lineItem.criticality` / `@UI.dataPoint.criticality`
- Amount/quantity columns from `@Semantics.amount.currencyCode` / `@Semantics.quantity.unitOfMeasure`
- Title from `@UI.headerInfo.typeNamePlural`, live row count
- Row navigation to a generated object page (row matched via `@ObjectModel.semanticKey`)

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
- Header attributes from `@UI.identification` (fallback: first visible fields)
- Status attributes with criticality from `@UI.dataPoint`
- Sections from `@UI.facet` fieldGroup references (order + labels), fallback to `@UI.fieldGroup` qualifiers
- User-format dates/times, Yes/No booleans, amounts/quantities with unit via `@Semantics`

##### abap2UI5 Object Page Call
```abap
"val: any structure typed after the CDS entity
client->nav_app_call( NEW z2ui5_cl_rap_object_page( val = ls_row ) ).
```

### CDS Worklist

Renders a simple read-only table of a CDS view with `@UI.lineItem` columns (fallback: all visible fields):

```abap
client->nav_app_call( NEW z2ui5_cl_rap_worklist(
  cds_view_name = `I_CURRENCY`
  title         = `Currencies` ) ).
```

### CDS Overview Page

Renders a grid of cards (table or KPI) for multiple CDS views:

```abap
client->nav_app_call( NEW z2ui5_cl_rap_overview_page(
  title = `Business Overview`
  cards = VALUE #(
    ( cds_view_name = `I_COUNTRY`  title = `Countries`  card_type = `TABLE` max_rows = 5 )
    ( cds_view_name = `I_LANGUAGE` title = `Languages`  card_type = `KPI` ) ) ) ).
```

### Demo

See `z2ui5_cl_rap_test` for a demo app that showcases all components.
