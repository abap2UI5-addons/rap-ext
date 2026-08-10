"! Fiori-Elements-style list report generated from the annotations of a
"! CDS view - columns, filter bar, criticality, units and row navigation
"! all come from the metadata (see README).
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event, so a subclass adds its
"! own actions the same way any abap2UI5 app handles them.
"!
"! Related: z2ui5_cl_fp_list_report in the abap2UI5 core generates the
"! same UX from any flat internal table via RTTI - use it when the data
"! source is not a CDS view with UI annotations.
CLASS z2ui5_cl_rap_list_report DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_filter,
        name  TYPE string,
        label TYPE string,
        value TYPE string,
      END OF ty_s_filter.

    TYPES ty_t_filter TYPE STANDARD TABLE OF ty_s_filter WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF cs_event,
        refresh   TYPE string VALUE `REFRESH`,
        go        TYPE string VALUE `GO`,
        row_press TYPE string VALUE `ROW_PRESS`,
        back      TYPE string VALUE `BACK`,
        create    TYPE string VALUE `CREATE`,
      END OF cs_event.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500.

    DATA mv_cds_view TYPE string.
    DATA mv_title    TYPE string.
    DATA mv_max_rows TYPE i.
    DATA mv_count    TYPE string.
    DATA ms_entity   TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mr_data     TYPE REF TO data.
    DATA mt_filter   TYPE ty_t_filter.

  PROTECTED SECTION.

    DATA mt_row_key TYPE string_table.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app;
    "! the default implementation only acknowledges the roundtrip
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS load_data.

    METHODS get_where_clause
      RETURNING
        VALUE(result) TYPE string.

    "! page skeleton - delegates to render_filter_bar and render_table
    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_filter_bar
      IMPORTING
        io_page TYPE REF TO z2ui5_cl_ai_xml
        client  TYPE REF TO z2ui5_if_client.

    METHODS render_table
      IMPORTING
        io_page TYPE REF TO z2ui5_cl_ai_xml
        client  TYPE REF TO z2ui5_if_client.

    METHODS render_toolbar
      IMPORTING
        io_table TYPE REF TO z2ui5_cl_ai_xml
        client   TYPE REF TO z2ui5_if_client.

    METHODS render_column
      IMPORTING
        io_columns TYPE REF TO z2ui5_cl_ai_xml
        is_col     TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    METHODS render_cell
      IMPORTING
        io_cells TYPE REF TO z2ui5_cl_ai_xml
        is_col   TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    METHODS on_row_press
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS on_create
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_line_item_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    METHODS get_selection_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    METHODS get_row_key_fields
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS normalize_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_list_report IMPLEMENTATION.

  METHOD constructor.
    mv_cds_view = to_upper( cds_view_name ).
    mv_title = title.
    mv_max_rows = max_rows.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      ms_entity = z2ui5_cl_rap_util=>read_entity( mv_cds_view ).
      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name_plural IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name_plural.
        ELSE.
          mv_title = mv_cds_view.
        ENDIF.
      ENDIF.

      "init filter bar from @UI.selectionField
      LOOP AT get_selection_fields( ) INTO DATA(ls_sel).
        APPEND VALUE ty_s_filter(
          name  = ls_sel-name
          label = ls_sel-label ) TO mt_filter.
      ENDLOOP.

      mt_row_key = get_row_key_fields( ).

      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-refresh )
      OR client->check_on_event( cs_event-go ).
      load_data( ).
      client->view_model_update( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-row_press ).
      on_row_press( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-create ).
      on_create( client ).
      RETURN.
    ENDIF.

    "handle return from Object Page - refresh if data was saved
    IF client->check_on_navigated( ).
      IF client->check_app_prev_stack( ).
        TRY.
            DATA(lo_prev_op) = CAST z2ui5_cl_rap_object_page(
              client->get_app_prev( ) ).
            IF lo_prev_op->was_saved( ).
              load_data( ).
              client->message_toast_display( `Data refreshed` ).
            ENDIF.
          CATCH cx_sy_move_cast_error ##NO_HANDLER.
        ENDTRY.
      ENDIF.
      client->view_model_update( ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event.
    "subclass hook - the default only acknowledges the roundtrip
    client->view_model_update( ).
  ENDMETHOD.


  METHOD load_data.
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( mv_cds_view ) ).
        DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
        CREATE DATA mr_data TYPE HANDLE lo_table_type.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN mr_data->* TO <lt_data>.
        DATA(lv_where) = get_where_clause( ).
        SELECT * FROM (mv_cds_view)
          WHERE (lv_where)
          INTO TABLE @<lt_data>
          UP TO @mv_max_rows ROWS.
        mv_count = lines( <lt_data> ).
      CATCH cx_root.
        CLEAR mr_data.
        mv_count = `0`.
    ENDTRY.
  ENDMETHOD.


  METHOD get_where_clause.

    LOOP AT mt_filter INTO DATA(ls_filter) WHERE value IS NOT INITIAL.
      DATA(lv_value) = replace( val  = ls_filter-value
                                sub  = `'`
                                with = `''`
                                occ  = 0 ).
      READ TABLE ms_entity-fields INTO DATA(ls_field)
        WITH KEY name = ls_filter-name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_cond) = ``.
      CASE ls_field-type_kind.
        WHEN `CHAR` OR `STRING`.
          "wildcard search: user pattern via *, otherwise contains
          IF lv_value CS `*`.
            lv_value = replace( val  = lv_value
                                sub  = `*`
                                with = `%`
                                occ  = 0 ).
            lv_cond = |{ ls_filter-name } LIKE '{ lv_value }'|.
          ELSE.
            lv_cond = |{ ls_filter-name } LIKE '%{ lv_value }%'|.
          ENDIF.
        WHEN OTHERS.
          lv_cond = |{ ls_filter-name } = '{ lv_value }'|.
      ENDCASE.

      IF result IS INITIAL.
        result = lv_cond.
      ELSE.
        result = |{ result } AND { lv_cond }|.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_line_item_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY line_item_pos.

    "fallback: if no lineItem annotations, show all visible fields
    IF result IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false.
        APPEND ls_field TO result.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_selection_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_selection_field = abap_true.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY selection_field_pos.
  ENDMETHOD.


  METHOD get_row_key_fields.

    "prefer @ObjectModel.semanticKey, fallback to all line item columns
    LOOP AT ms_entity-semantic_key INTO DATA(lv_key).
      IF line_exists( ms_entity-fields[ name = lv_key ] ).
        APPEND lv_key TO result.
      ENDIF.
    ENDLOOP.

    IF result IS INITIAL.
      LOOP AT get_line_item_fields( ) INTO DATA(ls_field).
        APPEND ls_field-name TO result.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD normalize_value.
    "align ABAP and JSON model representations (dates, times, padding)
    result = val.
    REPLACE ALL OCCURRENCES OF `-` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `:` IN result WITH ``.
    CONDENSE result.
  ENDMETHOD.


  METHOD on_row_press.

    IF mr_data IS NOT BOUND OR mt_row_key IS INITIAL.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_match) = abap_true.
      DATA(lv_index) = 0.
      LOOP AT mt_row_key INTO DATA(lv_key).
        lv_index = lv_index + 1.
        ASSIGN COMPONENT lv_key OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
        IF sy-subrc <> 0
          OR normalize_value( CONV #( <lv_val> ) )
          <> normalize_value( client->get_event_arg( lv_index ) ).
          lv_match = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_match = abap_true.
        client->nav_app_call( NEW z2ui5_cl_rap_object_page( val = <ls_row> ) ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD on_create.

    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( mv_cds_view ) ).
        DATA lr_empty TYPE REF TO data.
        CREATE DATA lr_empty TYPE HANDLE lo_descr.
        FIELD-SYMBOLS <ls_empty> TYPE any.
        ASSIGN lr_empty->* TO <ls_empty>.
        client->nav_app_call(
          NEW z2ui5_cl_rap_object_page(
            val       = <ls_empty>
            title     = `Create ` && mv_title
            editable  = abap_true
            is_create = abap_true ) ).
      CATCH cx_root.
        client->message_box_display(
          text = `Cannot create entry for this entity`
          type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lo_view) = z2ui5_cl_ai_xml=>factory( ).

    DATA(lo_page) = lo_view->open( n  = `View`
                                   ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `displayBlock`
              v = `true`
        )->a( n = `height`
              v = `100%`

        )->open( `Shell`
            )->open( `Page`
                )->a( n = `title`
                      v = mv_title
                )->a( n = `showNavButton`
                      v = z2ui5_cl_ai_xml=>as_bool( client->check_app_prev_stack( ) )
                )->a( n = `navButtonPress`
                      v = client->_event( cs_event-back ) ).

    render_filter_bar( io_page = lo_page
                       client  = client ).

    render_table( io_page = lo_page
                  client  = client ).

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_filter_bar.

    IF mt_filter IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_bar) = io_page->open( `subHeader`
        )->open( `OverflowToolbar` ).

    DATA(lo_fbox) = lo_bar->open( `HBox`
        )->a( n = `items`
              v = client->_bind( mt_filter )
        )->a( n = `alignItems`
              v = `Center`
        )->a( n = `wrap`
              v = `Wrap` ).

    lo_fbox->leaf( `Input`
        )->a( n = `value`
              v = `{VALUE}`
        )->a( n = `placeholder`
              v = `{LABEL}`
        )->a( n = `submit`
              v = client->_event( cs_event-go )
        )->a( n = `width`
              v = `12rem`
        )->a( n = `class`
              v = `sapUiTinyMarginEnd` ).

    lo_bar->leaf( `ToolbarSpacer` ).

    lo_bar->leaf( `Button`
        )->a( n = `text`
              v = `Go`
        )->a( n = `type`
              v = `Emphasized`
        )->a( n = `press`
              v = client->_event( cs_event-go )
        )->a( n = `icon`
              v = `sap-icon://search` ).

  ENDMETHOD.


  METHOD render_table.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lt_columns) = get_line_item_fields( ).

    DATA(lo_table) = io_page->open( `Table`
        )->a( n = `items`
              v = `{path:'` && client->_bind( val  = <lt_data>
                                              path = abap_true ) && `'}`
        )->a( n = `growing`
              v = `true`
        )->a( n = `growingThreshold`
              v = `50`
        )->a( n = `sticky`
              v = `ColumnHeaders,HeaderToolbar`
        )->a( n = `mode`
              v = `None` ).

    render_toolbar( io_table = lo_table
                    client   = client ).

    DATA(lo_columns) = lo_table->open( `columns` ).
    LOOP AT lt_columns INTO DATA(ls_col).
      render_column( io_columns = lo_columns
                     is_col     = ls_col ).
    ENDLOOP.

    "items - row press navigates to a generated object page
    DATA(lo_items) = lo_table->open( `items` ).
    DATA lo_row TYPE REF TO z2ui5_cl_ai_xml.
    IF mt_row_key IS NOT INITIAL.
      DATA lt_arg TYPE string_table.
      LOOP AT mt_row_key INTO DATA(lv_key).
        APPEND `${` && lv_key && `}` TO lt_arg.
      ENDLOOP.
      lo_row = lo_items->open( `ColumnListItem`
          )->a( n = `type`
                v = `Navigation`
          )->a( n = `press`
                v = client->_event( val   = cs_event-row_press
                                    t_arg = lt_arg ) ).
    ELSE.
      lo_row = lo_items->open( `ColumnListItem` ).
    ENDIF.
    DATA(lo_cells) = lo_row->open( `cells` ).

    LOOP AT lt_columns INTO ls_col.
      render_cell( io_cells = lo_cells
                   is_col   = ls_col ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_toolbar.

    DATA(lo_toolbar) = io_table->open( `headerToolbar`
        )->open( `OverflowToolbar` ).

    lo_toolbar->leaf( `Title`
        )->a( n = `text`
              v = mv_title && ` (` && client->_bind( mv_count ) && `)` ).

    lo_toolbar->leaf( `ToolbarSpacer` ).

    lo_toolbar->leaf( `Button`
        )->a( n = `text`
              v = `Create`
        )->a( n = `press`
              v = client->_event( cs_event-create )
        )->a( n = `type`
              v = `Emphasized`
        )->a( n = `icon`
              v = `sap-icon://add` ).

    lo_toolbar->leaf( `Button`
        )->a( n = `icon`
              v = `sap-icon://refresh`
        )->a( n = `press`
              v = client->_event( cs_event-refresh ) ).

  ENDMETHOD.


  METHOD render_column.

    DATA(lv_col_label) = is_col-line_item_label.
    IF lv_col_label IS INITIAL.
      lv_col_label = is_col-label.
    ENDIF.

    "@UI.lineItem importance drives responsive popin behavior
    IF is_col-line_item_importance CS `MEDIUM`.
      io_columns->open( `Column`
          )->a( n = `minScreenWidth`
                v = `Tablet`
          )->a( n = `demandPopin`
                v = `true`
          )->leaf( `Text`
              )->a( n = `text`
                    v = lv_col_label ).
    ELSEIF is_col-line_item_importance CS `LOW`.
      io_columns->open( `Column`
          )->a( n = `minScreenWidth`
                v = `Desktop`
          )->a( n = `demandPopin`
                v = `true`
          )->leaf( `Text`
              )->a( n = `text`
                    v = lv_col_label ).
    ELSE.
      io_columns->open( `Column`
          )->leaf( `Text`
              )->a( n = `text`
                    v = lv_col_label ).
    ENDIF.

  ENDMETHOD.


  METHOD render_cell.

    DATA(lv_path) = `{` && is_col-name && `}`.

    "criticality -> ObjectStatus
    IF is_col-datapoint_crit_field IS NOT INITIAL
      OR is_col-line_item_crit_field IS NOT INITIAL.
      DATA(lv_crit_field) = is_col-line_item_crit_field.
      IF lv_crit_field IS INITIAL.
        lv_crit_field = is_col-datapoint_crit_field.
      ENDIF.
      io_cells->leaf( `ObjectStatus`
          )->a( n = `text`
                v = lv_path
          )->a( n = `state`
                v = `{= ${` && lv_crit_field &&
                    `} === 3 ? 'Success' : (${` && lv_crit_field &&
                    `} === 1 ? 'Error' : (${` && lv_crit_field &&
                    `} === 2 ? 'Warning' : 'None')) }` ).

    "amount + currency -> ObjectNumber
    ELSEIF is_col-is_amount_field = abap_true
      AND is_col-semantics_currency_code IS NOT INITIAL.
      io_cells->leaf( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = `{` && to_upper( is_col-semantics_currency_code ) && `}` ).

    "quantity + unit -> ObjectNumber
    ELSEIF is_col-is_quantity_field = abap_true
      AND is_col-semantics_unit_of_measure IS NOT INITIAL.
      io_cells->leaf( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = `{` && to_upper( is_col-semantics_unit_of_measure ) && `}` ).

    ELSE.
      io_cells->leaf( `Text`
          )->a( n = `text`
                v = lv_path ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
