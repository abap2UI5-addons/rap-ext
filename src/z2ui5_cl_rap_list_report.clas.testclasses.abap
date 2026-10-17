" The steps of the list report that decide what is read and shown - order,
" filters, mandatory filters, views, columns, actions - on metadata set by
" hand. No row is read: these run transpiled in CI (npm run unit) as well
" as in a system.
CLASS ltcl_list_report DEFINITION DEFERRED.
CLASS z2ui5_cl_rap_list_report DEFINITION LOCAL FRIENDS ltcl_list_report.

CLASS ltcl_list_report DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO z2ui5_cl_rap_list_report.

    METHODS setup.

    METHODS order_by_sort_then_keys    FOR TESTING RAISING cx_static_check.
    METHODS order_by_only_offered      FOR TESTING RAISING cx_static_check.
    METHODS where_filters_and_search   FOR TESTING RAISING cx_static_check.
    METHODS mandatory_filters          FOR TESTING RAISING cx_static_check.
    METHODS variant_round_trip         FOR TESTING RAISING cx_static_check.
    METHODS variant_keeps_known_fields FOR TESTING RAISING cx_static_check.
    METHODS hidden_columns             FOR TESTING RAISING cx_static_check.
    METHODS actions_and_intents        FOR TESTING RAISING cx_static_check.
    METHODS virtual_no_filter          FOR TESTING RAISING cx_static_check.
    METHODS actions_by_permissions     FOR TESTING RAISING cx_static_check.
    METHODS inbound_filter_presets     FOR TESTING RAISING cx_static_check.
    METHODS filter_controls            FOR TESTING RAISING cx_static_check.
    METHODS filter_tokens              FOR TESTING RAISING cx_static_check.
    METHODS variant_layout_round_trip  FOR TESTING RAISING cx_static_check.
    METHODS variant_filter_fields      FOR TESTING RAISING cx_static_check.
    METHODS column_order               FOR TESTING RAISING cx_static_check.
    METHODS order_by_group_first       FOR TESTING RAISING cx_static_check.
    METHODS presentation_variants      FOR TESTING RAISING cx_static_check.
    METHODS initial_load               FOR TESTING RAISING cx_static_check.
    METHODS selection_for_intents      FOR TESTING RAISING cx_static_check.
    METHODS adaptable_fields           FOR TESTING RAISING cx_static_check.
    METHODS variant_keys               FOR TESTING RAISING cx_static_check.
    METHODS analytics_group_rows       FOR TESTING RAISING cx_static_check.
    METHODS table_type_and_columns     FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_list_report IMPLEMENTATION.

  METHOD setup.

    mo_cut = NEW #( cds_view_name = `Z_TRAVEL` ).
    mo_cut->ms_entity = VALUE #(
      name   = `Z_TRAVEL`
      keys   = VALUE #( ( `TRAVELID` ) )
      fields = VALUE #( ( name = `TRAVELID` label = `Travel`  type_kind = `CHAR` line_item_pos = 10 is_key = abap_true )
                        ( name = `STATUS`   label = `Status`  type_kind = `CHAR` line_item_pos = 20
                          is_selection_field = abap_true filter_mandatory = abap_true )
                        ( name = `AGENCY`   label = `Agency`  type_kind = `CHAR` line_item_pos = 30
                          is_selection_field = abap_true )
                        ( name = `NOTES`    label = `Notes`   type_kind = `STRING` line_item_pos = 40 ) )
      actions = VALUE #( ( name = `ACCEPT` label = `Accept` source = `LINEITEM` )
                         ( name = `INTENT~TRAVEL~DISPLAY` label = `Open` source = `LINEITEM`
                           semantic_object = `Travel` semantic_action = `display` ) ) ).
    mo_cut->mt_sort_field = VALUE #( ( name = `TRAVELID` label = `Travel` )
                                     ( name = `STATUS`   label = `Status` )
                                     ( name = `AGENCY`   label = `Agency` ) ).
    mo_cut->mt_filter = VALUE #( ( name = `STATUS` label = `Status *` mandatory = abap_true )
                                 ( name = `AGENCY` label = `Agency` ) ).
    "a business object - its actions are offered
    mo_cut->ms_caps-is_rap_bo = abap_true.

  ENDMETHOD.


  METHOD order_by_sort_then_keys.

    mo_cut->mv_sort_field = `STATUS`.
    mo_cut->mv_sort_desc = abap_true.
    "the keys come last, so a page of rows is the same page every time
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_order_by( )
                                        exp = `STATUS DESCENDING, TRAVELID` ).

  ENDMETHOD.


  METHOD order_by_only_offered.

    "a STRING column in an ORDER BY is invalid SQL - only an offered field
    mo_cut->mv_sort_field = `NOTES`.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_order_by( )
                                        exp = `TRAVELID` ).

  ENDMETHOD.


  METHOD where_filters_and_search.

    mo_cut->mt_filter[ name = `STATUS` ]-value = `=O`.
    mo_cut->mt_filter[ name = `AGENCY` ]-value = `70*`.
    DATA(lv_where) = mo_cut->get_where_clause( ).

    cl_abap_unit_assert=>assert_equals( act = lv_where
                                        exp = |STATUS = 'O' AND AGENCY LIKE '70%' ESCAPE '#'| ).

  ENDMETHOD.


  METHOD mandatory_filters.

    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_missing_filters( )
                                        exp = VALUE string_table( ( `Status` ) ) ).
    mo_cut->mt_filter[ name = `STATUS` ]-value = `O`.
    cl_abap_unit_assert=>assert_initial( mo_cut->get_missing_filters( ) ).

  ENDMETHOD.


  METHOD variant_round_trip.

    mo_cut->mt_filter[ name = `AGENCY` ]-value = `=70001`.
    mo_cut->mv_search = `Rome`.
    mo_cut->mv_sort_field = `AGENCY`.
    mo_cut->mv_sort_desc = abap_true.
    mo_cut->mt_hidden_column = VALUE #( ( `NOTES` ) ).
    DATA(ls_saved) = mo_cut->capture_variant( ).

    "everything back to the start, then the view again
    CLEAR: mo_cut->mt_filter[ name = `AGENCY` ]-value, mo_cut->mv_search, mo_cut->mv_sort_field,
           mo_cut->mv_sort_desc, mo_cut->mt_hidden_column.
    mo_cut->apply_variant( ls_saved ).

    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_filter[ name = `AGENCY` ]-value
                                        exp = `=70001` ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_search
                                        exp = `Rome` ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_sort_field
                                        exp = `AGENCY` ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_sort_desc ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_hidden_column
                                        exp = VALUE string_table( ( `NOTES` ) ) ).

  ENDMETHOD.


  METHOD variant_keeps_known_fields.

    "a view saved before the entity changed: an unknown filter is left out,
    "a sort field the list no longer offers is not taken over
    mo_cut->mv_sort_field = `TRAVELID`.
    mo_cut->apply_variant( VALUE #( filters    = VALUE #( ( name = `GONE` value = `x` ) )
                                    sort_field = `GONE` ) ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( mo_cut->mt_filter[ name = `GONE` ] ) ) ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_filter[ name = `AGENCY` ]-value ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_sort_field
                                        exp = `TRAVELID` ).

  ENDMETHOD.


  METHOD hidden_columns.

    mo_cut->mt_hidden_column = VALUE #( ( `NOTES` ) ( `AGENCY` ) ).
    DATA(lt_columns) = mo_cut->get_visible_columns( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_columns )
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_columns[ 2 ]-name
                                        exp = `STATUS` ).

    "never no column at all
    mo_cut->mt_hidden_column = VALUE #( ( `TRAVELID` ) ( `STATUS` ) ( `AGENCY` ) ( `NOTES` ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_visible_columns( ) )
                                        exp = 4 ).

  ENDMETHOD.


  METHOD actions_and_intents.

    "a navigation is no action - it neither selects rows nor runs in RAP
    DATA(lt_actions) = mo_cut->get_line_item_actions( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_actions )
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_actions[ 1 ]-name
                                        exp = `ACCEPT` ).
    DATA(lt_intents) = mo_cut->get_line_item_intents( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_intents )
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_intents[ 1 ]-semantic_object
                                        exp = `Travel` ).

  ENDMETHOD.


  METHOD virtual_no_filter.

    "a virtual element has no column - it is no filter field, even with
    "@UI.selectionField
    APPEND VALUE #( name = `DAYSTOGO` label = `Days` type_kind = `INT` is_selection_field = abap_true
                    is_virtual = abap_true virtual_calc_class = `ZCL_DAYS` ) TO mo_cut->ms_entity-fields.
    DATA(lt_selection) = mo_cut->get_selection_fields( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_selection )
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_selection[ name = `DAYSTOGO` ] ) ) ).

  ENDMETHOD.


  METHOD actions_by_permissions.

    "GET PERMISSIONS not asked: the toolbar action is enabled
    mo_cut->update_action_state( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_rap_list_report=>ty_t_name_value( ( name = `ACCEPT` value = `true` ) )
                                        act = mo_cut->get_action_enabled( ) ).

    "its global feature control disables it
    mo_cut->ms_perm = VALUE #( answered = abap_true
                               global   = VALUE #( actions = VALUE #( ( name = `ACCEPT` enabled = abap_false ) ) ) ).
    mo_cut->update_action_state( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_rap_list_report=>ty_t_name_value( ( name = `ACCEPT` value = `false` ) )
                                        act = mo_cut->get_action_enabled( ) ).

  ENDMETHOD.


  METHOD inbound_filter_presets.

    "a parameter of a filter field sets its value exactly, one of another
    "field adds its filter, an unknown one is ignored
    mo_cut->set_filter_presets( VALUE #( ( name = `status`  value = `O` )
                                         ( name = `TravelId` value = `42` )
                                         ( name = `Unknown`  value = `x` ) ) ).
    mo_cut->apply_filter_presets( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_filter[ name = `STATUS` ]-value
                                        exp = `=O` ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_filter[ name = `TRAVELID` ]-value
                                        exp = `=42` ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_filter[ name = `TRAVELID` ]-label
                                        exp = `Travel` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->mt_filter )
                                        exp = 3 ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_filter_preset ).

  ENDMETHOD.


  METHOD filter_controls.

    "a boolean is a list of Yes, No and every row, a date a range, a field
    "with a value help a MultiInput
    DATA(ls_bool) = mo_cut->create_filter( VALUE #( name = `ACTIVE` label = `Active` type_kind = `CHAR`
                                                    is_boolean = abap_true ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_filter_control-list
                                        act = ls_bool-control ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_bool-entries ) ).
    cl_abap_unit_assert=>assert_equals( exp = `=X`
                                        act = ls_bool-entries[ 2 ]-key ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-date_range
      act = mo_cut->create_filter( VALUE #( name = `BEGINDATE` type_kind = `DATS` ) )-control ).
    DATA(ls_multi) = mo_cut->create_filter( VALUE #( name             = `COUNTRY`
                                                     label            = `Country`
                                                     type_kind        = `CHAR`
                                                     filter_mandatory = abap_true
                                                     value_help       = VALUE #( entity_name = `I_COUNTRY` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_filter_control-multi
                                        act = ls_multi-control ).
    cl_abap_unit_assert=>assert_true( ls_multi-show_vh ).
    cl_abap_unit_assert=>assert_equals( exp = `Country *`
                                        act = ls_multi-label ).

  ENDMETHOD.


  METHOD filter_tokens.

    APPEND VALUE #( name = `COUNTRY` control = z2ui5_cl_rap_util=>cs_filter_control-multi
                    value = `=DE;!=US` input = `F*` ) TO mo_cut->mt_filter.
    "what is typed becomes a part of the value, every part a token - an
    "exact value without its =
    mo_cut->take_filter_inputs( ).
    DATA(ls_filter) = mo_cut->mt_filter[ name = `COUNTRY` ].
    cl_abap_unit_assert=>assert_equals( exp = `=DE;!=US;F*`
                                        act = ls_filter-value ).
    cl_abap_unit_assert=>assert_initial( ls_filter-input ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_list_report=>ty_t_filter_entry( ( key = `COUNTRY~1` text = `DE` )
                                                               ( key = `COUNTRY~2` text = `!=US` )
                                                               ( key = `COUNTRY~3` text = `F*` ) )
      act = ls_filter-tokens ).

  ENDMETHOD.


  METHOD variant_layout_round_trip.

    "the columns' order and widths and the group field travel with a view
    mo_cut->mt_column_order = VALUE #( ( `STATUS` ) ( `TRAVELID` ) ).
    mo_cut->mt_column_width = VALUE #( ( name = `STATUS` value = `8rem` ) ).
    mo_cut->mv_group_field = `AGENCY`.
    DATA(ls_saved) = mo_cut->capture_variant( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `STATUS` ) ( `AGENCY` ) )
                                        act = ls_saved-filter_fields ).
    CLEAR: mo_cut->mt_column_order, mo_cut->mt_column_width, mo_cut->mv_group_field.
    mo_cut->apply_variant( ls_saved ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `STATUS` ) ( `TRAVELID` ) )
                                        act = mo_cut->mt_column_order ).
    cl_abap_unit_assert=>assert_equals( exp = `8rem`
                                        act = mo_cut->mt_column_width[ 1 ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCY`
                                        act = mo_cut->mv_group_field ).

  ENDMETHOD.


  METHOD variant_filter_fields.

    "a view's filter bar: a field added by adapt filters comes back, one it
    "does not name goes - a mandatory filter always stays
    mo_cut->apply_variant( VALUE #( filter_fields = VALUE #( ( `TRAVELID` ) )
                                    filters       = VALUE #( ( name = `TRAVELID` value = `=42` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( mo_cut->mt_filter ) ).
    cl_abap_unit_assert=>assert_equals( exp = `=42`
                                        act = mo_cut->mt_filter[ name = `TRAVELID` ]-value ).
    cl_abap_unit_assert=>assert_true( mo_cut->mt_filter[ name = `TRAVELID` ]-is_added ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mo_cut->mt_filter[ name = `STATUS` ] ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( mo_cut->mt_filter[ name = `AGENCY` ] ) ) ).

  ENDMETHOD.


  METHOD column_order.

    "the user's order first, a column it does not name behind
    mo_cut->mt_column_order = VALUE #( ( `NOTES` ) ( `STATUS` ) ).
    DATA(lt_columns) = mo_cut->get_visible_columns( ).
    cl_abap_unit_assert=>assert_equals( exp = `NOTES`    act = lt_columns[ 1 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`   act = lt_columns[ 2 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID` act = lt_columns[ 3 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = 4          act = lines( lt_columns ) ).

  ENDMETHOD.


  METHOD order_by_group_first.

    "the rows of a group follow each other
    mo_cut->mv_group_field = `AGENCY`.
    mo_cut->mv_sort_field = `STATUS`.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_order_by( )
                                        exp = `AGENCY, STATUS, TRAVELID` ).

  ENDMETHOD.


  METHOD presentation_variants.

    "the selection presentation variant names the presentation variant
    "(sort, group, its line item) and the selection variant (filter values,
    "the rest as WHERE)
    mo_cut->ms_entity-fields[ name = `STATUS` ]-line_items = VALUE #( ( qualifier = `Short` position = 1 ) ).
    mo_cut->ms_entity-presentation_variants = VALUE #(
      ( qualifier               = `ByAgency`
        sort_order              = VALUE #( ( field = `STATUS` descending = abap_true ) )
        group_by                = VALUE #( ( `AGENCY` ) )
        visualization_type      = `LINEITEM`
        visualization_qualifier = `Short` ) ).
    mo_cut->ms_entity-selection_variants = VALUE #(
      ( qualifier = `Open` filter = `Status EQ O`
        select_options = VALUE #( ( name = `TRAVELID` value = `1..9` ) ) ) ).
    mo_cut->ms_entity-sel_pres_variants = VALUE #( ( qualifier              = `Default`
                                                     presentation_qualifier = `ByAgency`
                                                     selection_qualifier    = `Open` ) ).
    mo_cut->apply_presentation_variants( ).

    cl_abap_unit_assert=>assert_equals( exp = `Short`  act = mo_cut->mv_line_item_qualifier ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS` act = mo_cut->ms_entity-sort_order[ 1 ]-field ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCY` act = mo_cut->ms_entity-group_by[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = `=O`     act = mo_cut->mt_filter[ name = `STATUS` ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `1..9`   act = mo_cut->mt_filter[ name = `TRAVELID` ]-value ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_variant_where ).
    "the columns are the qualified line item's
    DATA(lt_columns) = mo_cut->get_line_item_fields( ).
    cl_abap_unit_assert=>assert_equals( exp = 1        act = lines( lt_columns ) ).

  ENDMETHOD.


  METHOD initial_load.

    cl_abap_unit_assert=>assert_true( mo_cut->is_initial_load( ) ).
    "the default view does not apply automatically
    mo_cut->mv_start_auto = abap_false.
    cl_abap_unit_assert=>assert_false( mo_cut->is_initial_load( ) ).
    mo_cut->mv_initial_load = z2ui5_cl_rap_list_report=>cs_initial_load-enabled.
    cl_abap_unit_assert=>assert_true( mo_cut->is_initial_load( ) ).
    mo_cut->mv_initial_load = z2ui5_cl_rap_list_report=>cs_initial_load-disabled.
    mo_cut->mv_start_auto = abap_true.
    cl_abap_unit_assert=>assert_false( mo_cut->is_initial_load( ) ).
    "the constructor takes it
    DATA(lo_disabled) = NEW z2ui5_cl_rap_list_report( cds_view_name = `Z_TRAVEL`
                                                      initial_load  = `disabled` ).
    cl_abap_unit_assert=>assert_false( lo_disabled->is_initial_load( ) ).

  ENDMETHOD.


  METHOD selection_for_intents.

    "no RAP: no actions - an intent navigation with semanticObjectBinding
    "still selects rows
    mo_cut->ms_caps-is_rap_bo = abap_false.
    cl_abap_unit_assert=>assert_false( mo_cut->has_selection( ) ).
    mo_cut->ms_entity-actions[ name = `INTENT~TRAVEL~DISPLAY` ]-sem_object_bindings =
      VALUE #( ( local_element = `TRAVELID` element = `Travel` ) ).
    cl_abap_unit_assert=>assert_true( mo_cut->has_selection( ) ).

  ENDMETHOD.


  METHOD adaptable_fields.

    "no file, no virtual element, nothing @Consumption.hidden
    APPEND VALUE #( name = `FILE` type_kind = `RAW` is_large_object = abap_true ) TO mo_cut->ms_entity-fields.
    APPEND VALUE #( name = `SECRET` type_kind = `CHAR` is_hidden = abap_true is_consumption_hidden = abap_true )
      TO mo_cut->ms_entity-fields.
    DATA(lt_fields) = mo_cut->get_adaptable_fields( ).
    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_fields ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_fields[ name = `FILE` ] ) ) ).

  ENDMETHOD.


  METHOD variant_keys.

    cl_abap_unit_assert=>assert_equals( exp = `Mine`
                                        act = mo_cut->get_variant_key( VALUE #( name = `Mine` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = `OTHER~Theirs`
                                        act = mo_cut->get_variant_key( VALUE #( name = `Theirs` owner = `OTHER` ) ) ).

  ENDMETHOD.

  METHOD analytics_group_rows.

    TYPES:
      BEGIN OF ty_s_row,
        travelid TYPE string,
        status   TYPE string,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_kind> TYPE any.
    FIELD-SYMBOLS <lv_label> TYPE any.
    DATA lt_labels TYPE string_table.
    DATA lt_kinds TYPE string_table.

    "the rows come ordered by the group field (get_order_by)
    lt_rows = VALUE #( ( travelid = `1` status = `A` )
                       ( travelid = `2` status = `A` )
                       ( travelid = `3` status = `B` ) ).
    mo_cut->mr_data = REF #( lt_rows ).
    mo_cut->mv_group_field = `STATUS`.

    "not analytical: the rows stay as they are
    mo_cut->apply_analytics( `` ).
    cl_abap_unit_assert=>assert_false( mo_cut->has_row_column( mo_cut->cs_row_column-row_kind ) ).

    mo_cut->mv_analytical = abap_true.
    mo_cut->apply_analytics( `` ).
    ASSIGN mo_cut->mr_data->* TO <lt_rows>.
    cl_abap_unit_assert=>assert_equals( exp = 5 act = lines( <lt_rows> ) ).
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT mo_cut->cs_row_column-row_kind OF STRUCTURE <ls_row> TO <lv_kind>.
      ASSIGN COMPONENT mo_cut->cs_row_column-row_label OF STRUCTURE <ls_row> TO <lv_label>.
      APPEND <lv_kind> TO lt_kinds.
      APPEND <lv_label> TO lt_labels.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `GROUP` ) ( `` ) ( `` ) ( `GROUP` ) ( `` ) )
                                        act = lt_kinds ).
    cl_abap_unit_assert=>assert_equals( exp = `Status: A` act = lt_labels[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = `Status: B` act = lt_labels[ 4 ] ).

  ENDMETHOD.


  METHOD table_type_and_columns.

    DATA(lo_grid) = NEW z2ui5_cl_rap_list_report( cds_view_name = `Z_TRAVEL`
                                                  table_type    = `grid`
                                                  analytical    = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = `GRID` act = lo_grid->mv_table_type ).
    cl_abap_unit_assert=>assert_true( lo_grid->mv_analytical ).
    cl_abap_unit_assert=>assert_equals( exp = `RESPONSIVE` act = mo_cut->mv_table_type ).

  ENDMETHOD.

ENDCLASS.
