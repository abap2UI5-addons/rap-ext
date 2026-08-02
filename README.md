# cds-wrapper

Display CDS artifacts with abap2UI5

### The Escape Hatch

Every floorplan in this addon is deliberately **not FINAL**: all rendering
and event steps are `PROTECTED` methods a subclass can redefine with
ordinary abap2UI5 view code, and events the floorplan does not know are
routed to the `on_event` hook. Breaking out of a floorplan is not a
breakout — it is just another view method.

```abap
CLASS zcl_my_report DEFINITION PUBLIC
  INHERITING FROM z2ui5_cl_cds_list_report CREATE PUBLIC.
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
    DATA(lo_toolbar) = io_table->header_toolbar( )->overflow_toolbar( ).
    lo_toolbar->title( text = mv_title && ` (` && client->_bind( mv_count ) && `)` ).
    lo_toolbar->toolbar_spacer( ).
    lo_toolbar->button( text  = `Approve`
                        type  = `Emphasized`
                        press = client->_event( `APPROVE` ) ).
    lo_toolbar->button( icon  = `sap-icon://refresh`
                        press = client->_event( cs_event-refresh ) ).
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

Related: `z2ui5_cl_fp_list_report` in the abap2UI5 core generates the same
list report UX from any flat internal table via RTTI — use it when the
data source is not a CDS view with UI annotations.

### CDS Action Dialog (Popup)

Renders a popup dialog for an abstract CDS entity, driven by its annotations (labels, tooltips, default values, value helps, multiline texts, hidden fields).

##### Popup Definition
```cds
@EndUserText.label: 'Entity for popup'
define abstract entity z2ui5_cds_test_popup
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

      DATA(lo_dialog) = NEW z2ui5_cl_cds_action_dialog(
        val   = VALUE z2ui5_cds_test_popup( searchcountry = `US` )
        title = `Enter Parameters` ).
      client->nav_app_call( CAST #( lo_dialog ) ).
      RETURN.

    ENDIF.

    lo_dialog = CAST #( client->get_app_prev( ) ).
    IF lo_dialog->was_confirmed( ).
      DATA(ls_cds_result) = CONV z2ui5_cds_test_popup( lo_dialog->result( )->* ).
    ENDIF.

  ENDMETHOD.
```

### CDS Value Help

Renders a table select dialog for any CDS view. Visible columns come from the entity metadata; `@ObjectModel.text.element` adds description columns.

##### abap2UI5 Value Help Call
```abap
  DATA(lo_vh) = NEW z2ui5_cl_cds_value_help(
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
client->nav_app_call( NEW z2ui5_cl_cds_list_report(
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
client->nav_app_call( NEW z2ui5_cl_cds_object_page( val = ls_row ) ).
```

### CDS Worklist

Renders a simple read-only table of a CDS view with `@UI.lineItem` columns (fallback: all visible fields):

```abap
client->nav_app_call( NEW z2ui5_cl_cds_worklist(
  cds_view_name = `I_CURRENCY`
  title         = `Currencies` ) ).
```

### CDS Overview Page

Renders a grid of cards (table or KPI) for multiple CDS views:

```abap
client->nav_app_call( NEW z2ui5_cl_cds_overview_page(
  title = `Business Overview`
  cards = VALUE #(
    ( cds_view_name = `I_COUNTRY`  title = `Countries`  card_type = `TABLE` max_rows = 5 )
    ( cds_view_name = `I_LANGUAGE` title = `Languages`  card_type = `KPI` ) ) ) ).
```

### Demo

See `z2ui5_cl_cds_test` for a demo app that showcases all components.
