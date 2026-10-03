"! Table select dialog for any CDS view - columns come from the entity
"! metadata, @ObjectModel.text.element adds description columns.
"!
"! The selection travels in a column of the rows (cv_select_column, bound to
"! the selected property of each item) - an event argument cannot carry it:
"! the confirm event's selectedItem is a control, which the frontend reduces
"! to its properties, and a binding context is not transportable at all.
"! Until 2026-09 the confirm read an event argument that was never sent, so
"! the value help returned nothing.
"!
"! The search field searches in the database (the searchable text fields,
"! see build_search_condition), not only in the rows already loaded.
"!
"! A value help entity with @UI.selectionField fields gets filter fields of
"! its own (since 2026-10): the dialog is then a sap.m.Dialog with a filter
"! bar and a table instead of the TableSelectDialog, which has no room for
"! them. The filter syntax is the list report's.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_value_help DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        confirm TYPE string VALUE `VH_CONFIRM`,
        cancel  TYPE string VALUE `VH_CANCEL`,
        search  TYPE string VALUE `VH_SEARCH`,
        "added 2026-10: Go of the filter bar
        go      TYPE string VALUE `VH_GO`,
      END OF cs_event.

    " a filter field of the dialog - one per @UI.selectionField
    TYPES:
      BEGIN OF ty_s_filter,
        name  TYPE string,
        label TYPE string,
        value TYPE string,
      END OF ty_s_filter.

    TYPES ty_t_filter TYPE STANDARD TABLE OF ty_s_filter WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        element       TYPE clike OPTIONAL
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 200
        multi_select  TYPE abap_bool DEFAULT abap_false
        filters       TYPE ty_t_name_value OPTIONAL
        search        TYPE string OPTIONAL.

    "! the first selected row, typed as the entity
    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the element value of the first selected row
    METHODS result_value
      RETURNING
        VALUE(result) TYPE string.

    "! every selected row, a table of the entity
    METHODS result_table
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the element value of every selected row
    METHODS result_values
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS was_confirmed
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS is_dropdown
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! why the value help closed without showing anything - the caller
    "! shows it (z2ui5_cl_rap_floorplan->get_value_help_result)
    METHODS load_error
      RETURNING
        VALUE(result) TYPE string.

    "! the rows the dialog shows - with the selection column
    DATA mr_data TYPE REF TO data.

    "! the selected rows after the confirm, a table of the entity. PUBLIC
    "! because the core carries a generic reference through the draft only
    "! as a public attribute - the caller reads it after nav_app_leave( )
    DATA mr_result_table TYPE REF TO data.

    "! the filter fields of the dialog (@UI.selectionField of the entity)
    DATA mt_filter TYPE ty_t_filter.
    "! the search field of the filter bar
    DATA mv_filter_search TYPE string.

  PROTECTED SECTION.
    DATA mv_cds_view   TYPE string.
    DATA mv_element    TYPE string.
    DATA mv_title      TYPE string.
    DATA mv_max_rows   TYPE i.
    DATA mv_confirmed  TYPE abap_bool.
    DATA ms_entity     TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mr_selected   TYPE REF TO data.
    DATA mv_result_val TYPE string.
    DATA mv_multi      TYPE abap_bool.
    DATA mt_filters    TYPE ty_t_name_value.
    DATA mv_search     TYPE string.
    DATA mt_result_values TYPE string_table.
    DATA mv_load_error TYPE string.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS load_data.

    "! the WHERE clause: the caller's filters and the search text
    METHODS get_where_clause
      RETURNING
        VALUE(result) TYPE string.

    METHODS render_dialog
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the dialog with a filter bar - when the entity has filter fields
    METHODS render_filter_dialog
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! read the selected rows into the results
    METHODS on_confirm
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_value_help IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-value_help.
    mv_cds_view = to_upper( cds_view_name ).
    mv_element = to_upper( element ).
    mv_title = title.
    mv_max_rows = max_rows.
    mv_multi = multi_select.
    mt_filters = filters.
    mv_search = search.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      ms_entity = z2ui5_cl_rap_util=>read_entity( mv_cds_view ).
      adjust_entity( CHANGING cs_entity = ms_entity ).
      IF mv_title IS INITIAL.
        mv_title = COND #( WHEN ms_entity-header_info-type_name_plural IS NOT INITIAL
                           THEN ms_entity-header_info-type_name_plural
                           ELSE ms_entity-name ).
      ENDIF.
      LOOP AT ms_entity-fields INTO DATA(ls_field)
        WHERE is_selection_field = abap_true AND filter_hidden = abap_false AND is_hidden = abap_false.
        APPEND VALUE #( name  = ls_field-name
                        label = ls_field-label
                        value = ls_field-filter_default ) TO mt_filter.
      ENDLOOP.
      IF mv_element IS INITIAL.
        "the key is what a value help returns - the first field otherwise
        IF ms_entity-keys IS NOT INITIAL.
          mv_element = ms_entity-keys[ 1 ].
        ELSEIF lines( ms_entity-fields ) > 0.
          mv_element = ms_entity-fields[ 1 ]-name.
        ENDIF.
      ENDIF.
      load_data( ).
      render_dialog( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-confirm ).
      on_confirm( client ).
      "a sap.m.Dialog does not close itself, the TableSelectDialog does
      IF mt_filter IS NOT INITIAL.
        client->popup_destroy( ).
      ENDIF.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      mv_confirmed = abap_false.
      IF mt_filter IS NOT INITIAL.
        client->popup_destroy( ).
      ENDIF.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-go ).
      mv_search = mv_filter_search.
      load_data( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-search ).
      "the new rows reach the open dialog with this roundtrip's model
      mv_search = client->get_event_arg( ).
      load_data( ).
      RETURN.
    ENDIF.

    "returning from a called app or a restored bookmark: check_on_init( ) is
    "false here and the browser still shows the OTHER app's view, so the view
    "has to be built again - a model push would reach nothing
    IF client->check_on_navigated( ).
      render_dialog( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD get_where_clause.

    DATA lt_and TYPE string_table.

    LOOP AT mt_filters INTO DATA(ls_filter) WHERE value IS NOT INITIAL.
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = to_upper( ls_filter-name ).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_cond) = build_filter_condition( is_field = ls_field
                                              value    = |={ ls_filter-value }| ).
      IF lv_cond IS NOT INITIAL.
        APPEND lv_cond TO lt_and.
      ENDIF.
    ENDLOOP.

    "the user's filter fields - the list report's syntax
    LOOP AT mt_filter INTO DATA(ls_user) WHERE value IS NOT INITIAL.
      READ TABLE ms_entity-fields INTO ls_field WITH KEY name = ls_user-name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_cond = build_filter_condition( is_field = ls_field
                                        value    = ls_user-value ).
      IF lv_cond IS NOT INITIAL.
        APPEND lv_cond TO lt_and.
      ENDIF.
    ENDLOOP.

    lv_cond = build_search_condition( it_fields = ms_entity-fields
                                      search    = mv_search ).
    IF lv_cond IS NOT INITIAL.
      APPEND lv_cond TO lt_and.
    ENDIF.

    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD load_data.
    mr_data = select_rows( entity_name    = mv_cds_view
                           where          = get_where_clause( )
                           max_rows       = mv_max_rows
                           with_selection = abap_true ).
  ENDMETHOD.


  METHOD on_confirm.

    FIELD-SYMBOLS <lt_selected> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_val> TYPE any.

    mv_confirmed = abap_true.
    CLEAR: mr_selected, mv_result_val, mt_result_values.

    mr_result_table = get_selected_rows( entity_name = mv_cds_view
                                         data        = mr_data ).
    IF mr_result_table IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_result_table->* TO <lt_selected>.

    LOOP AT <lt_selected> ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF mr_selected IS NOT BOUND.
        "typed by the entity's name - a named type survives the draft
        mr_selected = to_entity_row( entity_name = mv_cds_view
                                     row         = <ls_row> ).
      ENDIF.
      IF mv_element IS NOT INITIAL.
        ASSIGN COMPONENT mv_element OF STRUCTURE <ls_row> TO <lv_val>.
        IF sy-subrc = 0.
          APPEND |{ <lv_val> }| TO mt_result_values.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF mt_result_values IS NOT INITIAL.
      mv_result_val = mt_result_values[ 1 ].
    ENDIF.

  ENDMETHOD.


  METHOD render_dialog.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.

    IF mr_data IS NOT BOUND.
      "a message queued before nav_app_leave( ) never reaches the browser -
      "the caller reads load_error( ) and shows it
      mv_load_error = |{ get_text( cs_text-load_error ) }: { mv_cds_view }|.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF mt_filter IS NOT INITIAL.
      render_filter_dialog( client ).
      RETURN.
    ENDIF.

    ASSIGN mr_data->* TO <lt_data>.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`

        )->ele( `TableSelectDialog`
            )->a( n = `title`
                  t = mv_title
            )->a( n = `confirm`
                  v = client->_event( cs_event-confirm )
            )->a( n = `cancel`
                  v = client->_event( cs_event-cancel )
            )->a( n = `search`
                  v = client->_event( val = cs_event-search
                                      arg = `${$parameters>/value}` )
            )->a( n = `multiSelect`
                  b = mv_multi
            )->a( n = `growing`
                  b = abap_true
            )->a( n = `items`
                  v = `{path:'` && client->_bind( val  = <lt_data>
                                                  path = abap_true ) && `'}` ).

    DATA(lo_columns) = lo_dialog->ele( `columns` ).
    DATA(lo_cells) = lo_dialog->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `selected`
                  v = |\{{ cv_select_column }\}|
            )->ele( `cells` ).

    "render only visible, non-hidden fields
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_visible = abap_true AND is_hidden = abap_false.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = ls_field-label ).
      DATA(lv_path) = |\{{ ls_field-name }\}|.
      lo_cells->tag( `Text`
          )->a( n = `text`
                v = lv_path ).

      "if text element exists, add description column
      IF ls_field-text_element IS NOT INITIAL
        AND line_exists( ms_entity-fields[ name = ls_field-text_element ] ).
        DATA(lv_text_label) = ms_entity-fields[ name = ls_field-text_element ]-label.
        IF ms_entity-fields[ name = ls_field-text_element ]-is_visible = abap_true
          AND ms_entity-fields[ name = ls_field-text_element ]-is_hidden = abap_false.
          "rendered as a column of its own anyway
          CONTINUE.
        ENDIF.
        lo_columns->ele( `Column`
            )->tag( `Text`
                )->a( n = `text`
                      t = lv_text_label ).
        DATA(lv_text_path) = |\{{ ls_field-text_element }\}|.
        lo_cells->tag( `Text`
            )->a( n = `text`
                  v = lv_text_path ).
      ENDIF.
    ENDLOOP.

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD render_filter_dialog.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lv_mode) = `SingleSelectLeft`.
    IF mv_multi = abap_true.
      lv_mode = `MultiSelect`.
    ENDIF.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`

        )->ele( `Dialog`
            )->a( n = `title`
                  t = mv_title
            )->a( n = `contentWidth`
                  v = `60rem`
            )->a( n = `resizable`
                  v = `true`
            )->a( n = `draggable`
                  v = `true` ).

    "the filter bar: search, one input per filter field, Go
    DATA(lo_bar) = lo_dialog->ele( `subHeader`
        )->ele( `OverflowToolbar` ).
    lo_bar->tag( `SearchField`
        )->a( n = `value`
              v = client->_bind( mv_filter_search )
        )->a( n = `search`
              v = client->_event( cs_event-go )
        )->a( n = `width`
              v = `12rem` ).
    lo_bar->ele( `HBox`
        )->a( n = `items`
              v = client->_bind( mt_filter )
        )->a( n = `alignItems`
              v = `Center`
        )->tag( `Input`
            )->a( n = `value`
                  v = `{VALUE}`
            )->a( n = `placeholder`
                  v = `{LABEL}`
            )->a( n = `tooltip`
                  t = get_text( cs_text-filter_hint )
            )->a( n = `submit`
                  v = client->_event( cs_event-go )
            )->a( n = `width`
                  v = `10rem`
            )->a( n = `class`
                  v = `sapUiTinyMarginBegin` ).
    lo_bar->tag( `ToolbarSpacer` ).
    lo_bar->tag( `Button`
        )->a( n = `text`
              t = get_text( cs_text-go )
        )->a( n = `type`
              v = `Emphasized`
        )->a( n = `press`
              v = client->_event( cs_event-go ) ).

    DATA(lo_table) = lo_dialog->ele( `content`
        )->ele( `Table`
            )->a( n = `items`
                  v = `{path:'` && client->_bind( val  = <lt_data>
                                                  path = abap_true ) && `'}`
            )->a( n = `mode`
                  v = lv_mode
            )->a( n = `growing`
                  v = `true` ).

    DATA(lo_columns) = lo_table->ele( `columns` ).
    DATA(lo_cells) = lo_table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `selected`
                  v = |\{{ cv_select_column }\}|
            )->ele( `cells` ).
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_visible = abap_true AND is_hidden = abap_false.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = ls_field-label ).
      DATA(lv_path) = |\{{ ls_field-name }\}|.
      lo_cells->tag( `Text`
          )->a( n = `text`
                v = lv_path ).
    ENDLOOP.

    lo_dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-ok )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `press`
                  v = client->_event( cs_event-confirm ) ).
    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD result.
    result = mr_selected.
  ENDMETHOD.


  METHOD result_value.
    result = mv_result_val.
  ENDMETHOD.


  METHOD result_table.
    result = mr_result_table.
  ENDMETHOD.


  METHOD result_values.
    result = mt_result_values.
  ENDMETHOD.


  METHOD was_confirmed.
    result = mv_confirmed.
  ENDMETHOD.


  METHOD is_dropdown.
    result = ms_entity-is_dropdown.
  ENDMETHOD.


  METHOD load_error.
    result = mv_load_error.
  ENDMETHOD.

ENDCLASS.
