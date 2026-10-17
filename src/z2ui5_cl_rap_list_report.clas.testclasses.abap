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

ENDCLASS.
