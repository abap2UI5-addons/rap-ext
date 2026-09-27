" The page under test with only the data access replaced: load_all_cards
" reads a CDS view and the DDIC annotation API, neither of which a unit test
" can rely on. This one produces the same shape from fixed rows - an
" anonymous table of an RTTI-created table type behind data_ref, appended to
" mt_card_data - so everything after the load is the production code:
" display( ), collect_card_rows( ), render_page( ) and the card hooks.
CLASS ltd_page DEFINITION FINAL
  INHERITING FROM z2ui5_cl_rap_overview_page.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE i,
        name TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

  PROTECTED SECTION.
    METHODS load_all_cards REDEFINITION.

ENDCLASS.


CLASS ltd_page IMPLEMENTATION.

  METHOD load_all_cards.

    DATA ls_row TYPE ty_s_row.
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.

    LOOP AT mt_cards INTO DATA(ls_card).
      DATA(ls_cd) = VALUE ty_s_card_data( title = ls_card-title
                                          count = 2 ).
      ls_cd-entity-fields = VALUE #( ( name = `ID`   label = `Id`   line_item_pos = 1 )
                                     ( name = `NAME` label = `Name` line_item_pos = 2 ) ).

      DATA(lo_row) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( ls_row ) ).
      DATA(lo_table) = cl_abap_tabledescr=>create( lo_row ).
      CREATE DATA ls_cd-data_ref TYPE HANDLE lo_table.
      ASSIGN ls_cd-data_ref->* TO <lt_data>.
      <lt_data> = VALUE ty_t_row( ( id = 1 name = |{ ls_card-title } 1| )
                                  ( id = 2 name = |{ ls_card-title } 2| ) ).

      APPEND ls_cd TO mt_card_data.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


" A table card - the default card type - binds its rows. Every card used to
" bind the table behind mt_card_data[ n ]-data_ref, and the abap2UI5 model
" never looks into the rows of a table: the first render of any page with a
" table card ended with BINDING_ERROR. The roundtrips are driven the way the
" core's own tests drive an app - an action, a client on it, main( ) - and
" the second request goes through the core's handler, draft and all.
CLASS ltcl_table_card DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_page   TYPE REF TO ltd_page.
    DATA mo_action TYPE REF TO z2ui5_cl_ui5_action.

    METHODS setup.

    METHODS roundtrip.

    METHODS first_render_binds_rows    FOR TESTING RAISING cx_static_check.
    METHODS draft_roundtrip_keeps_rows FOR TESTING RAISING cx_static_check.
    METHODS redisplay_keeps_one_set    FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_table_card IMPLEMENTATION.

  METHOD setup.

    mo_page = NEW #( title = `Overview`
                     cards = VALUE #( ( cds_view_name = `Z_ORDERS`
                                        title         = `Orders`
                                        card_type     = `TABLE` )
                                      ( cds_view_name = `Z_OPEN`
                                        title         = `Open`
                                        card_type     = `KPI` ) ) ).

    DATA(lo_handler) = NEW z2ui5_cl_ui5_handler( `` ).
    mo_action = lo_handler->mo_action.
    mo_action->mo_app->mo_app = mo_page.

  ENDMETHOD.


  METHOD roundtrip.

    DATA(li_client) = CAST z2ui5_if_client( NEW z2ui5_cl_ui5_client( mo_action ) ).
    TRY.
        mo_page->z2ui5_if_app~main( li_client ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = lx->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD first_render_binds_rows.

    roundtrip( ).

    " the rows are in the model, under the path the table card binds
    cl_abap_unit_assert=>assert_char_cp(
        act = mo_action->mo_app->model_json_stringify( )
        exp = `*"MR_CARD_ROWS":{"CARD_1":[{"ID":1,"NAME":"Orders 1"},{"ID":2,"NAME":"Orders 2"}]*` ).

    " and no generic reference is left in a row of mt_card_data - the draft
    " cannot serialize one
    cl_abap_unit_assert=>assert_bound( mo_page->mr_card_rows ).
    LOOP AT mo_page->mt_card_data INTO DATA(ls_cd).
      cl_abap_unit_assert=>assert_not_bound( ls_cd-data_ref ).
    ENDLOOP.

  ENDMETHOD.


  METHOD draft_roundtrip_keeps_rows.

    mo_action->mo_app->ms_draft-id = cl_system_uuid=>create_uuid_c32_static( ).
    roundtrip( ).
    mo_action->mo_app->db_save( ).

    " the next request: an event the page does not handle, on that draft
    DATA(lo_next) = NEW z2ui5_cl_ui5_handler(
        |\{"value":\{"S_FRONT":\{"ID":"{ mo_action->mo_app->ms_draft-id }","EVENT":"UNKNOWN",| &&
        |"ORIGIN":"O","PATHNAME":"/","SEARCH":""\}\}\}| ).
    DATA(ls_response) = lo_next->main( ).

    cl_abap_unit_assert=>assert_equals( exp = 200
                                        act = ls_response-status_code ).
    DATA(lo_restored) = CAST ltd_page( lo_next->mo_action->mo_app->mo_app ).
    cl_abap_unit_assert=>assert_bound( lo_restored->mr_card_rows ).
    cl_abap_unit_assert=>assert_char_cp(
        act = lo_next->mo_action->mo_app->model_json_stringify( )
        exp = `*"MR_CARD_ROWS":{"CARD_1":[{"ID":1,"NAME":"Orders 1"},{"ID":2,"NAME":"Orders 2"}]*` ).

  ENDMETHOD.


  METHOD redisplay_keeps_one_set.

    roundtrip( ).

    " back from a called app: not the first render, and the view is built again
    mo_action->mo_app->mv_check_initialized = abap_true.
    mo_action->ms_actual-check_on_navigated = abap_true.
    roundtrip( ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( mo_page->mt_card_data ) ).
    cl_abap_unit_assert=>assert_char_cp(
        act = mo_action->mo_app->model_json_stringify( )
        exp = `*"MR_CARD_ROWS":{"CARD_1":[{"ID":1,"NAME":"Orders 1"},{"ID":2,"NAME":"Orders 2"}]*` ).

  ENDMETHOD.

ENDCLASS.
