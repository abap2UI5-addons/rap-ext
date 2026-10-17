"! Fiori-Elements-style list report generated from the annotations of a
"! CDS view - columns, filter bar, value helps, criticality, units, actions
"! and row navigation all come from the metadata (see README).
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event, so a subclass adds its
"! own actions the same way any abap2UI5 app handles them.
"!
"! The data source is always a CDS view with UI annotations - the abap2UI5
"! core ships no list report over a plain internal table (see README).
CLASS z2ui5_cl_rap_list_report DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_filter,
        name    TYPE string,
        label   TYPE string,
        value   TYPE string,
        "the field has a value help - the input shows its button
        show_vh TYPE abap_bool,
        "added 2026-10 (@Consumption.filter): a value is required before
        "the list loads; single - one value, the value help selects one
        mandatory TYPE abap_bool,
        single    TYPE abap_bool,
        "@Consumption.filter.hidden: not shown, its default still applies
        hidden    TYPE abap_bool,
      END OF ty_s_filter.

    TYPES ty_t_filter TYPE STANDARD TABLE OF ty_s_filter WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF cs_event,
        refresh    TYPE string VALUE `REFRESH`,
        go         TYPE string VALUE `GO`,
        row_press  TYPE string VALUE `ROW_PRESS`,
        back       TYPE string VALUE `BACK`,
        create     TYPE string VALUE `CREATE`,
        value_help TYPE string VALUE `FILTER_VALUE_HELP`,
        action     TYPE string VALUE `ACTION`,
        search     TYPE string VALUE `SEARCH`,
        sort       TYPE string VALUE `SORT`,
        sort_dir   TYPE string VALUE `SORT_DIRECTION`,
        more       TYPE string VALUE `MORE`,
        "added 2026-10
        nav_path   TYPE string VALUE `NAV_PATH`,
        intent     TYPE string VALUE `INTENT`,
        export     TYPE string VALUE `EXPORT`,
        variant_select    TYPE string VALUE `VARIANT_SELECT`,
        variant_save_open TYPE string VALUE `VARIANT_SAVE_OPEN`,
        variant_save      TYPE string VALUE `VARIANT_SAVE`,
        variant_delete    TYPE string VALUE `VARIANT_DELETE`,
        columns           TYPE string VALUE `COLUMNS`,
        columns_ok        TYPE string VALUE `COLUMNS_OK`,
        popup_cancel      TYPE string VALUE `POPUP_CANCEL`,
        "added 2026-10, third round: the selection of the rows changed -
        "the toolbar actions follow the selected rows' feature control
        selection_change  TYPE string VALUE `SELECTION_CHANGE`,
      END OF cs_event.

    "! the key of the standard view - the annotations' filters, sort order
    "! and columns
    CONSTANTS cv_variant_standard TYPE string VALUE `*STANDARD*`.

    " an entry of the views select, a row of the columns dialog
    TYPES:
      BEGIN OF ty_s_variant_item,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_variant_item.

    TYPES ty_t_variant_item TYPE STANDARD TABLE OF ty_s_variant_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_column,
        name    TYPE string,
        label   TYPE string,
        visible TYPE abap_bool,
      END OF ty_s_column.

    TYPES ty_t_column TYPE STANDARD TABLE OF ty_s_column WITH EMPTY KEY.

    "! the most rows an export writes
    CONSTANTS cv_export_max TYPE i VALUE 10000.

    " the columns a row of a RAP business object gets (added 2026-10,
    " third round): its draft status (z2ui5_cl_rap_util=>cs_editing_status)
    " and its text, and whether an inline action is enabled - the prefix
    " and the action's position
    CONSTANTS:
      BEGIN OF cs_row_column,
        draft         TYPE string VALUE `ZZDRAFT`,
        draft_text    TYPE string VALUE `ZZDRAFT_TEXT`,
        action_prefix TYPE string VALUE `ZZACTION_`,
      END OF cs_row_column.

    " a toolbar action and whether the selected rows allow it
    TYPES:
      BEGIN OF ty_s_action_state,
        name    TYPE string,
        enabled TYPE abap_bool,
      END OF ty_s_action_state.

    TYPES ty_t_action_state TYPE STANDARD TABLE OF ty_s_action_state WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500.

    "! the number of rows that match the filters (not only the loaded ones)
    DATA mv_count    TYPE string.
    "! the rows - with the selection column when the entity has actions
    DATA mr_data     TYPE REF TO data.
    DATA mt_filter   TYPE ty_t_filter.
    "! the free-text search (the worklist renders a field for it)
    DATA mv_search   TYPE string.

    TYPES:
      BEGIN OF ty_s_sort_field,
        name  TYPE string,
        label TYPE string,
      END OF ty_s_sort_field.

    TYPES ty_t_sort_field TYPE STANDARD TABLE OF ty_s_sort_field WITH DEFAULT KEY.

    "! the field the rows are sorted by (in the database) - the first
    "! of @UI.presentationVariant's sortOrder until the user picks another
    DATA mv_sort_field TYPE string.
    "! the fields the sort select offers - the columns
    DATA mt_sort_field TYPE ty_t_sort_field.
    "! more rows match than are loaded - the "more" button shows
    DATA mv_more       TYPE abap_bool.

    "! the views of the user (z2ui5_cl_rap_variant) and the selected one -
    "! empty when the system has no table for them
    DATA mt_variant_item   TYPE ty_t_variant_item.
    DATA mv_variant        TYPE string.
    "! the dialog that saves a view
    DATA mv_variant_name    TYPE string.
    DATA mv_variant_default TYPE abap_bool.
    "! the dialog that shows and hides columns
    DATA mt_column TYPE ty_t_column.

    "! the editing status filter of a draft business object
    "! (z2ui5_cl_rap_util=>cs_editing_status) and its entries
    DATA mv_editing_status TYPE string.
    DATA mt_editing_status TYPE ty_t_variant_item.

  PROTECTED SECTION.
    DATA mv_cds_view TYPE string.
    DATA mv_title    TYPE string.
    DATA mv_max_rows TYPE i.
    DATA ms_entity   TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    DATA mt_row_key TYPE string_table.
    "! the sort direction - shown by the icon of the direction button
    DATA mv_sort_desc TYPE abap_bool.
    "! the rows one "more" adds - the max_rows the list report started with
    DATA mv_page_size TYPE i.

    "! what the entity lets the user write (create button, actions)
    DATA ms_caps TYPE ty_s_capabilities.
    "! an action waiting for its parameter dialog to return
    DATA mv_pending_action TYPE string.
    "! the keys of the row an inline action was pressed on - empty for a
    "! toolbar action, which runs on the selected rows
    DATA mt_pending_keys TYPE string_table.
    "! the last action created a record and its object page was called -
    "! nothing else is rendered in this roundtrip (added 2026-10, third
    "! round)
    DATA mv_opened_created TYPE abap_bool.

    "! the columns the user hid (the columns dialog, a view)
    DATA mt_hidden_column TYPE string_table.
    "! the saved views, and the standard view as the list started (taken
    "! once, before a view applied)
    DATA mt_variants TYPE z2ui5_cl_rap_variant=>ty_t_variant.
    DATA ms_standard TYPE z2ui5_cl_rap_variant=>ty_s_data.
    "! what GET PERMISSIONS answers for the loaded rows (added 2026-10,
    "! third round)
    DATA ms_perm TYPE ty_s_permissions.
    "! the entity is the root of a draft business object
    DATA mv_is_draft_bo TYPE abap_bool.
    "! the toolbar actions, enabled by the feature control of the selected
    "! rows (update_action_state)
    DATA mt_action_state TYPE ty_t_action_state.

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

    "! the WHERE of the filter bar alone - what get_where_clause( ) returns
    "! here; a subclass that redefines get_where_clause( ) reads it to get
    "! the filters without its own additions
    METHODS get_filter_where_clause
      RETURNING
        VALUE(result) TYPE string.

    "! the ORDER BY of load_data: the sort field, then the keys, so that a
    "! page of rows is the same page on every load
    METHODS get_order_by
      RETURNING
        VALUE(result) TYPE string.

    "! the sort select and direction button - in the table's toolbar
    METHODS render_sort_controls
      IMPORTING
        io_toolbar TYPE REF TO z2ui5_cl_ui5_view_builder
        client     TYPE REF TO z2ui5_if_client.

    "! page skeleton - delegates to render_filter_bar and render_table
    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_filter_bar
      IMPORTING
        io_page TYPE REF TO z2ui5_cl_ui5_view_builder
        client  TYPE REF TO z2ui5_if_client.

    METHODS render_table
      IMPORTING
        io_page TYPE REF TO z2ui5_cl_ui5_view_builder
        client  TYPE REF TO z2ui5_if_client.

    METHODS render_toolbar
      IMPORTING
        io_table TYPE REF TO z2ui5_cl_ui5_view_builder
        client   TYPE REF TO z2ui5_if_client.

    METHODS render_column
      IMPORTING
        io_columns TYPE REF TO z2ui5_cl_ui5_view_builder
        is_col     TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    "! the cell of a column - client (added 2026-10) is needed for the
    "! links of a #WITH_NAVIGATION_PATH or #WITH_INTENT_BASED_NAVIGATION
    "! column, which are plain text without it
    METHODS render_cell
      IMPORTING
        io_cells TYPE REF TO z2ui5_cl_ui5_view_builder
        is_col   TYPE z2ui5_cl_rap_util=>ty_s_field_info
        client   TYPE REF TO z2ui5_if_client OPTIONAL.

    METHODS on_row_press
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS on_create
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a toolbar or inline action - asks for the parameter first when the
    "! action has one
    METHODS on_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! run the pending action on its rows, param is its parameter - a
    "! static action runs without rows, and the record a factory action
    "! created opens (open_created)
    METHODS execute_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        param  TYPE REF TO data OPTIONAL.

    "! the buttons of it_actions, by position (get_action_entries): a
    "! button per action, its criticality its type, and a MenuButton per
    "! action group with its actions as items. The press is event with
    "! the arguments args_before and the action's name; row decides a
    "! criticality that names a field (added 2026-10, third round)
    METHODS render_action_buttons
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        it_actions   TYPE z2ui5_cl_rap_util=>ty_t_action
        it_groups    TYPE z2ui5_cl_rap_util=>ty_t_action_group OPTIONAL
        client       TYPE REF TO z2ui5_if_client
        event        TYPE string
        args_before  TYPE string_table OPTIONAL
        row          TYPE data OPTIONAL
        "added 2026-10, third round: a button's enabled by the action
        "(name, value: true, false or a binding)
        enabled_values TYPE ty_t_name_value OPTIONAL.

    "! the object page of the record an action created (its MAPPED keys)
    METHODS open_created
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        keys   TYPE ty_t_name_value.

    "! after a load of a RAP business object: its permissions (ms_perm),
    "! the enabled inline actions and the draft status of every row (the
    "! columns cs_row_column), the editing status filter applied, the
    "! toolbar actions' state (added 2026-10, third round, like the
    "! methods below)
    METHODS apply_row_states.

    "! the draft status of the rows of data: from the draft fields the
    "! entity has (HASDRAFTENTITY, DRAFTENTITYLASTCHANGEDBY), else from
    "! their drafts read back - another user's by who changed it last
    METHODS fill_draft_status
      IMPORTING
        data TYPE REF TO data.

    "! the toolbar actions enabled for the selected rows (mt_action_state):
    "! the global permission, and every selected row's own
    METHODS update_action_state.

    "! whether each toolbar action is enabled - mt_action_state as the
    "! values of render_action_buttons' enabled_values
    METHODS get_action_enabled
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the rows (mr_data) have the column name
    METHODS has_row_column
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the return from a called app: value help, action dialog, object page
    METHODS on_navigated
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

    "! the actions of @UI.lineItem - inline ones render per row
    METHODS get_line_item_actions
      IMPORTING
        inline        TYPE abap_bool
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_action.

    "! the #FOR_INTENT_BASED_NAVIGATION entries of @UI.lineItem - toolbar
    "! buttons that navigate in the launchpad
    METHODS get_line_item_intents
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_action.

    "! every row that matches the filters (up to cv_export_max) with the
    "! visible columns, as a CSV file the browser downloads
    METHODS on_export
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the export button - in the table's toolbar
    METHODS render_export_button
      IMPORTING
        io_toolbar TYPE REF TO z2ui5_cl_ui5_view_builder
        client     TYPE REF TO z2ui5_if_client.

    "! the columns of the table - the line item without the hidden ones
    METHODS get_visible_columns
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! read the user's views, apply the default one
    METHODS init_variants.

    "! filters, search, sort order and hidden columns as they are now
    METHODS capture_variant
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_variant=>ty_s_data.

    METHODS apply_variant
      IMPORTING
        is_data TYPE z2ui5_cl_rap_variant=>ty_s_data.

    "! the views select, save, delete and the columns button - in the
    "! table's toolbar, when the system keeps views
    METHODS render_variant_controls
      IMPORTING
        io_toolbar TYPE REF TO z2ui5_cl_ui5_view_builder
        client     TYPE REF TO z2ui5_if_client.

    "! the dialog that saves the current view under a name
    METHODS render_variant_popup
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the dialog that shows and hides columns
    METHODS render_column_popup
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the events of the views and the columns dialog - abap_true when the
    "! event was one of them
    METHODS on_variant_event
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the labels of the mandatory filters (@Consumption.filter.mandatory)
    "! that have no value
    METHODS get_missing_filters
      RETURNING
        VALUE(result) TYPE string_table.

    "! the link of a #WITH_NAVIGATION_PATH column: the object page of the
    "! record the association leads to
    METHODS on_nav_path
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a launchpad navigation: a #FOR_INTENT_BASED_NAVIGATION button, or
    "! the link of a #WITH_INTENT_BASED_NAVIGATION column with its value and
    "! the row's keys as parameters
    METHODS on_intent
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS normalize_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_list_report IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-list_report.
    mv_cds_view = to_upper( cds_view_name ).
    mv_title = title.
    mv_max_rows = max_rows.
    mv_page_size = max_rows.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      ms_entity = z2ui5_cl_rap_util=>read_entity( mv_cds_view ).
      adjust_entity( CHANGING cs_entity = ms_entity ).
      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name_plural IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name_plural.
        ELSE.
          mv_title = mv_cds_view.
        ENDIF.
      ENDIF.

      "init filter bar from @UI.selectionField - a mandatory one is marked
      LOOP AT get_selection_fields( ) INTO DATA(ls_sel).
        APPEND VALUE ty_s_filter(
          name      = ls_sel-name
          label     = COND #( WHEN ls_sel-filter_mandatory = abap_true THEN |{ ls_sel-label } *| ELSE ls_sel-label )
          value     = ls_sel-filter_default
          show_vh   = xsdbool( ls_sel-value_help-entity_name IS NOT INITIAL )
          mandatory = ls_sel-filter_mandatory
          single    = ls_sel-filter_single
          hidden    = ls_sel-filter_hidden ) TO mt_filter.
      ENDLOOP.

      mt_row_key = get_row_key_fields( ).
      ms_caps = get_entity_capabilities( mv_cds_view ).
      "a draft business object: the draft of each row, and a filter by it
      IF ms_caps-is_rap_bo = abap_true AND is_draft_enabled( mv_cds_view ) = abap_true.
        mv_is_draft_bo = abap_true.
        mv_editing_status = z2ui5_cl_rap_util=>cs_editing_status-all.
        mt_editing_status = VALUE #(
          ( key = z2ui5_cl_rap_util=>cs_editing_status-all       text = get_text( cs_text-all ) )
          ( key = z2ui5_cl_rap_util=>cs_editing_status-own_draft text = get_text( cs_text-own_drafts ) )
          ( key = z2ui5_cl_rap_util=>cs_editing_status-locked    text = get_text( cs_text-locked_other ) )
          ( key = z2ui5_cl_rap_util=>cs_editing_status-unchanged text = get_text( cs_text-unchanged ) ) ).
      ENDIF.
      "@UI.createHidden: true - a path has no record to ask in a list
      IF is_hidden_by_annotation( ms_entity-create_hidden ) = abap_true.
        ms_caps-can_create = abap_false.
      ENDIF.

      "sortable: the columns that are text, numbers or dates - a virtual
      "element only with a sort transformation
      LOOP AT get_line_item_fields( ) INTO DATA(ls_col).
        IF z2ui5_cl_rap_util=>is_sortable( ls_col ) = abap_false.
          CONTINUE.
        ENDIF.
        APPEND VALUE #( name  = ls_col-name
                        label = COND #( WHEN ls_col-line_item_label IS NOT INITIAL THEN ls_col-line_item_label
                                        ELSE ls_col-label ) ) TO mt_sort_field.
      ENDLOOP.
      IF ms_entity-sort_order IS NOT INITIAL
        AND line_exists( mt_sort_field[ name = ms_entity-sort_order[ 1 ]-field ] ).
        mv_sort_field = ms_entity-sort_order[ 1 ]-field.
        mv_sort_desc = ms_entity-sort_order[ 1 ]-descending.
      ENDIF.

      "the standard view: the annotations' filters, sort order, columns
      ms_standard = capture_variant( ).
      init_variants( ).
      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-refresh )
      OR client->check_on_event( cs_event-go )
      OR client->check_on_event( cs_event-search )
      OR client->check_on_event( cs_event-sort ).
      "the rows of a mandatory filter only - none without its value
      DATA(lt_missing) = get_missing_filters( ).
      IF lt_missing IS NOT INITIAL.
        client->message_box_display(
          text = |{ get_text( cs_text-required ) }: { concat_lines_of( table = lt_missing sep = `, ` ) }|
          type = `warning` ).
      ENDIF.
      load_data( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-sort_dir ).
      mv_sort_desc = xsdbool( mv_sort_desc = abap_false ).
      load_data( ).
      "the button's icon shows the direction - built into the view
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-more ).
      "the next rows - loaded from the database, not only shown
      mv_max_rows = mv_max_rows + mv_page_size.
      load_data( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-row_press ).
      on_row_press( client ).
      RETURN.
    ENDIF.

    "the toolbar buttons follow the selected rows - built into the view
    IF client->check_on_event( cs_event-selection_change ).
      update_action_state( ).
      render_page( client ).
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

    IF client->check_on_event( cs_event-value_help ).
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0.
        open_value_help( client       = client
                         is_field     = ls_field
                         multi_select = xsdbool( ls_field-filter_single = abap_false ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-nav_path ).
      on_nav_path( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-intent ).
      on_intent( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-export ).
      on_export( client ).
      RETURN.
    ENDIF.

    IF on_variant_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-action ).
      on_action( client ).
      RETURN.
    ENDIF.

    IF client->check_on_navigated( ).
      on_navigated( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event.
    "subclass hook - the default does nothing: the framework pushes the model
    "by itself whenever a roundtrip changed it
    RETURN.
  ENDMETHOD.


  METHOD on_navigated.

    "back from the value help of a filter: its values, exact
    DATA(lo_vh) = get_value_help_result( client ).
    IF lo_vh IS BOUND.
      READ TABLE mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>) WITH KEY name = mv_vh_target.
      IF sy-subrc = 0.
        DATA lt_exact TYPE string_table.
        LOOP AT lo_vh->result_values( ) INTO DATA(lv_value).
          APPEND |={ lv_value }| TO lt_exact.
        ENDLOOP.
        <ls_filter>-value = concat_lines_of( table = lt_exact sep = `;` ).
      ENDIF.
      CLEAR mv_vh_target.
      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.
    CLEAR mv_vh_target.

    "what came back is decided by what this app called, not by
    "check_app_prev_stack( ) - that answers whether this app has a caller,
    "and a root list report has none

    "back from the parameter dialog of an action
    IF mv_pending_action IS NOT INITIAL.
      TRY.
          DATA(lo_dialog) = CAST z2ui5_cl_rap_action_dialog( client->get_app_prev( ) ).
          IF lo_dialog->was_confirmed( ).
            execute_action( client = client
                            param  = lo_dialog->result( ) ).
          ENDIF.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
      CLEAR: mv_pending_action, mt_pending_keys.
      "the action created a record - its object page is on its way
      IF mv_opened_created = abap_true.
        CLEAR mv_opened_created.
        RETURN.
      ENDIF.
    ENDIF.

    "back from the object page - refresh if data was saved
    TRY.
        DATA(lo_prev_op) = CAST z2ui5_cl_rap_object_page( client->get_app_prev( ) ).
        IF lo_prev_op->was_saved( ).
          load_data( ).
          client->message_toast_display( get_text( cs_text-refreshed ) ).
        ENDIF.
      "a cast error, or a previous app the draft no longer has
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    render_page( client ).

  ENDMETHOD.


  METHOD load_data.

    "a mandatory filter without a value: no rows until it has one
    IF get_missing_filters( ) IS NOT INITIAL.
      mr_data = create_entity_table(
        entity_name    = mv_cds_view
        with_selection = xsdbool( get_line_item_actions( abap_false ) IS NOT INITIAL ) ).
      mv_count = `0`.
      mv_more = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_where) = get_where_clause( ).
    mr_data = select_rows(
      entity_name    = mv_cds_view
      where          = lv_where
      max_rows       = mv_max_rows
      with_selection = xsdbool( get_line_item_actions( abap_false ) IS NOT INITIAL )
      order_by       = get_order_by( ) ).
    IF mr_data IS BOUND.
      DATA(lv_count) = count_rows( entity_name = mv_cds_view
                                   where       = lv_where ).
      mv_count = |{ lv_count }|.
      FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
      ASSIGN mr_data->* TO <lt_data>.
      mv_more = xsdbool( lv_count > lines( <lt_data> ) ).
      apply_row_states( ).
    ELSE.
      mv_count = `0`.
      mv_more = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD get_where_clause.

    result = get_filter_where_clause( ).

  ENDMETHOD.


  METHOD get_filter_where_clause.

    DATA lt_and TYPE string_table.

    LOOP AT mt_filter INTO DATA(ls_filter) WHERE value IS NOT INITIAL.
      READ TABLE ms_entity-fields INTO DATA(ls_field)
        WITH KEY name = ls_filter-name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_cond) = build_filter_condition( is_field = ls_field
                                              value    = ls_filter-value ).
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


  METHOD get_order_by.

    DATA lt_order TYPE string_table.
    DATA lt_used TYPE string_table.

    "only a field the sort select offers - a STRING (LOB) column in an
    "ORDER BY is invalid SQL and would empty the whole list
    IF mv_sort_field IS NOT INITIAL AND line_exists( mt_sort_field[ name = mv_sort_field ] ).
      APPEND |{ mv_sort_field }{ COND #( WHEN mv_sort_desc = abap_true THEN ` DESCENDING` ELSE `` ) }| TO lt_order.
      APPEND mv_sort_field TO lt_used.
    ENDIF.
    "then by the rest of @UI.presentationVariant, then by the keys - every
    "key that is not in the list yet, so a page is the same page each time
    LOOP AT ms_entity-sort_order INTO DATA(ls_sort).
      IF line_exists( lt_used[ table_line = ls_sort-field ] )
        OR NOT line_exists( mt_sort_field[ name = ls_sort-field ] ).
        CONTINUE.
      ENDIF.
      APPEND |{ ls_sort-field }{ COND #( WHEN ls_sort-descending = abap_true THEN ` DESCENDING` ELSE `` ) }| TO lt_order.
      APPEND ls_sort-field TO lt_used.
    ENDLOOP.
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      IF line_exists( lt_used[ table_line = lv_key ] ).
        CONTINUE.
      ENDIF.
      READ TABLE ms_entity-fields INTO DATA(ls_key_field) WITH KEY name = lv_key.
      IF sy-subrc = 0 AND ls_key_field-type_kind <> `STRING` AND ls_key_field-is_virtual = abap_false.
        APPEND lv_key TO lt_order.
        APPEND lv_key TO lt_used.
      ENDIF.
    ENDLOOP.

    result = concat_lines_of( table = lt_order sep = `, ` ).

  ENDMETHOD.


  METHOD render_sort_controls.

    IF mt_sort_field IS INITIAL.
      RETURN.
    ENDIF.

    "the core prefix is declared here, so no view has to carry it
    io_toolbar->ele( `Select`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->a( n = `selectedKey`
              v = client->_bind( mv_sort_field )
        )->a( n = `items`
              v = client->_bind( mt_sort_field )
        )->a( n = `change`
              v = client->_event( cs_event-sort )
        )->a( n = `forceSelection`
              v = `false`
        )->a( n = `tooltip`
              t = get_text( cs_text-sort )
        )->tag( n  = `Item`
                ns = `core`
            )->a( n = `key`
                  v = `{NAME}`
            )->a( n = `text`
                  v = `{LABEL}` ).

    DATA(lv_icon) = `sap-icon://sort-ascending`.
    IF mv_sort_desc = abap_true.
      lv_icon = `sap-icon://sort-descending`.
    ENDIF.
    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = lv_icon
        )->a( n = `tooltip`
              t = get_text( cs_text-sort )
        )->a( n = `press`
              v = client->_event( cs_event-sort_dir ) ).

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
    "a virtual element has no column to filter (is_filterable)
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_selection_field = abap_true AND is_virtual = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY selection_field_pos.
  ENDMETHOD.


  METHOD get_row_key_fields.

    "the keys of the entity (DDIC keys, else @ObjectModel.semanticKey),
    "fallback to all line item columns
    LOOP AT ms_entity-keys INTO DATA(lv_key).
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


  METHOD get_line_item_actions.
    "actions exist only on a RAP business object
    IF ms_caps-is_rap_bo = abap_false.
      RETURN.
    ENDIF.
    LOOP AT ms_entity-actions INTO DATA(ls_action)
      WHERE source = `LINEITEM` AND inline = inline AND semantic_object IS INITIAL.
      APPEND ls_action TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_line_item_intents.
    LOOP AT ms_entity-actions INTO DATA(ls_action)
      WHERE source = `LINEITEM` AND semantic_object IS NOT INITIAL.
      APPEND ls_action TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_export.

    IF get_missing_filters( ) IS NOT INITIAL.
      RETURN.
    ENDIF.
    "every matching row, not only the loaded ones - in the list's order
    DATA(lr_rows) = select_rows( entity_name = mv_cds_view
                                 where       = get_where_clause( )
                                 max_rows    = cv_export_max
                                 order_by    = get_order_by( ) ).
    IF lr_rows IS NOT BOUND.
      client->message_box_display( text = get_load_error( mv_cds_view )
                                   type = `error` ).
      RETURN.
    ENDIF.

    DATA(lv_csv) = z2ui5_cl_rap_util=>to_csv( data      = lr_rows
                                              it_fields = get_visible_columns( ) ).
    DATA(lv_base64) = z2ui5_cl_rap_util=>base64_encode( z2ui5_cl_rap_util=>to_utf8( val = lv_csv
                                                                                    bom = abap_true ) ).
    DATA(lv_name) = replace( val = mv_cds_view sub = `/` with = `_` occ = 0 ).
    client->follow_up_action( val   = client->cs_event-download_b64_file
                              t_arg = VALUE #( ( |data:text/csv;charset=utf-8;base64,{ lv_base64 }| )
                                               ( |{ to_lower( lv_name ) }.csv| ) ) ).

  ENDMETHOD.


  METHOD render_export_button.
    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://excel-attachment`
        )->a( n = `tooltip`
              t = get_text( cs_text-export )
        )->a( n = `press`
              v = client->_event( cs_event-export ) ).
  ENDMETHOD.


  METHOD get_visible_columns.
    result = get_line_item_fields( ).
    LOOP AT mt_hidden_column INTO DATA(lv_hidden).
      DELETE result WHERE name = lv_hidden.
    ENDLOOP.
    "never no column at all
    IF result IS INITIAL.
      result = get_line_item_fields( ).
    ENDIF.
  ENDMETHOD.


  METHOD init_variants.

    CLEAR: mt_variant_item, mt_variants, mv_variant.
    IF z2ui5_cl_rap_variant=>is_available( ) = abap_false.
      RETURN.
    ENDIF.
    mt_variants = z2ui5_cl_rap_variant=>read_all( mv_cds_view ).

    mv_variant = cv_variant_standard.
    APPEND VALUE #( key = cv_variant_standard text = get_text( cs_text-standard ) ) TO mt_variant_item.
    LOOP AT mt_variants INTO DATA(ls_variant).
      APPEND VALUE #( key = ls_variant-name text = ls_variant-name ) TO mt_variant_item.
      IF ls_variant-is_default = abap_true.
        mv_variant = ls_variant-name.
        apply_variant( ls_variant-data ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD capture_variant.
    LOOP AT mt_filter INTO DATA(ls_filter).
      APPEND VALUE #( name = ls_filter-name value = ls_filter-value ) TO result-filters.
    ENDLOOP.
    result-search = mv_search.
    result-sort_field = mv_sort_field.
    result-sort_desc = mv_sort_desc.
    result-hidden_columns = mt_hidden_column.
  ENDMETHOD.


  METHOD apply_variant.
    "only the filters the list has - a view of an older version of the
    "entity may name others
    LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>).
      READ TABLE is_data-filters INTO DATA(ls_value) WITH KEY name = <ls_filter>-name.
      <ls_filter>-value = COND #( WHEN sy-subrc = 0 THEN ls_value-value ).
    ENDLOOP.
    mv_search = is_data-search.
    IF is_data-sort_field IS INITIAL OR line_exists( mt_sort_field[ name = is_data-sort_field ] ).
      mv_sort_field = is_data-sort_field.
      mv_sort_desc = is_data-sort_desc.
    ENDIF.
    mt_hidden_column = is_data-hidden_columns.
  ENDMETHOD.


  METHOD render_variant_controls.

    IF mt_variant_item IS INITIAL.
      RETURN.
    ENDIF.

    io_toolbar->ele( `Select`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->a( n = `selectedKey`
              v = client->_bind( mv_variant )
        )->a( n = `items`
              v = client->_bind( mt_variant_item )
        )->a( n = `change`
              v = client->_event( cs_event-variant_select )
        )->a( n = `width`
              v = `12rem`
        )->tag( n  = `Item`
                ns = `core`
            )->a( n = `key`
                  v = `{KEY}`
            )->a( n = `text`
                  v = `{TEXT}` ).

    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://save`
        )->a( n = `tooltip`
              t = get_text( cs_text-save_view )
        )->a( n = `press`
              v = client->_event( cs_event-variant_save_open ) ).

    DATA(lv_deletable) = xsdbool( mv_variant IS NOT INITIAL AND mv_variant <> cv_variant_standard ).
    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://delete`
        )->a( n = `tooltip`
              t = get_text( cs_text-delete_view )
        )->a( n = `enabled`
              b = lv_deletable
        )->a( n = `press`
              v = client->_event( cs_event-variant_delete ) ).

    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://action-settings`
        )->a( n = `tooltip`
              t = get_text( cs_text-columns )
        )->a( n = `press`
              v = client->_event( cs_event-columns ) ).

  ENDMETHOD.


  METHOD render_variant_popup.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`
                  t = get_text( cs_text-save_view )
            )->a( n = `contentWidth`
                  v = `25rem` ).

    lo_dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class`
                  v = `sapUiSmallMargin`
            )->tag( `Label`
                )->a( n = `text`
                      t = get_text( cs_text-view_name )
                )->a( n = `required`
                      v = `true`
            )->tag( `Input`
                )->a( n = `value`
                      v = client->_bind( mv_variant_name )
                )->a( n = `maxLength`
                      v = `60`
            )->tag( `CheckBox`
                )->a( n = `text`
                      t = get_text( cs_text-as_default )
                )->a( n = `selected`
                      v = client->_bind( mv_variant_default ) ).

    lo_dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-save )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `press`
                  v = client->_event( cs_event-variant_save ) ).
    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-popup_cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD render_column_popup.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`
                  t = get_text( cs_text-columns )
            )->a( n = `contentWidth`
                  v = `25rem` ).

    lo_dialog->ele( `content`
        )->ele( `List`
            )->a( n = `mode`
                  v = `MultiSelect`
            )->a( n = `items`
                  v = client->_bind( mt_column )
            )->tag( `StandardListItem`
                )->a( n = `title`
                      v = `{LABEL}`
                )->a( n = `selected`
                      v = `{VISIBLE}` ).

    lo_dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-ok )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `press`
                  v = client->_event( cs_event-columns_ok ) ).
    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-popup_cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD on_variant_event.

    result = abap_true.
    CASE client->get_event( ).

      WHEN cs_event-variant_select.
        IF mv_variant = cv_variant_standard.
          apply_variant( ms_standard ).
        ELSE.
          READ TABLE mt_variants INTO DATA(ls_variant) WITH KEY name = mv_variant.
          IF sy-subrc = 0.
            apply_variant( ls_variant-data ).
          ENDIF.
        ENDIF.
        load_data( ).
        "the columns may differ - built into the view
        render_page( client ).

      WHEN cs_event-variant_save_open.
        mv_variant_name = COND #( WHEN mv_variant <> cv_variant_standard THEN mv_variant ).
        READ TABLE mt_variants INTO ls_variant WITH KEY name = mv_variant.
        mv_variant_default = xsdbool( sy-subrc = 0 AND ls_variant-is_default = abap_true ).
        render_variant_popup( client ).

      WHEN cs_event-variant_save.
        DATA(lv_name) = condense( mv_variant_name ).
        IF lv_name IS INITIAL OR lv_name = cv_variant_standard.
          client->message_box_display( text = |{ get_text( cs_text-required ) }: { get_text( cs_text-view_name ) }|
                                       type = `warning` ).
          RETURN.
        ENDIF.
        IF z2ui5_cl_rap_variant=>save( entity_name = mv_cds_view
                                       variant     = VALUE #( name       = lv_name
                                                              is_default = mv_variant_default
                                                              data       = capture_variant( ) ) ) = abap_false.
          client->message_box_display( text = get_text( cs_text-load_error )
                                       type = `error` ).
          RETURN.
        ENDIF.
        client->popup_destroy( ).
        init_variants( ).
        mv_variant = lv_name.
        READ TABLE mt_variants INTO ls_variant WITH KEY name = lv_name.
        IF sy-subrc = 0.
          apply_variant( ls_variant-data ).
        ENDIF.
        render_page( client ).
        client->message_toast_display( get_text( cs_text-view_saved ) ).

      WHEN cs_event-variant_delete.
        IF mv_variant <> cv_variant_standard AND mv_variant IS NOT INITIAL.
          z2ui5_cl_rap_variant=>delete( entity_name = mv_cds_view
                                        name        = mv_variant ).
        ENDIF.
        "the standard view again - init_variants would apply the default
        DATA(ls_now) = capture_variant( ).
        init_variants( ).
        apply_variant( ls_now ).
        mv_variant = cv_variant_standard.
        render_page( client ).

      WHEN cs_event-columns.
        CLEAR mt_column.
        LOOP AT get_line_item_fields( ) INTO DATA(ls_col).
          APPEND VALUE #( name    = ls_col-name
                          label   = COND #( WHEN ls_col-line_item_label IS NOT INITIAL THEN ls_col-line_item_label
                                            ELSE ls_col-label )
                          visible = xsdbool( NOT line_exists( mt_hidden_column[ table_line = ls_col-name ] ) ) )
            TO mt_column.
        ENDLOOP.
        render_column_popup( client ).

      WHEN cs_event-columns_ok.
        CLEAR mt_hidden_column.
        LOOP AT mt_column INTO DATA(ls_column) WHERE visible = abap_false.
          APPEND ls_column-name TO mt_hidden_column.
        ENDLOOP.
        client->popup_destroy( ).
        render_page( client ).

      WHEN cs_event-popup_cancel.
        client->popup_destroy( ).

      WHEN OTHERS.
        result = abap_false.
    ENDCASE.

  ENDMETHOD.


  METHOD get_missing_filters.
    LOOP AT mt_filter INTO DATA(ls_filter) WHERE mandatory = abap_true.
      IF condense( ls_filter-value ) = ``.
        READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = ls_filter-name.
        APPEND COND string( WHEN sy-subrc = 0 THEN ls_field-label ELSE ls_filter-name ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD on_nav_path.

    FIELD-SYMBOLS <ls_row> TYPE any.

    "arg 1 the column, args 2... the keys of the row
    READ TABLE ms_entity-fields INTO DATA(ls_col) WITH KEY name = client->get_event_arg( ).
    IF sy-subrc <> 0 OR ls_col-line_item_target IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lr_row) = find_row_by_event_keys( data       = mr_data
                                           key_fields = mt_row_key
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO <ls_row>.

    DATA(lr_target) = read_association_target( is_entity   = ms_entity
                                               association = ls_col-line_item_target
                                               row         = <ls_row> ).
    IF lr_target IS NOT BOUND.
      client->message_toast_display( get_text( cs_text-not_found ) ).
      RETURN.
    ENDIF.
    ASSIGN lr_target->* TO <ls_row>.
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( val = <ls_row> ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD on_intent.

    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lt_params TYPE ty_t_name_value.

    DATA(lv_arg) = client->get_event_arg( ).

    "a toolbar button: its target, no parameters
    READ TABLE ms_entity-actions INTO DATA(ls_intent) WITH KEY name = lv_arg.
    IF sy-subrc = 0 AND ls_intent-semantic_object IS NOT INITIAL.
      navigate_to_intent( client          = client
                          semantic_object = ls_intent-semantic_object
                          action          = ls_intent-semantic_action ).
      RETURN.
    ENDIF.

    "a column's link: the value and the row's keys as parameters
    READ TABLE ms_entity-fields INTO DATA(ls_col) WITH KEY name = lv_arg.
    IF sy-subrc <> 0 OR ls_col-line_item_sem_object IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lr_row) = find_row_by_event_keys( data       = mr_data
                                           key_fields = mt_row_key
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS BOUND.
      ASSIGN lr_row->* TO <ls_row>.
      DATA(lt_names) = VALUE string_table( ( ls_col-name ) ).
      APPEND LINES OF mt_row_key TO lt_names.
      LOOP AT lt_names INTO DATA(lv_name).
        IF line_exists( lt_params[ name = lv_name ] ).
          CONTINUE.
        ENDIF.
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT lv_name OF STRUCTURE <ls_row> TO <lv_value>.
        IF <lv_value> IS ASSIGNED.
          APPEND VALUE #( name = lv_name value = |{ <lv_value> }| ) TO lt_params.
        ENDIF.
      ENDLOOP.
    ENDIF.
    navigate_to_intent( client          = client
                        semantic_object = ls_col-line_item_sem_object
                        action          = COND #( WHEN ls_col-line_item_sem_action IS NOT INITIAL
                                                  THEN ls_col-line_item_sem_action ELSE `display` )
                        params          = lt_params ).

  ENDMETHOD.


  METHOD normalize_value.
    result = normalize_key_value( val ).
  ENDMETHOD.


  METHOD on_row_press.

    FIELD-SYMBOLS <ls_row> TYPE any.

    DATA(lr_row) = find_row_by_event_keys( data       = mr_data
                                           key_fields = mt_row_key
                                           client     = client ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO <ls_row>.

    "typed as the entity again - the object page reads its annotations
    "from the type name, which a row with the selection column has not
    DATA(lr_entity_row) = to_entity_row( entity_name = mv_cds_view
                                         row         = <ls_row> ).
    ASSIGN lr_entity_row->* TO <ls_row>.
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( val = <ls_row> ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD on_create.

    FIELD-SYMBOLS <ls_empty> TYPE any.

    IF ms_caps-can_create = abap_false.
      client->message_box_display( text = get_text( cs_text-read_only )
                                   type = `error` ).
      RETURN.
    ENDIF.

    TRY.
        DATA lr_empty TYPE REF TO data.
        CREATE DATA lr_empty TYPE (mv_cds_view).
        ASSIGN lr_empty->* TO <ls_empty>.
        DATA(lo_op) = NEW z2ui5_cl_rap_object_page(
          val       = <ls_empty>
          title     = |{ get_text( cs_text-create_title ) } { mv_title }|
          editable  = abap_true
          is_create = abap_true ).
        lo_op->set_extension( mo_ext ).
        client->nav_app_call( lo_op ).
      CATCH cx_root.
        client->message_box_display(
          text = get_text( cs_text-read_only )
          type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD on_action.

    "arg 1 the action, args 2... the keys of the row of an inline action -
    "only an action the list offers, whatever the event names
    mv_pending_action = client->get_event_arg( ).
    DATA(lt_offered) = get_line_item_actions( abap_false ).
    APPEND LINES OF get_line_item_actions( abap_true ) TO lt_offered.
    IF NOT line_exists( lt_offered[ name = mv_pending_action ] ).
      CLEAR mv_pending_action.
      RETURN.
    ENDIF.
    CLEAR mt_pending_keys.
    DO lines( mt_row_key ) TIMES.
      DATA(lv_key) = client->get_event_arg( sy-index + 1 ).
      IF lv_key IS INITIAL AND sy-index = 1.
        EXIT.
      ENDIF.
      APPEND lv_key TO mt_pending_keys.
    ENDDO.

    DATA(lr_param) = create_action_parameter( entity_name = mv_cds_view
                                              action      = mv_pending_action ).
    IF lr_param IS BOUND.
      "the parameter first - the action runs on the return (on_navigated)
      ASSIGN lr_param->* TO FIELD-SYMBOL(<ls_param>).
      READ TABLE ms_entity-actions INTO DATA(ls_action) WITH KEY name = mv_pending_action.
      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog( val   = <ls_param>
                                                        title = ls_action-label ).
      lo_dialog->set_extension( mo_ext ).
      client->nav_app_call( lo_dialog ).
      RETURN.
    ENDIF.

    execute_action( client ).
    CLEAR: mv_pending_action, mt_pending_keys, mv_opened_created.

  ENDMETHOD.


  METHOD execute_action.

    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    DATA lr_rows TYPE REF TO data.

    IF mt_pending_keys IS INITIAL.
      lr_rows = get_selected_rows( entity_name = mv_cds_view
                                   data        = mr_data ).
    ELSE.
      "the row of an inline action, found again by its keys
      DATA(lr_row) = find_row_by_keys( data       = mr_data
                                       key_fields = mt_row_key
                                       key_values = mt_pending_keys ).
      lr_rows = create_entity_table( mv_cds_view ).
      IF lr_row IS BOUND AND lr_rows IS BOUND.
        ASSIGN lr_rows->* TO <lt_rows>.
        ASSIGN lr_row->* TO <ls_row>.
        APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_new>).
        MOVE-CORRESPONDING <ls_row> TO <ls_new>.
      ENDIF.
    ENDIF.

    READ TABLE ms_entity-actions INTO DATA(ls_action) WITH KEY name = mv_pending_action source = `LINEITEM`.
    DATA(ls_result) = run_action( entity_name         = mv_cds_view
                                  action              = mv_pending_action
                                  rows                = lr_rows
                                  param               = param
                                  invocation_grouping = ls_action-invocation_grouping ).
    "#ISOLATED: some rows may have changed even when others failed
    load_data( ).
    IF ls_result-success = abap_true.
      "a factory action: the record it created
      IF ls_result-keys IS NOT INITIAL.
        open_created( client = client
                      keys   = ls_result-keys ).
        RETURN.
      ENDIF.
      IF ls_result-messages IS INITIAL.
        client->message_toast_display( get_text( cs_text-action_done ) ).
      ELSE.
        show_messages( client   = client
                       messages = ls_result-messages
                       type     = `success` ).
      ENDIF.
    ELSE.
      show_messages( client   = client
                     messages = ls_result-messages ).
    ENDIF.

  ENDMETHOD.


  METHOD render_action_buttons.

    DATA lt_arg TYPE string_table.
    DATA ls_crit TYPE z2ui5_cl_rap_util=>ty_s_action.

    LOOP AT get_action_entries( it_actions = it_actions
                                it_groups  = it_groups ) INTO DATA(ls_entry).

      IF ls_entry-group-id IS NOT INITIAL.
        DATA(lo_menu) = io_container->ele( `MenuButton`
            )->a( n = `text`
                  t = ls_entry-group-label
            )->ele( `menu`
                )->ele( `Menu` ).
        LOOP AT ls_entry-items INTO DATA(ls_item).
          lt_arg = args_before.
          APPEND ls_item-name TO lt_arg.
          READ TABLE enabled_values INTO DATA(ls_item_binding) WITH KEY name = ls_item-name.
          DATA(lv_item_enabled) = COND string( WHEN sy-subrc = 0 THEN ls_item_binding-value ELSE `true` ).
          lo_menu->tag( `MenuItem`
              )->a( n = `text`
                    t = ls_item-label
              )->a( n = `enabled`
                    v = lv_item_enabled
              )->a( n = `press`
                    v = client->_event( val   = event
                                        t_arg = lt_arg ) ).
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "the criticality as the button's type - written as a literal of
      "sap.m.ButtonType, so the view gate can check it
      ls_crit = ls_entry-action.
      DATA(lv_button_type) = `Default`.
      IF row IS SUPPLIED.
        CASE get_action_button_type( is_action = ls_crit
                                     row       = row ).
          WHEN `Accept`.
            lv_button_type = `Accept`.
          WHEN `Reject`.
            lv_button_type = `Reject`.
          WHEN `Emphasized`.
            lv_button_type = `Emphasized`.
        ENDCASE.
      ELSE.
        CASE get_action_button_type( ls_crit ).
          WHEN `Accept`.
            lv_button_type = `Accept`.
          WHEN `Reject`.
            lv_button_type = `Reject`.
          WHEN `Emphasized`.
            lv_button_type = `Emphasized`.
        ENDCASE.
      ENDIF.
      lt_arg = args_before.
      APPEND ls_entry-action-name TO lt_arg.
      READ TABLE enabled_values INTO DATA(ls_binding) WITH KEY name = ls_entry-action-name.
      DATA(lv_action_enabled) = COND string( WHEN sy-subrc = 0 THEN ls_binding-value ELSE `true` ).
      io_container->tag( `Button`
          )->a( n = `text`
                t = ls_entry-action-label
          )->a( n = `type`
                v = lv_button_type
          )->a( n = `enabled`
                v = lv_action_enabled
          )->a( n = `press`
                v = client->_event( val   = event
                                    t_arg = lt_arg ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD open_created.

    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( cds_view_name = mv_cds_view
                                                keys          = keys ).
    lo_op->set_extension( mo_ext ).
    mv_opened_created = abap_true.
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      client->message_box_display( text = get_load_error( mv_cds_view )
                                   type = `error` ).
      RETURN.
    ENDIF.

    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_page) = lo_view->ele( n  = `View`
                                   ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `displayBlock`
              v = `true`
        )->a( n = `height`
              v = `100%`

        )->ele( `Shell`
            )->ele( `Page`
                )->a( n = `title`
                      t = mv_title
                )->a( n = `showNavButton`
                      b = client->check_app_prev_stack( )
                )->a( n = `navButtonPress`
                      v = client->_event( cs_event-back ) ).

    render_filter_bar( io_page = lo_page
                       client  = client ).

    render_table( io_page = lo_page
                  client  = client ).

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_filter_bar.

    IF mt_filter IS INITIAL AND ms_entity-is_searchable = abap_false AND mv_is_draft_bo = abap_false.
      RETURN.
    ENDIF.

    DATA(lo_bar) = io_page->ele( `subHeader`
        )->ele( `OverflowToolbar` ).

    "@Search.searchable: the free-text search over the search elements
    IF ms_entity-is_searchable = abap_true.
      lo_bar->tag( `SearchField`
          )->a( n = `value`
                v = client->_bind( mv_search )
          )->a( n = `search`
                v = client->_event( cs_event-search )
          )->a( n = `width`
                v = `15rem`
          )->a( n = `class`
                v = `sapUiTinyMarginEnd` ).
    ENDIF.

    DATA(lo_fbox) = lo_bar->ele( `HBox`
        )->a( n = `items`
              v = client->_bind( mt_filter )
        )->a( n = `alignItems`
              v = `Center`
        )->a( n = `wrap`
              v = `Wrap` ).

    "a hidden filter is not shown - its default still restricts the rows
    lo_fbox->tag( `Input`
        )->a( n = `visible`
              v = `{= !${HIDDEN} }`
        )->a( n = `value`
              v = `{VALUE}`
        )->a( n = `placeholder`
              v = `{LABEL}`
        )->a( n = `tooltip`
              t = get_text( cs_text-filter_hint )
        )->a( n = `showValueHelp`
              v = `{SHOW_VH}`
        )->a( n = `valueHelpRequest`
              v = client->_event( val = cs_event-value_help
                                  arg = `${NAME}` )
        )->a( n = `submit`
              v = client->_event( cs_event-go )
        )->a( n = `width`
              v = `12rem`
        )->a( n = `class`
              v = `sapUiTinyMarginEnd` ).

    "a draft business object: the editing status (since 2026-10, third
    "round)
    IF mv_is_draft_bo = abap_true.
      lo_bar->ele( `Select`
          )->a( n = `xmlns:core`
                v = `sap.ui.core`
          )->a( n = `selectedKey`
                v = client->_bind( mv_editing_status )
          )->a( n = `items`
                v = client->_bind( mt_editing_status )
          )->a( n = `change`
                v = client->_event( cs_event-go )
          )->a( n = `tooltip`
                t = get_text( cs_text-editing_status )
          )->tag( n  = `Item`
                  ns = `core`
              )->a( n = `key`
                    v = `{KEY}`
              )->a( n = `text`
                    v = `{TEXT}` ).
    ENDIF.

    lo_bar->tag( `ToolbarSpacer` ).

    lo_bar->tag( `Button`
        )->a( n = `text`
              t = get_text( cs_text-go )
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

    DATA(lt_columns) = get_visible_columns( ).
    DATA(lt_inline) = get_line_item_actions( abap_true ).
    DATA(lv_select) = xsdbool( get_line_item_actions( abap_false ) IS NOT INITIAL ).
    "the rows are selectable when there are actions to run on them
    DATA(lv_mode) = `None`.
    IF lv_select = abap_true.
      lv_mode = `MultiSelect`.
    ENDIF.

    DATA(lo_table) = io_page->ele( `Table`
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
              v = lv_mode ).
    "the toolbar actions follow the feature control of the selected rows
    IF lv_select = abap_true AND ms_perm-answered = abap_true.
      lo_table->a( n = `selectionChange`
                   v = client->_event( cs_event-selection_change ) ).
    ENDIF.

    render_toolbar( io_table = lo_table
                    client   = client ).

    "the draft status of a row of a draft business object - first
    DATA(lv_draft_column) = has_row_column( cs_row_column-draft ).
    DATA(lo_columns) = lo_table->ele( `columns` ).
    IF lv_draft_column = abap_true.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = get_text( cs_text-editing_status ) ).
    ENDIF.
    LOOP AT lt_columns INTO DATA(ls_col).
      render_column( io_columns = lo_columns
                     is_col     = ls_col ).
    ENDLOOP.
    LOOP AT lt_inline INTO DATA(ls_inline).
      lo_columns->ele( `Column`
          )->a( n = `hAlign`
                v = `End` ).
    ENDLOOP.

    "items - row press navigates to a generated object page
    DATA(lo_items) = lo_table->ele( `items` ).
    DATA lo_row TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA lt_arg TYPE string_table.
    LOOP AT mt_row_key INTO DATA(lv_key).
      APPEND `${` && lv_key && `}` TO lt_arg.
    ENDLOOP.
    IF mt_row_key IS NOT INITIAL.
      lo_row = lo_items->ele( `ColumnListItem`
          )->a( n = `type`
                v = `Navigation`
          )->a( n = `press`
                v = client->_event( val   = cs_event-row_press
                                    t_arg = lt_arg ) ).
    ELSE.
      lo_row = lo_items->ele( `ColumnListItem` ).
    ENDIF.
    IF lv_select = abap_true.
      lo_row->a( n = `selected`
                 v = |\{{ cv_select_column }\}| ).
    ENDIF.
    DATA(lo_cells) = lo_row->ele( `cells` ).

    IF lv_draft_column = abap_true.
      lo_cells->tag( `ObjectStatus`
          )->a( n = `text`
                v = |\{{ cs_row_column-draft_text }\}|
          )->a( n = `state`
                v = `{= ${ZZDRAFT} === 'LOCKED' ? 'Warning' : 'Information' }` ).
    ENDIF.

    LOOP AT lt_columns INTO ls_col.
      render_cell( io_cells = lo_cells
                   is_col   = ls_col
                   client   = client ).
    ENDLOOP.

    "inline actions - one button per row, the row found again by its keys;
    "enabled by the row's feature control (since 2026-10, third round)
    LOOP AT lt_inline INTO ls_inline.
      DATA(lv_inline_column) = |{ cs_row_column-action_prefix }{ sy-tabix }|.
      DATA(lv_inline_enabled) = COND string( WHEN has_row_column( lv_inline_column ) = abap_true
                                             THEN |\{{ lv_inline_column }\}|
                                             ELSE `true` ).
      DATA(lt_action_arg) = VALUE string_table( ( ls_inline-name ) ).
      APPEND LINES OF lt_arg TO lt_action_arg.
      "the criticality as the type - a literal the view gate can check; a
      "field's criticality needs the row, which the template does not have
      DATA(lv_inline_type) = `Default`.
      CASE get_action_button_type( ls_inline ).
        WHEN `Accept`.
          lv_inline_type = `Accept`.
        WHEN `Reject`.
          lv_inline_type = `Reject`.
        WHEN `Emphasized`.
          lv_inline_type = `Emphasized`.
      ENDCASE.
      lo_cells->tag( `Button`
          )->a( n = `text`
                t = ls_inline-label
          )->a( n = `type`
                v = lv_inline_type
          )->a( n = `enabled`
                v = lv_inline_enabled
          )->a( n = `press`
                v = client->_event( val   = cs_event-action
                                    t_arg = lt_action_arg ) ).
    ENDLOOP.

    "more rows than loaded - the next page comes from the database
    io_page->tag( `Button`
        )->a( n = `text`
              t = get_text( cs_text-more )
        )->a( n = `width`
              v = `100%`
        )->a( n = `type`
              v = `Transparent`
        )->a( n = `visible`
              v = client->_bind( mv_more )
        )->a( n = `press`
              v = client->_event( cs_event-more ) ).

  ENDMETHOD.


  METHOD render_toolbar.

    DATA(lo_toolbar) = io_table->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).

    lo_toolbar->tag( `Title`
        )->a( n = `text`
              v = mv_title && ` (` && client->_bind( mv_count ) && `)` ).

    lo_toolbar->tag( `ToolbarSpacer` ).

    "@UI.lineItem actions of type #FOR_ACTION - on the selected rows, a
    "static one without; by position, an action group as a menu
    render_action_buttons( io_container     = lo_toolbar
                           it_actions       = get_line_item_actions( abap_false )
                           it_groups        = ms_entity-action_groups
                           client           = client
                           event            = cs_event-action
                           enabled_values   = get_action_enabled( ) ).

    "@UI.lineItem #FOR_INTENT_BASED_NAVIGATION - to another app
    LOOP AT get_line_item_intents( ) INTO DATA(ls_intent).
      lo_toolbar->tag( `Button`
          )->a( n = `text`
                t = ls_intent-label
          )->a( n = `press`
                v = client->_event( val = cs_event-intent
                                    arg = ls_intent-name ) ).
    ENDLOOP.

    render_sort_controls( io_toolbar = lo_toolbar
                          client     = client ).

    render_variant_controls( io_toolbar = lo_toolbar
                             client     = client ).

    IF ms_caps-can_create = abap_true.
      lo_toolbar->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-create )
          )->a( n = `press`
                v = client->_event( cs_event-create )
          )->a( n = `type`
                v = `Emphasized`
          )->a( n = `icon`
                v = `sap-icon://add` ).
    ENDIF.

    render_extension( spot         = cs_spot-toolbar
                      io_container = lo_toolbar
                      client       = client ).

    render_export_button( io_toolbar = lo_toolbar
                          client     = client ).

    lo_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://refresh`
        )->a( n = `tooltip`
              t = get_text( cs_text-refresh )
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
      io_columns->ele( `Column`
          )->a( n = `minScreenWidth`
                v = `Tablet`
          )->a( n = `demandPopin`
                v = `true`
          )->tag( `Text`
              )->a( n = `text`
                    t = lv_col_label
              )->a( n = `tooltip`
                    t = is_col-tooltip ).
    ELSEIF is_col-line_item_importance CS `LOW`.
      io_columns->ele( `Column`
          )->a( n = `minScreenWidth`
                v = `Desktop`
          )->a( n = `demandPopin`
                v = `true`
          )->tag( `Text`
              )->a( n = `text`
                    t = lv_col_label
              )->a( n = `tooltip`
                    t = is_col-tooltip ).
    ELSE.
      io_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = lv_col_label
              )->a( n = `tooltip`
                    t = is_col-tooltip ).
    ENDIF.

  ENDMETHOD.


  METHOD render_cell.

    DATA(lv_path) = |\{{ is_col-name }\}|.

    "the arguments of a link that needs its row: the column, the row's keys
    DATA(lt_link_arg) = VALUE string_table( ( is_col-name ) ).
    LOOP AT mt_row_key INTO DATA(lv_key).
      APPEND `${` && lv_key && `}` TO lt_link_arg.
    ENDLOOP.

    "#WITH_URL -> a link to the URL in another field
    IF is_col-line_item_type = `WITH_URL` AND is_col-line_item_url IS NOT INITIAL
      AND line_exists( ms_entity-fields[ name = is_col-line_item_url ] ).
      io_cells->tag( `Link`
          )->a( n = `text`
                v = lv_path
          )->a( n = `href`
                v = |\{{ is_col-line_item_url }\}|
          )->a( n = `target`
                v = `_blank` ).

    "#WITH_NAVIGATION_PATH -> the object page of the associated record
    ELSEIF is_col-line_item_type = `WITH_NAVIGATION_PATH` AND is_col-line_item_target IS NOT INITIAL
      AND client IS BOUND AND mt_row_key IS NOT INITIAL.
      io_cells->tag( `Link`
          )->a( n = `text`
                v = lv_path
          )->a( n = `press`
                v = client->_event( val   = cs_event-nav_path
                                    t_arg = lt_link_arg ) ).

    "#WITH_INTENT_BASED_NAVIGATION -> another app of the launchpad
    ELSEIF is_col-line_item_type = `WITH_INTENT_BASED_NAVIGATION` AND is_col-line_item_sem_object IS NOT INITIAL
      AND client IS BOUND AND mt_row_key IS NOT INITIAL.
      io_cells->tag( `Link`
          )->a( n = `text`
                v = lv_path
          )->a( n = `press`
                v = client->_event( val   = cs_event-intent
                                    t_arg = lt_link_arg ) ).

    "criticality -> ObjectStatus
    ELSEIF is_col-datapoint_crit_field IS NOT INITIAL
      OR is_col-line_item_crit_field IS NOT INITIAL.
      DATA(lv_crit_field) = is_col-line_item_crit_field.
      IF lv_crit_field IS INITIAL.
        lv_crit_field = is_col-datapoint_crit_field.
      ENDIF.
      io_cells->tag( `ObjectStatus`
          )->a( n = `text`
                v = lv_path
          )->a( n = `state`
                v = criticality_expression( lv_crit_field ) ).

    "amount + currency -> ObjectNumber
    ELSEIF is_col-is_amount_field = abap_true
      AND is_col-semantics_currency_code IS NOT INITIAL.
      io_cells->tag( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = |\{{ is_col-semantics_currency_code }\}| ).

    "quantity + unit -> ObjectNumber
    ELSEIF is_col-is_quantity_field = abap_true
      AND is_col-semantics_unit_of_measure IS NOT INITIAL.
      io_cells->tag( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = |\{{ is_col-semantics_unit_of_measure }\}| ).

    "@ObjectModel.text.element, arranged by @UI.textArrangement - "Text
    "(Value)" is the Fiori default
    ELSEIF is_col-text_element IS NOT INITIAL
      AND line_exists( ms_entity-fields[ name = is_col-text_element ] ).
      CASE is_col-text_arrangement.
        WHEN `TEXT_LAST`.
          io_cells->tag( `Text`
              )->a( n = `text`
                    v = |{ lv_path } (\{{ is_col-text_element }\})| ).
        WHEN `TEXT_ONLY`.
          io_cells->tag( `Text`
              )->a( n = `text`
                    v = |\{{ is_col-text_element }\}| ).
        WHEN `TEXT_SEPARATE`.
          io_cells->tag( `Text`
              )->a( n = `text`
                    v = lv_path ).
        WHEN OTHERS.
          io_cells->tag( `Text`
              )->a( n = `text`
                    v = |\{{ is_col-text_element }\} ({ lv_path })| ).
      ENDCASE.

    ELSE.
      io_cells->tag( `Text`
          )->a( n = `text`
                v = lv_path ).
    ENDIF.

  ENDMETHOD.


  METHOD apply_row_states.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lr_extended TYPE REF TO data.
    FIELD-SYMBOLS <lt_old> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_new> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_enabled> TYPE any.
    FIELD-SYMBOLS <lv_state> TYPE any.
    FIELD-SYMBOLS <ls_row> TYPE any.
    DATA ls_inline TYPE z2ui5_cl_rap_util=>ty_s_action.

    CLEAR: ms_perm, mt_action_state.
    IF ms_caps-is_rap_bo = abap_false OR mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    ms_perm = get_permissions( entity_name = mv_cds_view
                               rows        = mr_data ).
    DATA(lt_inline) = get_line_item_actions( abap_true ).

    "the columns: an inline action's enabled, the draft status
    TRY.
        DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( mr_data ) ).
        DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
        lt_comp = lo_line->get_components( ).
        DATA(lo_bool) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_name( `ABAP_BOOL` ) ).
        DATA(lo_string) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_name( `STRING` ) ).
        IF ms_perm-answered = abap_true.
          LOOP AT lt_inline INTO ls_inline.
            APPEND VALUE #( name = |{ cs_row_column-action_prefix }{ sy-tabix }| type = lo_bool ) TO lt_comp.
          ENDLOOP.
        ENDIF.
        IF mv_is_draft_bo = abap_true.
          APPEND VALUE #( name = cs_row_column-draft type = lo_string ) TO lt_comp.
          APPEND VALUE #( name = cs_row_column-draft_text type = lo_string ) TO lt_comp.
        ENDIF.
        IF lines( lt_comp ) > lines( lo_line->get_components( ) ).
          DATA(lo_new_table) = cl_abap_tabledescr=>create( cl_abap_structdescr=>create( lt_comp ) ).
          CREATE DATA lr_extended TYPE HANDLE lo_new_table.
          ASSIGN mr_data->* TO <lt_old>.
          ASSIGN lr_extended->* TO <lt_new>.
          MOVE-CORRESPONDING <lt_old> TO <lt_new>.
          mr_data = lr_extended.
        ENDIF.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    ASSIGN mr_data->* TO <lt_new>.
    IF ms_perm-answered = abap_true AND lt_inline IS NOT INITIAL.
      LOOP AT <lt_new> ASSIGNING <ls_row>.
        DATA(ls_row_perm) = z2ui5_cl_rap_util=>get_instance_permissions(
          is_permissions = ms_perm
          keys           = get_keys_of_row( entity_name = mv_cds_view
                                            row         = <ls_row> ) ).
        LOOP AT lt_inline INTO ls_inline.
          UNASSIGN <lv_enabled>.
          ASSIGN COMPONENT |{ cs_row_column-action_prefix }{ sy-tabix }| OF STRUCTURE <ls_row> TO <lv_enabled>.
          IF <lv_enabled> IS ASSIGNED.
            <lv_enabled> = z2ui5_cl_rap_util=>is_permitted( ops  = ls_row_perm-actions
                                                            name = ls_inline-name ).
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDIF.

    IF mv_is_draft_bo = abap_true.
      fill_draft_status( mr_data ).
      "the editing status filter - applied to the rows read, so the count
      "is theirs and no "more" follows
      IF mv_editing_status IS NOT INITIAL
        AND mv_editing_status <> z2ui5_cl_rap_util=>cs_editing_status-all.
        DATA lr_kept TYPE REF TO data.
        CREATE DATA lr_kept LIKE <lt_new>.
        ASSIGN lr_kept->* TO <lt_old>.
        LOOP AT <lt_new> ASSIGNING <ls_row>.
          UNASSIGN <lv_state>.
          ASSIGN COMPONENT cs_row_column-draft OF STRUCTURE <ls_row> TO <lv_state>.
          IF <lv_state> IS ASSIGNED AND z2ui5_cl_rap_util=>matches_editing_status( filter = mv_editing_status
                                                                                   state  = <lv_state> ) = abap_true.
            APPEND <ls_row> TO <lt_old>.
          ENDIF.
        ENDLOOP.
        mr_data = lr_kept.
        mv_count = |{ lines( <lt_old> ) }|.
        mv_more = abap_false.
      ENDIF.
    ENDIF.

    update_action_state( ).

  ENDMETHOD.


  METHOD fill_draft_status.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_drafts> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_has> TYPE any.
    FIELD-SYMBOLS <lv_owner> TYPE any.
    FIELD-SYMBOLS <lv_state> TYPE any.
    FIELD-SYMBOLS <lv_text> TYPE any.
    DATA lt_draft_keys TYPE string_table.
    DATA lt_owner TYPE ty_t_name_value.
    DATA lv_has TYPE abap_bool.
    DATA lv_owner TYPE string.

    ASSIGN data->* TO <lt_rows>.
    IF <lt_rows> IS INITIAL.
      RETURN.
    ENDIF.
    "the entity's own draft fields, where a projection has them
    DATA(lv_own_fields) = xsdbool( line_exists( ms_entity-fields[ name = `HASDRAFTENTITY` ] ) ).
    READ TABLE ms_entity-fields INTO DATA(ls_by) WITH KEY admin_field = `LAST_CHANGED_BY`.
    IF sy-subrc <> 0.
      CLEAR ls_by.
    ENDIF.

    "else the drafts, read back - the key of each, and who changed it
    IF lv_own_fields = abap_false.
      DATA(lr_drafts) = read_drafts( entity_name = mv_cds_view
                                     rows        = data ).
      IF lr_drafts IS NOT BOUND.
        RETURN.
      ENDIF.
      ASSIGN lr_drafts->* TO <lt_drafts>.
      LOOP AT <lt_drafts> ASSIGNING FIELD-SYMBOL(<ls_draft>).
        DATA(lv_draft_key) = concat_lines_of( table = VALUE string_table(
          FOR ls_k IN get_keys_of_row( entity_name = mv_cds_view row = <ls_draft> ) ( ls_k-value ) ) sep = `|` ).
        APPEND lv_draft_key TO lt_draft_keys.
        CLEAR lv_owner.
        IF ls_by-name IS NOT INITIAL.
          UNASSIGN <lv_owner>.
          ASSIGN COMPONENT ls_by-name OF STRUCTURE <ls_draft> TO <lv_owner>.
          IF <lv_owner> IS ASSIGNED.
            lv_owner = |{ <lv_owner> }|.
          ENDIF.
        ENDIF.
        APPEND VALUE #( name = lv_draft_key value = lv_owner ) TO lt_owner.
      ENDLOOP.
    ENDIF.

    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      CLEAR: lv_has, lv_owner.
      IF lv_own_fields = abap_true.
        UNASSIGN <lv_has>.
        ASSIGN COMPONENT `HASDRAFTENTITY` OF STRUCTURE <ls_row> TO <lv_has>.
        lv_has = xsdbool( <lv_has> IS ASSIGNED AND <lv_has> IS NOT INITIAL ).
        UNASSIGN <lv_owner>.
        ASSIGN COMPONENT `DRAFTENTITYLASTCHANGEDBY` OF STRUCTURE <ls_row> TO <lv_owner>.
        IF <lv_owner> IS NOT ASSIGNED.
          ASSIGN COMPONENT `INPROCESSBYUSER` OF STRUCTURE <ls_row> TO <lv_owner>.
        ENDIF.
        IF <lv_owner> IS ASSIGNED.
          lv_owner = |{ <lv_owner> }|.
        ENDIF.
      ELSE.
        DATA(lv_row_key) = concat_lines_of( table = VALUE string_table(
          FOR ls_r IN get_keys_of_row( entity_name = mv_cds_view row = <ls_row> ) ( ls_r-value ) ) sep = `|` ).
        READ TABLE lt_owner INTO DATA(ls_owner) WITH KEY name = lv_row_key.
        IF sy-subrc = 0.
          lv_has = abap_true.
          lv_owner = ls_owner-value.
        ENDIF.
      ENDIF.
      DATA(ls_status) = z2ui5_cl_rap_util=>get_draft_status( has_draft = lv_has
                                                             owner     = lv_owner
                                                             user      = CONV #( sy-uname ) ).
      UNASSIGN: <lv_state>, <lv_text>.
      ASSIGN COMPONENT cs_row_column-draft OF STRUCTURE <ls_row> TO <lv_state>.
      ASSIGN COMPONENT cs_row_column-draft_text OF STRUCTURE <ls_row> TO <lv_text>.
      IF <lv_state> IS NOT ASSIGNED OR <lv_text> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      <lv_state> = ls_status-state.
      <lv_text> = SWITCH string( ls_status-state
        WHEN z2ui5_cl_rap_util=>cs_editing_status-own_draft THEN get_text( cs_text-own_draft )
        WHEN z2ui5_cl_rap_util=>cs_editing_status-locked
          THEN replace( val = get_text( cs_text-locked_by ) sub = `&1` with = ls_status-user )
        ELSE `` ).
    ENDLOOP.

  ENDMETHOD.


  METHOD update_action_state.

    CLEAR mt_action_state.
    DATA(lt_actions) = get_line_item_actions( abap_false ).
    IF lt_actions IS INITIAL.
      RETURN.
    ENDIF.
    "the selected rows - a static action needs none
    DATA(lr_selected) = get_selected_rows( entity_name = mv_cds_view
                                           data        = mr_data ).
    FIELD-SYMBOLS <lt_selected> TYPE STANDARD TABLE.
    LOOP AT lt_actions INTO DATA(ls_action).
      DATA(lv_enabled) = z2ui5_cl_rap_util=>is_permitted( ops  = ms_perm-global-actions
                                                          name = ls_action-name ).
      IF lv_enabled = abap_true AND ms_perm-answered = abap_true AND lr_selected IS BOUND.
        ASSIGN lr_selected->* TO <lt_selected>.
        LOOP AT <lt_selected> ASSIGNING FIELD-SYMBOL(<ls_selected>).
          IF z2ui5_cl_rap_util=>is_permitted(
               ops  = z2ui5_cl_rap_util=>get_instance_permissions(
                        is_permissions = ms_perm
                        keys           = get_keys_of_row( entity_name = mv_cds_view
                                                          row         = <ls_selected> ) )-actions
               name = ls_action-name ) = abap_false.
            lv_enabled = abap_false.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
      APPEND VALUE #( name = ls_action-name enabled = lv_enabled ) TO mt_action_state.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_action_enabled.
    LOOP AT mt_action_state INTO DATA(ls_state).
      APPEND VALUE #( name  = ls_state-name
                      value = COND #( WHEN ls_state-enabled = abap_true THEN `true` ELSE `false` ) ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_row_column.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( mr_data ) ).
        DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
        result = xsdbool( line_exists( lo_line->components[ name = to_upper( name ) ] ) ).
      CATCH cx_root.
        result = abap_false.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
