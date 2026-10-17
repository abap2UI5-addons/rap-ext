" The order of the tree's rows, its columns and what expand and collapse
" change - on metadata and rows set by hand, no row read (npm run unit
" and a system alike). Added 2026-10, third round.
CLASS ltcl_tree DEFINITION DEFERRED.
CLASS z2ui5_cl_rap_tree DEFINITION LOCAL FRIENDS ltcl_tree.

CLASS ltcl_tree DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_node,
        node   TYPE string,
        parent TYPE string,
        name   TYPE string,
      END OF ty_s_node.

    DATA mo_cut TYPE REF TO z2ui5_cl_rap_tree.
    DATA mt_rows TYPE STANDARD TABLE OF ty_s_node WITH EMPTY KEY.

    METHODS setup.
    METHODS column_values
      IMPORTING
        column        TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS order_by_siblings  FOR TESTING RAISING cx_static_check.
    METHODS rows_in_tree_order FOR TESTING RAISING cx_static_check.
    METHODS expand_and_collapse FOR TESTING RAISING cx_static_check.
    METHODS delete_mode        FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_tree IMPLEMENTATION.

  METHOD setup.

    mo_cut = NEW #( cds_view_name = `Z_NODE`
                    delete_mode   = `move_up` ).
    mo_cut->ms_entity = VALUE #(
      name   = `Z_NODE`
      keys   = VALUE #( ( `NODE` ) )
      fields = VALUE #( ( name = `NODE`   label = `Node`   type_kind = `CHAR` line_item_pos = 10 is_key = abap_true )
                        ( name = `PARENT` label = `Parent` type_kind = `CHAR` line_item_pos = 20 )
                        ( name = `NAME`   label = `Name`   type_kind = `CHAR` line_item_pos = 30 ) ) ).
    mo_cut->mt_sort_field = VALUE #( ( name = `NODE` ) ( name = `NAME` ) ).
    mo_cut->ms_hierarchy = VALUE #( node_field   = `NODE`
                                    parent_field = `PARENT`
                                    order_by     = VALUE #( ( field = `NAME` ) )
                                    delete_mode  = `MOVE_UP` ).
    mo_cut->mv_hierarchy_read = abap_true.
    mt_rows = VALUE #( ( node = `2` parent = `1` name = `b` )
                       ( node = `1`              name = `a` )
                       ( node = `3` parent = `1` name = `c` )
                       ( node = `4` parent = `2` name = `d` ) ).
    mo_cut->mr_data = REF #( mt_rows ).

  ENDMETHOD.


  METHOD column_values.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_value> TYPE any.
    ASSIGN mo_cut->mr_data->* TO <lt_rows>.
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT column OF STRUCTURE <ls_row> TO <lv_value>.
      APPEND |{ <lv_value> }| TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD order_by_siblings.
    "the order of the siblings first, then the keys of the list report
    cl_abap_unit_assert=>assert_equals( exp = `NAME, NODE`
                                        act = mo_cut->get_order_by( ) ).
  ENDMETHOD.


  METHOD rows_in_tree_order.

    mo_cut->build_tree_rows( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `1` ) ( `2` ) ( `4` ) ( `3` ) )
                                        act = column_values( `NODE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `1` ) ( `2` ) ( `4` ) ( `3` ) )
                                        act = column_values( mo_cut->cs_tree_column-key ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `0rem` ) ( `1.5rem` ) ( `3rem` ) ( `1.5rem` ) )
                                        act = column_values( mo_cut->cs_tree_column-indent ) ).
    "the roots are expanded at the start (expand_levels 1), node 2 is not
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `X` ) ( `X` ) ( `` ) ( `X` ) )
                                        act = column_values( mo_cut->cs_row_column-row_visible ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `X` ) ( `X` ) ( `` ) ( `` ) )
                                        act = column_values( mo_cut->cs_tree_column-children ) ).

  ENDMETHOD.


  METHOD expand_and_collapse.

    mo_cut->build_tree_rows( ).
    APPEND `2` TO mo_cut->mt_expanded.
    mo_cut->refresh_tree_state( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `X` ) ( `X` ) ( `X` ) ( `X` ) )
                                        act = column_values( mo_cut->cs_row_column-row_visible ) ).
    "collapsing the root hides every descendant
    CLEAR mo_cut->mt_expanded.
    mo_cut->refresh_tree_state( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `X` ) ( `` ) ( `` ) ( `` ) )
                                        act = column_values( mo_cut->cs_row_column-row_visible ) ).

  ENDMETHOD.


  METHOD delete_mode.
    cl_abap_unit_assert=>assert_equals( exp = `MOVE_UP` act = mo_cut->get_delete_mode( `1` ) ).
    mo_cut->ms_hierarchy-delete_mode = `ANYTHING`.
    cl_abap_unit_assert=>assert_equals( exp = `SUBTREE` act = mo_cut->get_delete_mode( `1` ) ).
  ENDMETHOD.

ENDCLASS.
