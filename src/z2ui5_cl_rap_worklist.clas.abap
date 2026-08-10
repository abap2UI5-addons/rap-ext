"! Read-only worklist table of a CDS view with @UI.lineItem columns.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_worklist DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        refresh TYPE string VALUE `REFRESH`,
        back    TYPE string VALUE `BACK`,
      END OF cs_event.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500.

    DATA mv_cds_view  TYPE string.
    DATA mv_title     TYPE string.
    DATA mv_max_rows  TYPE i.
    DATA ms_entity    TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mr_data      TYPE REF TO data.
    DATA mv_search    TYPE string.

  PROTECTED SECTION.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS load_data.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_line_item_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_worklist IMPLEMENTATION.

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
      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-refresh ).
      load_data( ).
      client->view_model_update( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD load_data.
    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr(
          cl_abap_typedescr=>describe_by_name( mv_cds_view ) ).
        DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
        CREATE DATA mr_data TYPE HANDLE lo_table_type.
        FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
        ASSIGN mr_data->* TO <lt_data>.
        SELECT * FROM (mv_cds_view) INTO TABLE @<lt_data>
          UP TO @mv_max_rows ROWS.
      CATCH cx_root.
        CLEAR mr_data.
    ENDTRY.
  ENDMETHOD.


  METHOD get_line_item_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY line_item_pos.
    IF result IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false.
        APPEND ls_field TO result.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lt_columns) = get_line_item_fields( ).
    DATA(lv_count) = CONV string( lines( <lt_data> ) ).

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

    "table
    DATA(lo_table) = lo_page->open( `Table`
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

    "toolbar
    lo_table->open( `headerToolbar`
        )->open( `OverflowToolbar`
            )->leaf( `Title`
                )->a( n = `text`
                      v = |{ mv_title } ({ lv_count })|
            )->leaf( `ToolbarSpacer`
            )->leaf( `Button`
                )->a( n = `icon`
                      v = `sap-icon://refresh`
                )->a( n = `press`
                      v = client->_event( cs_event-refresh ) ).

    "columns
    DATA(lo_columns) = lo_table->open( `columns` ).
    LOOP AT lt_columns INTO DATA(ls_col).
      DATA(lv_col_label) = ls_col-line_item_label.
      IF lv_col_label IS INITIAL.
        lv_col_label = ls_col-label.
      ENDIF.
      lo_columns->open( `Column`
          )->leaf( `Text`
              )->a( n = `text`
                    v = lv_col_label ).
    ENDLOOP.

    "items
    DATA(lo_cells) = lo_table->open( `items`
        )->open( `ColumnListItem`
            )->open( `cells` ).

    LOOP AT lt_columns INTO ls_col.
      lo_cells->leaf( `Text`
          )->a( n = `text`
                v = `{` && ls_col-name && `}` ).
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
