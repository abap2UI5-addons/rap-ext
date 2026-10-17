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

    " an entry of a list filter, a token of a MultiInput (added 2026-10,
    " third round)
    TYPES:
      BEGIN OF ty_s_filter_entry,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_filter_entry.

    TYPES ty_t_filter_entry TYPE STANDARD TABLE OF ty_s_filter_entry WITH EMPTY KEY.

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
        "added 2026-10, third round (filter bar): the control
        "(z2ui5_cl_rap_util=>cs_filter_control), the tokens of a MultiInput
        "(a part of value each), the entries of a list, the text typed into
        "a MultiInput, Error when a mandatory filter has no value, and the
        "filter was added by "adapt filters"
        control   TYPE string,
        tokens    TYPE ty_t_filter_entry,
        entries   TYPE ty_t_filter_entry,
        input     TYPE string,
        state     TYPE string,
        is_added  TYPE abap_bool,
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
        "added 2026-10, third round (filter bar, table): a token typed into
        "a MultiInput (argument the filter) or deleted (the token's key),
        "the define conditions dialog (open: the filter; add, delete: the
        "row; ok), adapt filters, a column moved up or down (the column)
        filter_token_add    TYPE string VALUE `FILTER_TOKEN_ADD`,
        filter_token_delete TYPE string VALUE `FILTER_TOKEN_DELETE`,
        conditions          TYPE string VALUE `FILTER_CONDITIONS`,
        condition_add       TYPE string VALUE `CONDITION_ADD`,
        condition_delete    TYPE string VALUE `CONDITION_DELETE`,
        conditions_ok       TYPE string VALUE `CONDITIONS_OK`,
        adapt_filters       TYPE string VALUE `ADAPT_FILTERS`,
        adapt_filters_ok    TYPE string VALUE `ADAPT_FILTERS_OK`,
        column_up           TYPE string VALUE `COLUMN_UP`,
        column_down         TYPE string VALUE `COLUMN_DOWN`,
      END OF cs_event.

    " when the list is read at the start (constructor initial_load; added
    " 2026-10, third round): AUTO - unless the default view does not apply
    " automatically; ENABLED - always; DISABLED - only on Go
    CONSTANTS:
      BEGIN OF cs_initial_load,
        auto     TYPE string VALUE `AUTO`,
        enabled  TYPE string VALUE `ENABLED`,
        disabled TYPE string VALUE `DISABLED`,
      END OF cs_initial_load.

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
        "added 2026-10, third round: the column's width (a CSS size)
        width   TYPE string,
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
        "added 2026-10, third round: the text of a field with
        "@ObjectModel.text.association - the prefix and the field's position
        text_prefix   TYPE string VALUE `ZZTEXT_`,
      END OF cs_row_column.

    " a row of the define conditions dialog (added 2026-10, third round)
    TYPES:
      BEGIN OF ty_s_condition_row,
        id       TYPE string,
        operator TYPE string,
        low      TYPE string,
        high     TYPE string,
        exclude  TYPE abap_bool,
      END OF ty_s_condition_row.

    TYPES ty_t_condition_row TYPE STANDARD TABLE OF ty_s_condition_row WITH EMPTY KEY.

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
        max_rows      TYPE i DEFAULT 500
        "added 2026-10, third round: cs_initial_load
        initial_load  TYPE string DEFAULT `AUTO`.

    "! values for the filters before the list is read - the inbound
    "! parameters of a navigation (z2ui5_cl_rap_start), by the name of the
    "! field, case-insensitive; a parameter that names no field is ignored.
    "! They win over the defaults and the default view (added 2026-10,
    "! third round)
    METHODS set_filter_presets
      IMPORTING
        params TYPE ty_t_name_value.

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

    "! added 2026-10, third round: the save dialog's public and apply
    "! automatically; the define conditions dialog - its rows and its
    "! operators; the fields "adapt filters" offers; the group
    "! field of the rows and the fields it offers; the table's text when it
    "! has no rows
    DATA mv_variant_public TYPE abap_bool.
    DATA mv_variant_auto   TYPE abap_bool.
    DATA mt_condition      TYPE ty_t_condition_row.
    DATA mt_condition_op   TYPE ty_t_variant_item.
    DATA mt_adapt          TYPE ty_t_column.
    DATA mv_group_field    TYPE string.
    DATA mt_group_item     TYPE ty_t_variant_item.
    DATA mv_no_data        TYPE string.

  PROTECTED SECTION.
    "! the inbound parameters set_filter_presets got - applied once, when
    "! the list starts (added 2026-10, third round)
    DATA mt_filter_preset TYPE ty_t_name_value.
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
    "! added 2026-10, third round (filter bar, table, views): when the list
    "! is read at the start (cs_initial_load), the filter of the define
    "! conditions dialog, the columns' order and widths of the user, the
    "! qualifier of the @UI.lineItem shown (a presentation variant's), what
    "! a selection variant restricts beyond the filter bar, and whether the
    "! rows were read (Go) at all
    DATA mv_initial_load TYPE string.
    DATA mv_condition_field TYPE string.
    "! the title of the define conditions dialog
    DATA mv_condition_title TYPE string.
    DATA mt_column_order TYPE string_table.
    DATA mt_column_width TYPE ty_t_name_value.
    DATA mv_line_item_qualifier TYPE string.
    DATA mv_variant_where TYPE string.
    DATA mv_loaded TYPE abap_bool.
    "! the view the list started with applies automatically
    DATA mv_start_auto TYPE abap_bool VALUE abap_true.
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

    "! the rows the pending action runs on: the row of an inline action,
    "! else the selected rows - a table of the entity (added 2026-10, third
    "! round)
    METHODS get_action_rows
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the inbound parameters (set_filter_presets) as the values of the
    "! filters of the fields they name - a field without a filter gets one;
    "! z2ui5_cl_rap_util=>match_inbound_parameters decides which (added
    "! 2026-10, third round)
    METHODS apply_filter_presets.

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

    "! a filter of the filter bar for is_field: its label, default, value
    "! help and control (z2ui5_cl_rap_util=>get_filter_control) with the
    "! entries of a list and the tokens of a MultiInput (added 2026-10,
    "! third round, like the methods below)
    METHODS create_filter
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE ty_s_filter.

    "! the tokens of the MultiInput filters - one per part of their value
    METHODS update_filter_tokens.

    "! what is typed into a MultiInput and not yet a token becomes a part
    "! of its value - before a read
    METHODS take_filter_inputs.

    "! the start of the list: the @UI.selectionPresentationVariant (else
    "! the unqualified presentation and selection variant) - the sort
    "! order, the group field, the qualified @UI.lineItem of the
    "! presentation variant and the selection variant's filter values
    METHODS apply_presentation_variants.

    "! the events of the filter bar - tokens, define conditions, adapt
    "! filters: abap_true when the event was one of them
    METHODS on_filter_event
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the define conditions dialog of the filter mv_condition_field
    METHODS render_condition_popup
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the adapt filters dialog - every field the filter bar can take
    METHODS render_adapt_popup
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the fields adapt filters offers: visible, no virtual element, no file
    METHODS get_adaptable_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! no rows until Go - the start without an initial load, a view that
    "! does not apply automatically
    METHODS clear_rows.

    "! the list is read at the start: cs_initial_load and whether the
    "! default view applies automatically
    METHODS is_initial_load
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the texts of the fields with @ObjectModel.text.association - a
    "! column cs_row_column-text_prefix and the field's position each
    METHODS apply_text_columns.

    "! the column of the association text of is_col - empty without one
    METHODS get_text_column
      IMPORTING
        is_col        TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! the rows can be selected: actions run on them, or an intent
    "! navigation takes their values (semanticObjectBinding)
    METHODS has_selection
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the operators of the define conditions dialog
    METHODS get_condition_operators
      RETURNING
        VALUE(result) TYPE ty_t_variant_item.

    "! the line item columns in the user's order (the columns dialog, a
    "! view), the hidden ones included
    METHODS get_ordered_columns
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the key of a view in the views select: its name, owner~name for
    "! another user's public view
    METHODS get_variant_key
      IMPORTING
        is_variant    TYPE z2ui5_cl_rap_variant=>ty_s_variant
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
    mv_initial_load = COND #( WHEN initial_load IS INITIAL THEN cs_initial_load-auto
                              ELSE to_upper( initial_load ) ).
  ENDMETHOD.


  METHOD set_filter_presets.
    mt_filter_preset = params.
  ENDMETHOD.


  METHOD apply_filter_presets.

    LOOP AT z2ui5_cl_rap_util=>match_inbound_parameters( params    = mt_filter_preset
                                                         it_fields = ms_entity-fields ) INTO DATA(ls_preset).
      "exactly the value the navigation names - not the "contains" of a
      "typed text
      DATA(lv_preset_value) = COND string( WHEN ls_preset-value IS INITIAL THEN ``
                                           ELSE |={ ls_preset-value }| ).
      READ TABLE mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>) WITH KEY name = ls_preset-name.
      IF sy-subrc = 0.
        <ls_filter>-value = lv_preset_value.
        CONTINUE.
      ENDIF.
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = ls_preset-name.
      DATA(ls_new_filter) = create_filter( ls_field ).
      ls_new_filter-value = lv_preset_value.
      ls_new_filter-is_added = abap_true.
      APPEND ls_new_filter TO mt_filter.
    ENDLOOP.
    CLEAR mt_filter_preset.
    update_filter_tokens( ).

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

      "init filter bar from @UI.selectionField - a mandatory one is marked,
      "each with the control of its type (since 2026-10, third round)
      LOOP AT get_selection_fields( ) INTO DATA(ls_sel).
        APPEND create_filter( ls_sel ) TO mt_filter.
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

      "the selection presentation variant - sort order, group field, the
      "qualified line item, filter values (since 2026-10, third round)
      apply_presentation_variants( ).

      "sortable: the columns that are text, numbers or dates - a virtual
      "element only with a sort transformation
      LOOP AT get_line_item_fields( ) INTO DATA(ls_col).
        IF z2ui5_cl_rap_util=>is_sortable( ls_col ) = abap_false OR ls_col-line_item_type = `AS_FIELDGROUP`.
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
      "the group field: @UI.presentationVariant.groupBy, a sortable column
      mt_group_item = VALUE #( ( ) ).
      LOOP AT mt_sort_field INTO DATA(ls_group_item).
        APPEND VALUE #( key = ls_group_item-name text = ls_group_item-label ) TO mt_group_item.
      ENDLOOP.
      IF ms_entity-group_by IS NOT INITIAL AND line_exists( mt_sort_field[ name = ms_entity-group_by[ 1 ] ] ).
        mv_group_field = ms_entity-group_by[ 1 ].
      ENDIF.

      "the standard view: the annotations' filters, sort order, columns
      update_filter_tokens( ).
      ms_standard = capture_variant( ).
      init_variants( ).
      "the parameters of an inbound navigation win over the default view -
      "and read the list whatever the initial load says
      DATA(lv_presets) = xsdbool( mt_filter_preset IS NOT INITIAL ).
      apply_filter_presets( ).
      IF lv_presets = abap_true OR is_initial_load( ) = abap_true.
        load_data( ).
      ELSE.
        clear_rows( ).
      ENDIF.
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
      "the rows of a mandatory filter only - none without its value; the
      "filter shows it (valueState, since 2026-10, third round)
      take_filter_inputs( ).
      DATA(lt_missing) = get_missing_filters( ).
      LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<ls_state>).
        <ls_state>-state = COND #( WHEN <ls_state>-mandatory = abap_true AND condense( <ls_state>-value ) = ``
                                   THEN `Error` ).
      ENDLOOP.
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

    IF on_filter_event( client ) = abap_true.
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
        "a MultiInput keeps what it had and gets the new values as tokens
        IF <ls_filter>-control = z2ui5_cl_rap_util=>cs_filter_control-multi.
          DATA(lt_parts) = z2ui5_cl_rap_util=>split_filter_value( <ls_filter>-value ).
          LOOP AT lt_exact INTO DATA(lv_exact).
            IF NOT line_exists( lt_parts[ table_line = lv_exact ] ).
              APPEND lv_exact TO lt_parts.
            ENDIF.
          ENDLOOP.
          <ls_filter>-value = concat_lines_of( table = lt_parts sep = `;` ).
        ELSE.
          <ls_filter>-value = concat_lines_of( table = lt_exact sep = `;` ).
        ENDIF.
        update_filter_tokens( ).
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

    "the rows are read - the table's text is that of no match from now on
    mv_loaded = abap_true.
    mv_no_data = get_text( cs_text-not_found ).

    "a mandatory filter without a value: no rows until it has one
    IF get_missing_filters( ) IS NOT INITIAL.
      mr_data = create_entity_table(
        entity_name    = mv_cds_view
        with_selection = has_selection( ) ).
      mv_count = `0`.
      mv_more = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_where) = get_where_clause( ).
    mr_data = select_rows(
      entity_name    = mv_cds_view
      where          = lv_where
      max_rows       = mv_max_rows
      with_selection = has_selection( )
      order_by       = get_order_by( ) ).
    IF mr_data IS BOUND.
      DATA(lv_count) = count_rows( entity_name = mv_cds_view
                                   where       = lv_where ).
      mv_count = |{ lv_count }|.
      FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
      ASSIGN mr_data->* TO <lt_data>.
      mv_more = xsdbool( lv_count > lines( <lt_data> ) ).
      "the files stay on the server - the object page reads them (since
      "2026-10, third round)
      z2ui5_cl_rap_util=>clear_large_objects( data      = mr_data
                                              it_fields = ms_entity-fields ).
      apply_row_states( ).
      apply_text_columns( ).
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

    "what the start's selection variant restricts beyond the filter bar
    "(an OR, parentheses - since 2026-10, third round)
    IF mv_variant_where IS NOT INITIAL.
      APPEND |( { mv_variant_where } )| TO lt_and.
    ENDIF.

    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD get_order_by.

    DATA lt_order TYPE string_table.
    DATA lt_used TYPE string_table.

    "the group field first - the rows of a group follow each other (since
    "2026-10, third round)
    IF mv_group_field IS NOT INITIAL AND line_exists( mt_sort_field[ name = mv_group_field ] ).
      APPEND mv_group_field TO lt_order.
      APPEND mv_group_field TO lt_used.
    ENDIF.

    "only a field the sort select offers - a STRING (LOB) column in an
    "ORDER BY is invalid SQL and would empty the whole list
    IF mv_sort_field IS NOT INITIAL AND line_exists( mt_sort_field[ name = mv_sort_field ] )
      AND NOT line_exists( lt_used[ table_line = mv_sort_field ] ).
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

    "the qualified @UI.lineItem of the presentation variant the list
    "started with (since 2026-10, third round)
    IF mv_line_item_qualifier IS NOT INITIAL.
      result = z2ui5_cl_rap_util=>get_line_item_columns( it_fields = ms_entity-fields
                                                         qualifier = mv_line_item_qualifier ).
      IF result IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

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
    result = get_ordered_columns( ).
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
    mv_start_auto = abap_true.
    IF z2ui5_cl_rap_variant=>is_available( ) = abap_false.
      RETURN.
    ENDIF.
    mt_variants = z2ui5_cl_rap_variant=>read_all( mv_cds_view ).

    mv_variant = cv_variant_standard.
    APPEND VALUE #( key = cv_variant_standard text = get_text( cs_text-standard ) ) TO mt_variant_item.
    LOOP AT mt_variants INTO DATA(ls_variant).
      "another user's public view: its name and whose it is
      APPEND VALUE #( key  = get_variant_key( ls_variant )
                      text = COND #( WHEN ls_variant-owner IS INITIAL THEN ls_variant-name
                                     ELSE |{ ls_variant-name } ({ ls_variant-owner })| ) ) TO mt_variant_item.
      IF ls_variant-is_default = abap_true AND ls_variant-owner IS INITIAL.
        mv_variant = ls_variant-name.
        mv_start_auto = ls_variant-auto_apply.
        apply_variant( ls_variant-data ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD capture_variant.
    LOOP AT mt_filter INTO DATA(ls_filter).
      APPEND VALUE #( name = ls_filter-name value = ls_filter-value ) TO result-filters.
      "the fields of the filter bar - adapt filters (since 2026-10, third
      "round, like the columns' order and widths and the group field)
      APPEND ls_filter-name TO result-filter_fields.
    ENDLOOP.
    result-search = mv_search.
    result-sort_field = mv_sort_field.
    result-sort_desc = mv_sort_desc.
    result-hidden_columns = mt_hidden_column.
    result-column_order = mt_column_order.
    result-column_widths = mt_column_width.
    result-group_field = mv_group_field.
  ENDMETHOD.


  METHOD apply_variant.

    DATA lt_filter TYPE ty_t_filter.
    DATA(lt_adaptable) = get_adaptable_fields( ).

    "the fields of the view's filter bar - a mandatory filter always, a
    "field the entity no longer has never (since 2026-10, third round)
    IF is_data-filter_fields IS NOT INITIAL.
      LOOP AT is_data-filter_fields INTO DATA(lv_filter_field).
        READ TABLE mt_filter INTO DATA(ls_kept) WITH KEY name = lv_filter_field.
        IF sy-subrc = 0.
          APPEND ls_kept TO lt_filter.
          CONTINUE.
        ENDIF.
        READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = lv_filter_field.
        IF sy-subrc = 0 AND line_exists( lt_adaptable[ name = lv_filter_field ] ).
          DATA(ls_added) = create_filter( ls_field ).
          ls_added-is_added = xsdbool( ls_field-is_selection_field = abap_false ).
          APPEND ls_added TO lt_filter.
        ENDIF.
      ENDLOOP.
      LOOP AT mt_filter INTO DATA(ls_mandatory) WHERE mandatory = abap_true.
        IF NOT line_exists( lt_filter[ name = ls_mandatory-name ] ).
          APPEND ls_mandatory TO lt_filter.
        ENDIF.
      ENDLOOP.
      mt_filter = lt_filter.
    ENDIF.

    "only the filters the list has - a view of an older version of the
    "entity may name others
    LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>).
      READ TABLE is_data-filters INTO DATA(ls_value) WITH KEY name = <ls_filter>-name.
      <ls_filter>-value = COND #( WHEN sy-subrc = 0 THEN ls_value-value ).
      CLEAR: <ls_filter>-state, <ls_filter>-input.
    ENDLOOP.
    update_filter_tokens( ).
    mv_search = is_data-search.
    IF is_data-sort_field IS INITIAL OR line_exists( mt_sort_field[ name = is_data-sort_field ] ).
      mv_sort_field = is_data-sort_field.
      mv_sort_desc = is_data-sort_desc.
    ENDIF.
    mt_hidden_column = is_data-hidden_columns.
    mt_column_order = is_data-column_order.
    mt_column_width = is_data-column_widths.
    IF is_data-group_field IS INITIAL OR line_exists( mt_sort_field[ name = is_data-group_field ] ).
      mv_group_field = is_data-group_field.
    ENDIF.

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

    "only the user's own view - another user's public one is not theirs
    DATA(lv_deletable) = xsdbool( mv_variant IS NOT INITIAL AND mv_variant <> cv_variant_standard
                                  AND line_exists( mt_variants[ name = mv_variant owner = `` ] ) ).
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

    DATA(lo_variant_box) = lo_dialog->ele( `content`
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

    "public and apply automatically - where the table has their columns
    "(since 2026-10, third round)
    IF z2ui5_cl_rap_variant=>has_public_views( ) = abap_true.
      lo_variant_box->tag( `CheckBox`
          )->a( n = `text`
                t = get_text( cs_text-public )
          )->a( n = `selected`
                v = client->_bind( mv_variant_public )
      )->tag( `CheckBox`
          )->a( n = `text`
                t = get_text( cs_text-auto_apply )
          )->a( n = `selected`
                v = client->_bind( mv_variant_auto ) ).
    ENDIF.

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
                  v = `32rem` ).

    "the group field (since 2026-10, third round)
    DATA(lo_column_content) = lo_dialog->ele( `content` ).
    lo_column_content->ele( `HBox`
        )->a( n = `alignItems`
              v = `Center`
        )->a( n = `class`
              v = `sapUiSmallMarginBeginEnd`
        )->tag( `Label`
            )->a( n = `text`
                  t = get_text( cs_text-group_by )
            )->a( n = `class`
                  v = `sapUiSmallMarginEnd`
        )->ele( `Select`
            )->a( n = `selectedKey`
                  v = client->_bind( mv_group_field )
            )->a( n = `items`
                  v = client->_bind( mt_group_item )
            )->a( n = `forceSelection`
                  v = `false`
            )->tag( n  = `Item`
                    ns = `core`
                )->a( n = `key`
                      v = `{KEY}`
                )->a( n = `text`
                      v = `{TEXT}` ).

    "visible, label, width, order - a row per column
    DATA(lo_column_table) = lo_column_content->ele( `Table`
        )->a( n = `items`
              v = client->_bind( mt_column ) ).
    lo_column_table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width`
                  v = `3rem`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text`
                      t = get_text( cs_text-columns )
        )->end(
        )->ele( `Column`
            )->a( n = `width`
                  v = `8rem`
            )->tag( `Text`
                )->a( n = `text`
                      t = get_text( cs_text-width )
        )->end(
        )->ele( `Column`
            )->a( n = `width`
                  v = `6rem` ).
    lo_column_table->ele( `items`
        )->ele( `ColumnListItem`
            )->tag( `CheckBox`
                )->a( n = `selected`
                      v = `{VISIBLE}`
            )->tag( `Text`
                )->a( n = `text`
                      v = `{LABEL}`
            )->tag( `Input`
                )->a( n = `value`
                      v = `{WIDTH}`
                )->a( n = `placeholder`
                      v = `10rem`
            )->ele( `HBox`
                )->tag( `Button`
                    )->a( n = `icon`
                          v = `sap-icon://navigation-up-arrow`
                    )->a( n = `type`
                          v = `Transparent`
                    )->a( n = `tooltip`
                          t = get_text( cs_text-move_up )
                    )->a( n = `press`
                          v = client->_event( val = cs_event-column_up
                                              arg = `${NAME}` )
                )->tag( `Button`
                    )->a( n = `icon`
                          v = `sap-icon://navigation-down-arrow`
                    )->a( n = `type`
                          v = `Transparent`
                    )->a( n = `tooltip`
                          t = get_text( cs_text-move_down )
                    )->a( n = `press`
                          v = client->_event( val = cs_event-column_down
                                              arg = `${NAME}` ) ).

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

    DATA lv_index TYPE i.
    DATA ls_column TYPE ty_s_column.
    DATA ls_variant TYPE z2ui5_cl_rap_variant=>ty_s_variant.

    result = abap_true.
    CASE client->get_event( ).

      WHEN cs_event-variant_select.
        "a view that does not apply automatically sets its filters and
        "waits for Go (since 2026-10, third round)
        DATA(lv_apply) = xsdbool( mv_initial_load <> cs_initial_load-disabled ).
        IF mv_variant = cv_variant_standard.
          apply_variant( ms_standard ).
        ELSE.
          LOOP AT mt_variants INTO ls_variant.
            IF get_variant_key( ls_variant ) = mv_variant.
              apply_variant( ls_variant-data ).
              lv_apply = ls_variant-auto_apply.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.
        IF lv_apply = abap_true OR mv_floorplan = cs_floorplan-worklist.
          load_data( ).
        ELSE.
          clear_rows( ).
        ENDIF.
        "the columns may differ - built into the view
        render_page( client ).

      WHEN cs_event-variant_save_open.
        CLEAR: mv_variant_name, mv_variant_default, mv_variant_public.
        mv_variant_auto = abap_true.
        "the user's own view is saved again, another user's under a name of
        "the user's own
        READ TABLE mt_variants INTO ls_variant WITH KEY name = mv_variant owner = ``.
        IF sy-subrc = 0 AND mv_variant <> cv_variant_standard.
          mv_variant_name = ls_variant-name.
          mv_variant_default = ls_variant-is_default.
          mv_variant_public = ls_variant-is_public.
          mv_variant_auto = ls_variant-auto_apply.
        ENDIF.
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
                                                              is_public  = mv_variant_public
                                                              auto_apply = mv_variant_auto
                                                              data       = capture_variant( ) ) ) = abap_false.
          client->message_box_display( text = get_text( cs_text-load_error )
                                       type = `error` ).
          RETURN.
        ENDIF.
        client->popup_destroy( ).
        "the views again - init_variants would apply the default
        DATA(ls_saved) = capture_variant( ).
        init_variants( ).
        apply_variant( ls_saved ).
        mv_variant = lv_name.
        render_page( client ).
        client->message_toast_display( get_text( cs_text-view_saved ) ).

      WHEN cs_event-variant_delete.
        IF mv_variant <> cv_variant_standard AND mv_variant IS NOT INITIAL
          AND line_exists( mt_variants[ name = mv_variant owner = `` ] ).
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
        "every column in the user's order, with its width (since 2026-10,
        "third round)
        CLEAR mt_column.
        LOOP AT get_ordered_columns( ) INTO DATA(ls_col).
          READ TABLE mt_column_width INTO DATA(ls_width) WITH KEY name = ls_col-name.
          APPEND VALUE #( name    = ls_col-name
                          label   = COND #( WHEN ls_col-line_item_label IS NOT INITIAL THEN ls_col-line_item_label
                                            ELSE ls_col-label )
                          visible = xsdbool( NOT line_exists( mt_hidden_column[ table_line = ls_col-name ] ) )
                          width   = COND #( WHEN sy-subrc = 0 THEN ls_width-value ELSE ls_col-line_item_width ) )
            TO mt_column.
        ENDLOOP.
        render_column_popup( client ).

      WHEN cs_event-column_up OR cs_event-column_down.
        READ TABLE mt_column INTO ls_column WITH KEY name = client->get_event_arg( ).
        IF sy-subrc = 0.
          lv_index = sy-tabix.
          DATA(lv_target) = COND i( WHEN client->get_event( ) = cs_event-column_up THEN lv_index - 1
                                    ELSE lv_index + 1 ).
          IF lv_target >= 1 AND lv_target <= lines( mt_column ).
            DELETE mt_column INDEX lv_index.
            INSERT ls_column INTO mt_column INDEX lv_target.
          ENDIF.
        ENDIF.
        render_column_popup( client ).

      WHEN cs_event-columns_ok.
        CLEAR: mt_hidden_column, mt_column_order, mt_column_width.
        LOOP AT mt_column INTO ls_column.
          IF ls_column-visible = abap_false.
            APPEND ls_column-name TO mt_hidden_column.
          ENDIF.
          APPEND ls_column-name TO mt_column_order.
          "a width the user gave - one the annotation gives needs no entry
          DATA(lv_width) = z2ui5_cl_rap_util=>normalize_css_width( ls_column-width ).
          READ TABLE ms_entity-fields INTO DATA(ls_width_field) WITH KEY name = ls_column-name.
          IF lv_width IS NOT INITIAL AND ( sy-subrc <> 0 OR lv_width <> ls_width_field-line_item_width ).
            APPEND VALUE #( name = ls_column-name value = lv_width ) TO mt_column_width.
          ENDIF.
        ENDLOOP.
        client->popup_destroy( ).
        "the group field orders the rows in the database
        IF mv_loaded = abap_true.
          load_data( ).
        ENDIF.
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
    FIELD-SYMBOLS <lt_selected> TYPE STANDARD TABLE.
    DATA lt_params TYPE ty_t_name_value.

    DATA(lv_arg) = client->get_event_arg( ).

    "a toolbar button: its target - with semanticObjectBinding the values
    "of the selected rows as parameters (since 2026-10, third round)
    READ TABLE ms_entity-actions INTO DATA(ls_intent) WITH KEY name = lv_arg.
    IF sy-subrc = 0 AND ls_intent-semantic_object IS NOT INITIAL.
      IF ls_intent-sem_object_bindings IS NOT INITIAL.
        DATA(lr_selected) = get_selected_rows( entity_name = mv_cds_view
                                               data        = mr_data ).
        IF lr_selected IS BOUND.
          ASSIGN lr_selected->* TO <lt_selected>.
          LOOP AT <lt_selected> ASSIGNING FIELD-SYMBOL(<ls_selected>).
            APPEND LINES OF z2ui5_cl_rap_util=>get_navigation_params(
              row      = <ls_selected>
              bindings = ls_intent-sem_object_bindings ) TO lt_params.
          ENDLOOP.
        ENDIF.
        IF lt_params IS INITIAL.
          client->message_toast_display( get_text( cs_text-no_selection ) ).
          RETURN.
        ENDIF.
      ENDIF.
      navigate_to_intent( client          = client
                          semantic_object = ls_intent-semantic_object
                          action          = ls_intent-semantic_action
                          params          = lt_params ).
      RETURN.
    ENDIF.

    "a column's link: the value (mapped by the semantic object's bindings)
    "and the row's keys as parameters
    READ TABLE ms_entity-fields INTO DATA(ls_col) WITH KEY name = lv_arg.
    IF sy-subrc <> 0 OR ( ls_col-line_item_sem_object IS INITIAL AND ls_col-semantic_object IS INITIAL ).
      RETURN.
    ENDIF.
    DATA(lv_object) = COND string( WHEN ls_col-line_item_sem_object IS NOT INITIAL THEN ls_col-line_item_sem_object
                                   ELSE ls_col-semantic_object ).
    DATA(lr_row) = find_row_by_event_keys( data       = mr_data
                                           key_fields = mt_row_key
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS BOUND.
      ASSIGN lr_row->* TO <ls_row>.
      lt_params = z2ui5_cl_rap_util=>get_navigation_params( row      = <ls_row>
                                                            field    = ls_col-name
                                                            bindings = ls_col-sem_object_bindings ).
      LOOP AT mt_row_key INTO DATA(lv_name).
        IF line_exists( lt_params[ name = lv_name ] )
          OR line_exists( ls_col-sem_object_bindings[ local_element = lv_name ] ).
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
                        semantic_object = lv_object
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
      "the parameter first - the action runs on the return (on_navigated);
      "its default function fills it (since 2026-10, third round)
      ASSIGN lr_param->* TO FIELD-SYMBOL(<ls_param>).
      apply_action_defaults( EXPORTING entity_name = mv_cds_view
                                       action      = mv_pending_action
                                       rows        = get_action_rows( )
                             CHANGING  param       = <ls_param> ).
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


  METHOD get_action_rows.

    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    IF mt_pending_keys IS INITIAL.
      result = get_selected_rows( entity_name = mv_cds_view
                                  data        = mr_data ).
      RETURN.
    ENDIF.
    "the row of an inline action, found again by its keys
    DATA(lr_row) = find_row_by_keys( data       = mr_data
                                     key_fields = mt_row_key
                                     key_values = mt_pending_keys ).
    result = create_entity_table( mv_cds_view ).
    IF lr_row IS BOUND AND result IS BOUND.
      ASSIGN result->* TO <lt_rows>.
      ASSIGN lr_row->* TO <ls_row>.
      APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_new>).
      MOVE-CORRESPONDING <ls_row> TO <ls_new>.
    ENDIF.

  ENDMETHOD.


  METHOD execute_action.

    DATA(lr_rows) = get_action_rows( ).

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
                       details  = ls_result-details
                       fields   = ms_entity-fields
                       type     = `success` ).
      ENDIF.
    ELSE.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
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

    DATA(lv_adaptable) = xsdbool( get_adaptable_fields( ) IS NOT INITIAL ).
    IF mt_filter IS INITIAL AND ms_entity-is_searchable = abap_false AND mv_is_draft_bo = abap_false
      AND lv_adaptable = abap_false.
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

    "further filter fields at runtime (since 2026-10, third round)
    IF lv_adaptable = abap_true.
      lo_bar->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-adapt_filters )
          )->a( n = `type`
                v = `Transparent`
          )->a( n = `press`
                v = client->_event( cs_event-adapt_filters ) ).
    ENDIF.

    lo_bar->tag( `Button`
        )->a( n = `text`
              t = get_text( cs_text-go )
        )->a( n = `type`
              v = `Emphasized`
        )->a( n = `press`
              v = client->_event( cs_event-go )
        )->a( n = `icon`
              v = `sap-icon://search` ).

    IF mt_filter IS INITIAL.
      RETURN.
    ENDIF.

    "the filters - a label over the control of each field's type: an input
    "with the filter syntax, a MultiInput with tokens, a list, a date or a
    "date range (since 2026-10, third round); the conditions button
    "defines conditions. One template for every filter, so each control is
    "visible by the filter's CONTROL
    DATA(lv_filter_state) = `{= ${STATE} === 'Error' ? 'Error' : 'None' }`.
    DATA(lo_filter_box) = io_page->ele( `HBox`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->a( n = `items`
              v = client->_bind( mt_filter )
        )->a( n = `wrap`
              v = `Wrap`
        )->a( n = `class`
              v = `sapUiSmallMarginBeginEnd sapUiSmallMarginTop` ).

    DATA(lo_filter_item) = lo_filter_box->ele( `VBox`
        )->a( n = `visible`
              v = `{= !${HIDDEN} }`
        )->a( n = `class`
              v = `sapUiSmallMarginEnd sapUiTinyMarginBottom`
        )->tag( `Label`
            )->a( n = `text`
                  v = `{LABEL}`
            )->a( n = `tooltip`
                  t = get_text( cs_text-filter_hint ) ).

    DATA(lo_filter_line) = lo_filter_item->ele( `HBox`
        )->a( n = `alignItems`
              v = `Center` ).

    "a hidden filter is not shown - its default still restricts the rows
    lo_filter_line->tag( `Input`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'INPUT' }`
        )->a( n = `value`
              v = `{VALUE}`
        )->a( n = `tooltip`
              t = get_text( cs_text-filter_hint )
        )->a( n = `showValueHelp`
              v = `{SHOW_VH}`
        )->a( n = `valueHelpRequest`
              v = client->_event( val = cs_event-value_help
                                  arg = `${NAME}` )
        )->a( n = `submit`
              v = client->_event( cs_event-go )
        )->a( n = `valueState`
              v = lv_filter_state
        )->a( n = `width`
              v = `12rem` ).

    "a value help that takes several values: a token per value
    lo_filter_line->ele( `MultiInput`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'MULTI' }`
        )->a( n = `value`
              v = `{INPUT}`
        )->a( n = `tokens`
              v = `{TOKENS}`
        )->a( n = `showValueHelp`
              v = `true`
        )->a( n = `valueHelpRequest`
              v = client->_event( val = cs_event-value_help
                                  arg = `${NAME}` )
        )->a( n = `submit`
              v = client->_event( val = cs_event-filter_token_add
                                  arg = `${NAME}` )
        )->a( n = `valueState`
              v = lv_filter_state
        )->a( n = `width`
              v = `15rem`
        )->ele( `tokens`
            )->tag( `Token`
                )->a( n = `key`
                      v = `{KEY}`
                )->a( n = `text`
                      v = `{TEXT}`
                )->a( n = `delete`
                      v = client->_event( val = cs_event-filter_token_delete
                                          arg = `${KEY}` ) ).

    "a boolean, fixed values, a dropdown value help
    lo_filter_line->ele( `Select`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'LIST' }`
        )->a( n = `selectedKey`
              v = `{VALUE}`
        )->a( n = `items`
              v = `{ENTRIES}`
        )->a( n = `forceSelection`
              v = `false`
        )->a( n = `valueState`
              v = lv_filter_state
        )->a( n = `width`
              v = `12rem`
        )->tag( n  = `Item`
                ns = `core`
            )->a( n = `key`
                  v = `{KEY}`
            )->a( n = `text`
                  v = `{TEXT}` ).

    "a date: one day, or a range - the model's form, from..to
    lo_filter_line->tag( `DatePicker`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'DATE' }`
        )->a( n = `value`
              v = `{VALUE}`
        )->a( n = `valueFormat`
              v = `yyyy-MM-dd`
        )->a( n = `valueState`
              v = lv_filter_state
        )->a( n = `width`
              v = `12rem`
    )->tag( `DateRangeSelection`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'DATE_RANGE' }`
        )->a( n = `value`
              v = `{VALUE}`
        )->a( n = `displayFormat`
              v = `yyyy-MM-dd`
        )->a( n = `delimiter`
              v = `..`
        )->a( n = `valueState`
              v = lv_filter_state
        )->a( n = `width`
              v = `15rem`
    )->tag( `Button`
        )->a( n = `visible`
              v = `{= ${CONTROL} === 'INPUT' || ${CONTROL} === 'MULTI' }`
        )->a( n = `icon`
              v = `sap-icon://filter`
        )->a( n = `type`
              v = `Transparent`
        )->a( n = `tooltip`
              t = get_text( cs_text-define_conditions )
        )->a( n = `press`
              v = client->_event( val = cs_event-conditions
                                  arg = `${NAME}` ) ).

  ENDMETHOD.


  METHOD render_table.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN mr_data->* TO <lt_data>.

    DATA(lt_columns) = get_visible_columns( ).
    DATA(lt_inline) = get_line_item_actions( abap_true ).
    DATA(lv_select) = has_selection( ).
    "the rows are selectable when there are actions to run on them, or a
    "navigation that takes their values
    DATA(lv_mode) = `None`.
    IF lv_select = abap_true.
      lv_mode = `MultiSelect`.
    ENDIF.

    "grouped by the group field: a group header row per value - the rows
    "come ordered by it from the database (since 2026-10, third round)
    DATA(lv_items) = `{path:'` && client->_bind( val  = <lt_data>
                                                 path = abap_true ) && `'`.
    IF mv_group_field IS NOT INITIAL AND line_exists( mt_sort_field[ name = mv_group_field ] ).
      lv_items = lv_items && `, sorter: {path: '` && mv_group_field && `', group: true}`.
    ENDIF.
    lv_items = lv_items && `}`.

    DATA(lo_table) = io_page->ele( `Table`
        )->a( n = `items`
              v = lv_items
        )->a( n = `noDataText`
              v = client->_bind( mv_no_data )
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
    "the row's criticality - the entity's own @UI.lineItem (since 2026-10,
    "third round)
    IF ms_entity-row_criticality IS NOT INITIAL AND line_exists( ms_entity-fields[ name = ms_entity-row_criticality ] ).
      lo_row->a( n = `highlight`
                 v = criticality_expression( crit_field = ms_entity-row_criticality
                                             kind       = `HIGHLIGHT` ) ).
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

    "@UI.lineItem importance drives responsive popin behavior - a semantic
    "key without one is HIGH (since 2026-10, third round)
    DATA(lv_importance) = to_upper( is_col-line_item_importance ).
    IF lv_importance IS INITIAL AND line_exists( ms_entity-semantic_key[ table_line = is_col-name ] ).
      lv_importance = `HIGH`.
    ENDIF.
    DATA(lv_min_screen) = ``.
    IF lv_importance CS `MEDIUM`.
      lv_min_screen = `Tablet`.
    ELSEIF lv_importance CS `LOW`.
      lv_min_screen = `Desktop`.
    ENDIF.
    "the user's width (the columns dialog, a view), else
    "@UI.lineItem.cssDefault.width
    READ TABLE mt_column_width INTO DATA(ls_user_width) WITH KEY name = is_col-name.
    DATA(lv_col_width) = z2ui5_cl_rap_util=>normalize_css_width(
      COND #( WHEN sy-subrc = 0 THEN ls_user_width-value ELSE is_col-line_item_width ) ).

    DATA(lo_column) = io_columns->ele( `Column` ).
    IF lv_min_screen IS NOT INITIAL.
      lo_column->a( n = `minScreenWidth`
                    t = lv_min_screen
          )->a( n = `demandPopin`
                v = `true` ).
    ENDIF.
    IF lv_col_width IS NOT INITIAL.
      lo_column->a( n = `width`
                    v = lv_col_width ).
    ENDIF.
    lo_column->tag( `Text`
        )->a( n = `text`
              t = lv_col_label
        )->a( n = `tooltip`
              t = is_col-tooltip ).

  ENDMETHOD.


  METHOD render_cell.

    DATA lt_group TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    DATA(lv_path) = |\{{ is_col-name }\}|.
    DATA(ls_cell) = is_col.

    "the arguments of a link that needs its row: the column, the row's keys
    DATA(lt_link_arg) = VALUE string_table( ( is_col-name ) ).
    LOOP AT mt_row_key INTO DATA(lv_key).
      APPEND `${` && lv_key && `}` TO lt_link_arg.
    ENDLOOP.

    "hidden: #(Field) - the field of the row hides the cell (since 2026-10,
    "third round, like the branches below that say so)
    DATA(lo_cell) = io_cells.
    IF is_col-line_item_hidden IS NOT INITIAL AND is_col-line_item_hidden <> `TRUE`
      AND line_exists( ms_entity-fields[ name = is_col-line_item_hidden ] ).
      lo_cell = io_cells->ele( `VBox`
          )->a( n = `visible`
                v = `{= !${` && is_col-line_item_hidden && `} }` ).
    ENDIF.

    "@ObjectModel.text.association: the text read for the rows
    DATA(lv_text_column) = get_text_column( is_col ).
    IF ls_cell-text_element IS INITIAL AND lv_text_column IS NOT INITIAL.
      ls_cell-text_element = lv_text_column.
    ENDIF.
    DATA(lv_has_text) = xsdbool( ls_cell-text_element IS NOT INITIAL
                                 AND ( line_exists( ms_entity-fields[ name = ls_cell-text_element ] )
                                       OR ls_cell-text_element = lv_text_column ) ).

    "#AS_FIELDGROUP -> the fields of the field group, one under the other
    IF is_col-line_item_type = `AS_FIELDGROUP` AND is_col-line_item_value_qualifier IS NOT INITIAL.
      LOOP AT ms_entity-fields INTO DATA(ls_group_field) WHERE is_hidden = abap_false.
        READ TABLE ls_group_field-field_groups INTO DATA(ls_group)
          WITH KEY qualifier = is_col-line_item_value_qualifier.
        IF sy-subrc = 0.
          ls_group_field-field_group_pos = ls_group-position.
          APPEND ls_group_field TO lt_group.
        ENDIF.
      ENDLOOP.
      SORT lt_group BY field_group_pos.
      DATA(lo_group) = lo_cell->ele( `VBox` ).
      LOOP AT lt_group INTO ls_group_field.
        lo_group->tag( `Text`
            )->a( n = `text`
                  v = COND string( WHEN ls_group_field-text_element IS NOT INITIAL
                                     AND line_exists( ms_entity-fields[ name = ls_group_field-text_element ] )
                                   THEN |\{{ ls_group_field-text_element }\} (\{{ ls_group_field-name }\})|
                                   ELSE |\{{ ls_group_field-name }\}| ) ).
      ENDLOOP.

    "#WITH_URL -> a link to the URL in another field
    ELSEIF is_col-line_item_type = `WITH_URL` AND is_col-line_item_url IS NOT INITIAL
      AND line_exists( ms_entity-fields[ name = is_col-line_item_url ] ).
      lo_cell->tag( `Link`
          )->a( n = `text`
                v = lv_path
          )->a( n = `href`
                v = |\{{ is_col-line_item_url }\}|
          )->a( n = `target`
                v = `_blank` ).

    "#WITH_NAVIGATION_PATH -> the object page of the associated record
    ELSEIF is_col-line_item_type = `WITH_NAVIGATION_PATH` AND is_col-line_item_target IS NOT INITIAL
      AND client IS BOUND AND mt_row_key IS NOT INITIAL.
      lo_cell->tag( `Link`
          )->a( n = `text`
                v = lv_path
          )->a( n = `press`
                v = client->_event( val   = cs_event-nav_path
                                    t_arg = lt_link_arg ) ).

    "#WITH_INTENT_BASED_NAVIGATION, @Consumption.semanticObject -> another
    "app of the launchpad
    ELSEIF ( ( is_col-line_item_type = `WITH_INTENT_BASED_NAVIGATION` AND is_col-line_item_sem_object IS NOT INITIAL )
             OR is_col-semantic_object IS NOT INITIAL )
      AND client IS BOUND AND mt_row_key IS NOT INITIAL.
      lo_cell->tag( `Link`
          )->a( n = `text`
                v = COND string( WHEN lv_has_text = abap_true THEN |\{{ ls_cell-text_element }\} ({ lv_path })| ELSE lv_path )
          )->a( n = `press`
                v = client->_event( val   = cs_event-intent
                                    t_arg = lt_link_arg ) ).

    "@Semantics.imageUrl -> the image
    ELSEIF is_col-is_image_url = abap_true.
      lo_cell->tag( `Avatar`
          )->a( n = `src`
                v = lv_path
          )->a( n = `displaySize`
                v = `XS`
          )->a( n = `displayShape`
                v = `Square` ).

    "criticality -> ObjectStatus, with its icon unless #WITHOUT_ICON
    ELSEIF is_col-datapoint_crit_field IS NOT INITIAL
      OR is_col-line_item_crit_field IS NOT INITIAL.
      DATA(lv_crit_field) = is_col-line_item_crit_field.
      IF lv_crit_field IS INITIAL.
        lv_crit_field = is_col-datapoint_crit_field.
      ENDIF.
      DATA(lo_status) = lo_cell->tag( `ObjectStatus`
          )->a( n = `text`
                v = COND string( WHEN lv_has_text = abap_true THEN |\{{ ls_cell-text_element }\} ({ lv_path })| ELSE lv_path )
          )->a( n = `state`
                v = criticality_expression( lv_crit_field ) ).
      IF is_col-line_item_crit_repr <> `WITHOUT_ICON`.
        lo_status->a( n = `icon`
                      v = criticality_expression( crit_field = lv_crit_field
                                                  kind       = `ICON` ) ).
      ENDIF.

    "amount + currency -> ObjectNumber
    ELSEIF is_col-is_amount_field = abap_true
      AND is_col-semantics_currency_code IS NOT INITIAL.
      lo_cell->tag( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = |\{{ is_col-semantics_currency_code }\}| ).

    "quantity + unit -> ObjectNumber
    ELSEIF is_col-is_quantity_field = abap_true
      AND is_col-semantics_unit_of_measure IS NOT INITIAL.
      lo_cell->tag( `ObjectNumber`
          )->a( n = `number`
                v = lv_path
          )->a( n = `unit`
                v = |\{{ is_col-semantics_unit_of_measure }\}| ).

    "@ObjectModel.semanticKey -> bold, with its text beneath
    ELSEIF line_exists( ms_entity-semantic_key[ table_line = is_col-name ] ).
      DATA(lo_identifier) = lo_cell->tag( `ObjectIdentifier`
          )->a( n = `title`
                v = lv_path ).
      IF lv_has_text = abap_true.
        lo_identifier->a( n = `text`
                          v = |\{{ ls_cell-text_element }\}| ).
      ENDIF.

    "iconUrl -> the icon in front of the value
    ELSEIF is_col-line_item_icon_url IS NOT INITIAL.
      lo_cell->ele( `HBox`
          )->a( n = `xmlns:core`
                v = `sap.ui.core`
          )->a( n = `alignItems`
                v = `Center`
          )->tag( n  = `Icon`
                  ns = `core`
              )->a( n = `src`
                    t = is_col-line_item_icon_url
              )->a( n = `class`
                    v = `sapUiTinyMarginEnd`
          )->tag( `Text`
              )->a( n = `text`
                    v = lv_path ).

    "@ObjectModel.text.element, arranged by @UI.textArrangement - "Text
    "(Value)" is the Fiori default
    ELSEIF lv_has_text = abap_true.
      CASE is_col-text_arrangement.
        WHEN `TEXT_LAST`.
          lo_cell->tag( `Text`
              )->a( n = `text`
                    v = |{ lv_path } (\{{ ls_cell-text_element }\})| ).
        WHEN `TEXT_ONLY`.
          lo_cell->tag( `Text`
              )->a( n = `text`
                    v = |\{{ ls_cell-text_element }\}| ).
        WHEN `TEXT_SEPARATE`.
          lo_cell->tag( `Text`
              )->a( n = `text`
                    v = lv_path ).
        WHEN OTHERS.
          lo_cell->tag( `Text`
              )->a( n = `text`
                    v = |\{{ ls_cell-text_element }\} ({ lv_path })| ).
      ENDCASE.

    ELSE.
      lo_cell->tag( `Text`
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


  METHOD create_filter.

    result = VALUE #(
      name      = is_field-name
      label     = COND #( WHEN is_field-filter_mandatory = abap_true THEN |{ is_field-label } *| ELSE is_field-label )
      value     = is_field-filter_default
      show_vh   = xsdbool( is_field-value_help-entity_name IS NOT INITIAL )
      mandatory = is_field-filter_mandatory
      single    = is_field-filter_single
      hidden    = is_field-filter_hidden
      control   = z2ui5_cl_rap_util=>get_filter_control( is_field ) ).

    IF result-control <> z2ui5_cl_rap_util=>cs_filter_control-list.
      RETURN.
    ENDIF.
    "a boolean or fixed values: their entries; a dropdown value help: the
    "rows of its entity, the text by its text element
    IF is_field-is_boolean = abap_true OR is_field-value_help-fixed_values IS NOT INITIAL.
      LOOP AT z2ui5_cl_rap_util=>get_filter_list( is_field = is_field
                                                  yes      = get_text( cs_text-yes )
                                                  no       = get_text( cs_text-no ) ) INTO DATA(ls_entry).
        APPEND VALUE #( key = ls_entry-name text = ls_entry-value ) TO result-entries.
      ENDLOOP.
      RETURN.
    ENDIF.

    APPEND VALUE #( ) TO result-entries.
    DATA(lr_rows) = select_rows( entity_name = is_field-value_help-entity_name
                                 max_rows    = 200 ).
    IF lr_rows IS NOT BOUND.
      "no entries - the value help input instead
      result-control = z2ui5_cl_rap_util=>cs_filter_control-input.
      CLEAR result-entries.
      RETURN.
    ENDIF.
    DATA(ls_list_entity) = z2ui5_cl_rap_util=>read_entity( is_field-value_help-entity_name ).
    READ TABLE ls_list_entity-fields INTO DATA(ls_element) WITH KEY name = is_field-value_help-element.
    DATA(lv_text_field) = COND string( WHEN sy-subrc = 0 THEN ls_element-text_element ).
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_key> TYPE any.
    FIELD-SYMBOLS <lv_text> TYPE any.
    ASSIGN lr_rows->* TO <lt_rows>.
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      UNASSIGN: <lv_key>, <lv_text>.
      ASSIGN COMPONENT is_field-value_help-element OF STRUCTURE <ls_row> TO <lv_key>.
      IF <lv_key> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      DATA(lv_entry_key) = condense( |{ <lv_key> }| ).
      IF lv_text_field IS NOT INITIAL.
        ASSIGN COMPONENT lv_text_field OF STRUCTURE <ls_row> TO <lv_text>.
      ENDIF.
      APPEND VALUE #( key  = |={ lv_entry_key }|
                      text = COND #( WHEN <lv_text> IS ASSIGNED AND <lv_text> IS NOT INITIAL
                                     THEN |{ <lv_text> } ({ lv_entry_key })|
                                     ELSE lv_entry_key ) ) TO result-entries.
    ENDLOOP.

  ENDMETHOD.


  METHOD update_filter_tokens.

    DATA lv_index TYPE i.

    LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>)
      WHERE control = z2ui5_cl_rap_util=>cs_filter_control-multi.
      CLEAR <ls_filter>-tokens.
      lv_index = 0.
      LOOP AT z2ui5_cl_rap_util=>split_filter_value( <ls_filter>-value ) INTO DATA(lv_part).
        lv_index = lv_index + 1.
        "an exact value shows without its =
        DATA(lv_token_text) = COND string( WHEN strlen( lv_part ) > 1 AND lv_part(1) = `=`
                                           THEN substring( val = lv_part off = 1 )
                                           ELSE lv_part ).
        APPEND VALUE #( key  = |{ <ls_filter>-name }~{ lv_index }|
                        text = lv_token_text ) TO <ls_filter>-tokens.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD take_filter_inputs.

    LOOP AT mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>)
      WHERE control = z2ui5_cl_rap_util=>cs_filter_control-multi AND input IS NOT INITIAL.
      DATA(lv_input) = condense( <ls_filter>-input ).
      IF lv_input IS NOT INITIAL.
        <ls_filter>-value = COND #( WHEN <ls_filter>-value IS INITIAL THEN lv_input
                                    ELSE |{ <ls_filter>-value };{ lv_input }| ).
      ENDIF.
      CLEAR <ls_filter>-input.
    ENDLOOP.
    update_filter_tokens( ).

  ENDMETHOD.


  METHOD apply_presentation_variants.

    DATA lt_presets TYPE ty_t_name_value.
    DATA lv_where TYPE string.
    DATA lv_presentation TYPE string.
    DATA lv_selection TYPE string.

    "the selection presentation variant: the unqualified one, else the
    "first - without one the unqualified presentation and selection
    "variant
    READ TABLE ms_entity-sel_pres_variants INTO DATA(ls_spv) WITH KEY qualifier = ``.
    IF sy-subrc <> 0.
      READ TABLE ms_entity-sel_pres_variants INTO ls_spv INDEX 1.
    ENDIF.
    IF sy-subrc = 0.
      lv_presentation = ls_spv-presentation_qualifier.
      lv_selection = ls_spv-selection_qualifier.
    ENDIF.

    "the presentation variant: sort order, groupBy, its @UI.lineItem
    READ TABLE ms_entity-presentation_variants INTO DATA(ls_pv) WITH KEY qualifier = lv_presentation.
    IF sy-subrc = 0.
      IF lv_presentation IS NOT INITIAL AND ls_pv-sort_order IS NOT INITIAL.
        ms_entity-sort_order = ls_pv-sort_order.
      ENDIF.
      IF lv_presentation IS NOT INITIAL AND ls_pv-group_by IS NOT INITIAL.
        ms_entity-group_by = ls_pv-group_by.
      ENDIF.
      IF ls_pv-visualization_type = `LINEITEM` AND ls_pv-visualization_qualifier IS NOT INITIAL
        AND z2ui5_cl_rap_util=>get_line_item_columns( it_fields = ms_entity-fields
                                                      qualifier = ls_pv-visualization_qualifier ) IS NOT INITIAL.
        mv_line_item_qualifier = ls_pv-visualization_qualifier.
      ENDIF.
    ENDIF.

    "the selection variant: its values in the filter bar, the rest as it
    "is - a worklist's selection variants are its tabs
    IF mv_floorplan = cs_floorplan-worklist.
      RETURN.
    ENDIF.
    READ TABLE ms_entity-selection_variants INTO DATA(ls_sv) WITH KEY qualifier = lv_selection.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    z2ui5_cl_rap_util=>selection_variant_filters( EXPORTING is_variant = ls_sv
                                                            it_fields  = ms_entity-fields
                                                  IMPORTING filters    = lt_presets
                                                            where      = lv_where ).
    mv_variant_where = lv_where.
    LOOP AT lt_presets INTO DATA(ls_preset).
      READ TABLE mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>) WITH KEY name = ls_preset-name.
      IF sy-subrc = 0.
        <ls_filter>-value = ls_preset-value.
        CONTINUE.
      ENDIF.
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = ls_preset-name.
      IF sy-subrc <> 0 OR ls_field-is_virtual = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_new_filter) = create_filter( ls_field ).
      ls_new_filter-value = ls_preset-value.
      ls_new_filter-is_added = abap_true.
      APPEND ls_new_filter TO mt_filter.
    ENDLOOP.

  ENDMETHOD.


  METHOD on_filter_event.

    DATA lv_index TYPE i.
    DATA lt_parts TYPE string_table.
    DATA lv_name TYPE string.
    DATA lv_number TYPE string.

    result = abap_true.
    CASE client->get_event( ).

      WHEN cs_event-filter_token_add.
        take_filter_inputs( ).

      WHEN cs_event-filter_token_delete.
        "the token's key: the filter~the part's number
        DATA(lv_token) = client->get_event_arg( ).
        DATA(lv_at) = find( val = lv_token sub = `~` occ = -1 ).
        IF lv_at > 0.
          lv_name = substring( val = lv_token len = lv_at ).
          lv_number = substring( val = lv_token off = lv_at + 1 ).
          READ TABLE mt_filter ASSIGNING FIELD-SYMBOL(<ls_filter>) WITH KEY name = lv_name.
          IF sy-subrc = 0 AND lv_number CO `0123456789` AND lv_number IS NOT INITIAL.
            lt_parts = z2ui5_cl_rap_util=>split_filter_value( <ls_filter>-value ).
            lv_index = lv_number.
            IF lv_index >= 1 AND lv_index <= lines( lt_parts ).
              DELETE lt_parts INDEX lv_index.
            ENDIF.
            <ls_filter>-value = concat_lines_of( table = lt_parts sep = `;` ).
          ENDIF.
        ENDIF.
        update_filter_tokens( ).

      WHEN cs_event-conditions.
        mv_condition_field = client->get_event_arg( ).
        READ TABLE mt_filter INTO DATA(ls_filter) WITH KEY name = mv_condition_field.
        READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = mv_condition_field.
        IF sy-subrc <> 0 OR ls_filter-name IS INITIAL.
          RETURN.
        ENDIF.
        mv_condition_title = |{ get_text( cs_text-define_conditions ) }: { ls_field-label }|.
        mt_condition_op = get_condition_operators( ).
        CLEAR mt_condition.
        LOOP AT z2ui5_cl_rap_util=>filter_to_conditions( value    = ls_filter-value
                                                         is_field = ls_field ) INTO DATA(ls_condition).
          APPEND VALUE #( id       = |{ lines( mt_condition ) + 1 }|
                          operator = ls_condition-operator
                          low      = ls_condition-low
                          high     = ls_condition-high
                          exclude  = ls_condition-exclude ) TO mt_condition.
        ENDLOOP.
        IF mt_condition IS INITIAL.
          APPEND VALUE #( id = `1` operator = z2ui5_cl_rap_util=>cs_condition_op-eq ) TO mt_condition.
        ENDIF.
        render_condition_popup( client ).

      WHEN cs_event-condition_add.
        "a number no row has
        lv_index = 0.
        LOOP AT mt_condition INTO DATA(ls_row).
          IF ls_row-id CO `0123456789` AND CONV i( ls_row-id ) > lv_index.
            lv_index = ls_row-id.
          ENDIF.
        ENDLOOP.
        APPEND VALUE #( id = |{ lv_index + 1 }| operator = z2ui5_cl_rap_util=>cs_condition_op-eq ) TO mt_condition.
        render_condition_popup( client ).

      WHEN cs_event-condition_delete.
        DELETE mt_condition WHERE id = client->get_event_arg( ).
        render_condition_popup( client ).

      WHEN cs_event-conditions_ok.
        READ TABLE mt_filter ASSIGNING <ls_filter> WITH KEY name = mv_condition_field.
        IF sy-subrc = 0.
          <ls_filter>-value = z2ui5_cl_rap_util=>conditions_to_filter(
            VALUE #( FOR ls_c IN mt_condition ( operator = ls_c-operator
                                                 low      = ls_c-low
                                                 high     = ls_c-high
                                                 exclude  = ls_c-exclude ) ) ).
          CLEAR <ls_filter>-state.
        ENDIF.
        update_filter_tokens( ).
        CLEAR: mv_condition_field, mt_condition.
        client->popup_destroy( ).

      WHEN cs_event-adapt_filters.
        CLEAR mt_adapt.
        LOOP AT get_adaptable_fields( ) INTO DATA(ls_adapt).
          APPEND VALUE #( name    = ls_adapt-name
                          label   = ls_adapt-label
                          visible = xsdbool( line_exists( mt_filter[ name = ls_adapt-name ] ) ) ) TO mt_adapt.
        ENDLOOP.
        render_adapt_popup( client ).

      WHEN cs_event-adapt_filters_ok.
        "a field chosen gets a filter, one deselected loses it - a
        "mandatory filter stays
        LOOP AT mt_adapt INTO DATA(ls_choice).
          DATA(lv_present) = xsdbool( line_exists( mt_filter[ name = ls_choice-name ] ) ).
          IF ls_choice-visible = abap_true AND lv_present = abap_false.
            READ TABLE ms_entity-fields INTO ls_field WITH KEY name = ls_choice-name.
            IF sy-subrc = 0.
              DATA(ls_added) = create_filter( ls_field ).
              ls_added-is_added = abap_true.
              APPEND ls_added TO mt_filter.
            ENDIF.
          ELSEIF ls_choice-visible = abap_false AND lv_present = abap_true.
            DELETE mt_filter WHERE name = ls_choice-name AND mandatory = abap_false.
          ENDIF.
        ENDLOOP.
        update_filter_tokens( ).
        client->popup_destroy( ).
        render_page( client ).

      WHEN OTHERS.
        result = abap_false.
    ENDCASE.

  ENDMETHOD.


  METHOD render_condition_popup.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`
                  t = mv_condition_title
            )->a( n = `contentWidth`
                  v = `40rem` ).

    "a row per condition: exclude, the operator, its values, delete
    DATA(lo_condition_table) = lo_dialog->ele( `content`
        )->ele( `Table`
            )->a( n = `items`
                  v = client->_bind( mt_condition ) ).
    lo_condition_table->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`
                      t = get_text( cs_text-add_condition )
                )->a( n = `icon`
                      v = `sap-icon://add`
                )->a( n = `press`
                      v = client->_event( cs_event-condition_add ) ).
    lo_condition_table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width`
                  v = `7rem`
            )->tag( `Text`
                )->a( n = `text`
                      t = get_text( cs_text-exclude )
        )->end(
        )->ele( `Column`
            )->a( n = `width`
                  v = `12rem`
        )->end(
        )->ele( `Column`
        )->end(
        )->ele( `Column`
        )->end(
        )->ele( `Column`
            )->a( n = `width`
                  v = `3rem` ).
    lo_condition_table->ele( `items`
        )->ele( `ColumnListItem`
            )->tag( `CheckBox`
                )->a( n = `selected`
                      v = `{EXCLUDE}`
            )->ele( `Select`
                )->a( n = `selectedKey`
                      v = `{OPERATOR}`
                )->a( n = `items`
                      v = client->_bind( mt_condition_op )
                )->a( n = `width`
                      v = `100%`
                )->tag( n  = `Item`
                        ns = `core`
                    )->a( n = `key`
                          v = `{KEY}`
                    )->a( n = `text`
                          v = `{TEXT}`
            )->end(
            )->tag( `Input`
                )->a( n = `value`
                      v = `{LOW}`
                )->a( n = `visible`
                      v = `{= ${OPERATOR} !== 'EMPTY' }`
            )->tag( `Input`
                )->a( n = `value`
                      v = `{HIGH}`
                )->a( n = `visible`
                      v = `{= ${OPERATOR} === 'BT' }`
            )->tag( `Button`
                )->a( n = `icon`
                      v = `sap-icon://decline`
                )->a( n = `type`
                      v = `Transparent`
                )->a( n = `tooltip`
                      t = get_text( cs_text-remove )
                )->a( n = `press`
                      v = client->_event( val = cs_event-condition_delete
                                          arg = `${ID}` ) ).

    lo_dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-ok )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `press`
                  v = client->_event( cs_event-conditions_ok ) ).
    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-popup_cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD render_adapt_popup.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`
                  t = get_text( cs_text-adapt_filters )
            )->a( n = `contentWidth`
                  v = `25rem` ).

    lo_dialog->ele( `content`
        )->ele( `List`
            )->a( n = `mode`
                  v = `MultiSelect`
            )->a( n = `items`
                  v = client->_bind( mt_adapt )
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
                  v = client->_event( cs_event-adapt_filters_ok ) ).
    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-popup_cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD get_adaptable_fields.

    "every field that can be filtered: visible, a column, no file
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_hidden = abap_false AND is_virtual = abap_false AND is_large_object = abap_false.
      IF ls_field-type_kind = `RAW` OR ls_field-is_consumption_hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND ls_field TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD clear_rows.

    mr_data = create_entity_table( entity_name    = mv_cds_view
                                   with_selection = has_selection( ) ).
    CLEAR mv_count.
    mv_more = abap_false.
    mv_loaded = abap_false.
    mv_no_data = get_text( cs_text-press_go ).

  ENDMETHOD.


  METHOD is_initial_load.

    "a worklist has no Go - it is always read
    IF mv_floorplan = cs_floorplan-worklist.
      result = abap_true.
      RETURN.
    ENDIF.
    result = SWITCH #( mv_initial_load
      WHEN cs_initial_load-disabled THEN abap_false
      WHEN cs_initial_load-enabled  THEN abap_true
      ELSE mv_start_auto ).

  ENDMETHOD.


  METHOD get_text_column.

    IF is_col-text_association IS INITIAL OR is_col-text_element IS NOT INITIAL.
      RETURN.
    ENDIF.
    READ TABLE ms_entity-fields TRANSPORTING NO FIELDS WITH KEY name = is_col-name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_column) = |{ cs_row_column-text_prefix }{ sy-tabix }|.
    IF has_row_column( lv_column ) = abap_true.
      result = lv_column.
    ENDIF.

  ENDMETHOD.


  METHOD apply_text_columns.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lr_extended TYPE REF TO data.
    DATA lt_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    DATA lt_columns TYPE string_table.
    FIELD-SYMBOLS <lt_old> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_new> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_text> TYPE any.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    "the fields of the table with a text association and no text element
    DATA(lt_visible) = get_visible_columns( ).
    LOOP AT ms_entity-fields INTO DATA(ls_field).
      DATA(lv_position) = sy-tabix.
      IF ls_field-text_association IS INITIAL OR ls_field-text_element IS NOT INITIAL
        OR NOT line_exists( lt_visible[ name = ls_field-name ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_field TO lt_fields.
      APPEND |{ cs_row_column-text_prefix }{ lv_position }| TO lt_columns.
    ENDLOOP.
    IF lt_fields IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( mr_data ) ).
        DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
        lt_comp = lo_line->get_components( ).
        DATA(lo_string) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_name( `STRING` ) ).
        LOOP AT lt_columns INTO DATA(lv_column).
          IF NOT line_exists( lt_comp[ name = lv_column ] ).
            APPEND VALUE #( name = lv_column type = lo_string ) TO lt_comp.
          ENDIF.
        ENDLOOP.
        IF lines( lt_comp ) > lines( lo_line->get_components( ) ).
          DATA(lo_new_table) = cl_abap_tabledescr=>create( cl_abap_structdescr=>create( lt_comp ) ).
          CREATE DATA lr_extended TYPE HANDLE lo_new_table.
          ASSIGN mr_data->* TO <lt_old>.
          ASSIGN lr_extended->* TO <lt_new>.
          MOVE-CORRESPONDING <lt_old> TO <lt_new>.
          mr_data = lr_extended.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    ASSIGN mr_data->* TO <lt_new>.
    LOOP AT lt_fields INTO ls_field.
      lv_column = lt_columns[ sy-tabix ].
      DATA(lt_texts) = read_association_texts( is_entity = ms_entity
                                               is_field  = ls_field
                                               data      = mr_data ).
      LOOP AT <lt_new> ASSIGNING FIELD-SYMBOL(<ls_row>).
        UNASSIGN <lv_text>.
        ASSIGN COMPONENT lv_column OF STRUCTURE <ls_row> TO <lv_text>.
        IF <lv_text> IS NOT ASSIGNED.
          CONTINUE.
        ENDIF.
        READ TABLE lt_texts INTO DATA(ls_text)
          WITH KEY name = get_association_text_key( is_entity = ms_entity
                                                    is_field  = ls_field
                                                    row       = <ls_row> ).
        <lv_text> = COND string( WHEN sy-subrc = 0 THEN ls_text-value ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD has_selection.

    result = xsdbool( get_line_item_actions( abap_false ) IS NOT INITIAL ).
    IF result = abap_true.
      RETURN.
    ENDIF.
    LOOP AT get_line_item_intents( ) INTO DATA(ls_intent) WHERE sem_object_bindings IS NOT INITIAL.
      result = abap_true.
      RETURN.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_condition_operators.

    result = VALUE #(
      ( key = z2ui5_cl_rap_util=>cs_condition_op-eq          text = get_text( cs_text-op_eq ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-ne          text = get_text( cs_text-op_ne ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-bt          text = get_text( cs_text-op_bt ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-gt          text = get_text( cs_text-op_gt ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-ge          text = get_text( cs_text-op_ge ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-lt          text = get_text( cs_text-op_lt ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-le          text = get_text( cs_text-op_le ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-contains    text = get_text( cs_text-op_contains ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-starts_with text = get_text( cs_text-op_starts ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-ends_with   text = get_text( cs_text-op_ends ) )
      ( key = z2ui5_cl_rap_util=>cs_condition_op-empty       text = get_text( cs_text-op_empty ) ) ).

  ENDMETHOD.


  METHOD get_ordered_columns.

    DATA(lt_all) = get_line_item_fields( ).
    LOOP AT mt_column_order INTO DATA(lv_name).
      READ TABLE lt_all INTO DATA(ls_column) WITH KEY name = lv_name.
      IF sy-subrc = 0.
        APPEND ls_column TO result.
      ENDIF.
    ENDLOOP.
    "a column the order does not name - a new one - behind
    LOOP AT lt_all INTO ls_column.
      IF NOT line_exists( result[ name = ls_column-name ] ).
        APPEND ls_column TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_variant_key.

    result = COND #( WHEN is_variant-owner IS INITIAL THEN is_variant-name
                     ELSE |{ is_variant-owner }~{ is_variant-name }| ).

  ENDMETHOD.

ENDCLASS.
