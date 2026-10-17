" The routing of the flexible column layout - which column an event
" reaches, what opens and closes a column, the view of the columns - with
" floorplans that display fixed views and a client that records them
" (npm run unit and a system alike). Added 2026-10, third round.
CLASS ltcl_fcl DEFINITION DEFERRED.
CLASS z2ui5_cl_rap_fcl DEFINITION LOCAL FRIENDS ltcl_fcl.

CLASS ltd_client DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_client.
    DATA mv_event TYPE string.
    DATA mv_init TYPE abap_bool.
    DATA mv_navigated TYPE abap_bool.
    DATA mv_view TYPE string.
    DATA mv_called TYPE abap_bool.

ENDCLASS.


CLASS ltd_client IMPLEMENTATION.

  METHOD z2ui5_if_client~view_destroy.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.

  METHOD z2ui5_if_client~view_model_update.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~set_session_stateful.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~app_state_set_active.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~app_state_get_href.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~hash_set.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~hash_replace.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest_view_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest_view_destroy.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest_view_model_update.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest2_view_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest2_view_destroy.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nest2_view_model_update.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popup_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popup_model_update.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popup_destroy.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popover_model_update.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popover_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~popover_destroy.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~get.
    result-event = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event_arg.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_app.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~_event_nav_app_leave.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_call.
    mv_called = abap_true.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_toast_display.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~_event.
    result = |EV:{ val }|.
  ENDMETHOD.

  METHOD z2ui5_if_client~_event_client.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~_bind.
    result = `{/BOUND}`.
  ENDMETHOD.

  METHOD z2ui5_if_client~_bind_edit.
    result = `{/BOUND}`.
  ENDMETHOD.

  METHOD z2ui5_if_client~_bind_path.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~follow_up_action.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_event.
    result = xsdbool( mv_event = val ).
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_app_prev_stack.
    RETURN.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_navigated.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_app_prev.
    RETURN.
  ENDMETHOD.

ENDCLASS.


" an object page that shows a fixed page and leaves on BACK
CLASS ltd_page DEFINITION FINAL FOR TESTING
  INHERITING FROM z2ui5_cl_rap_object_page.

  PUBLIC SECTION.
    METHODS z2ui5_if_app~main REDEFINITION.

ENDCLASS.


CLASS ltd_page IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    IF client->check_on_init( ).
      client->view_display( `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc" xmlns:uxap="sap.uxap">`
                         && `<Shell><Page title="Page"/></Shell></mvc:View>` ).
    ELSEIF client->check_on_event( `BACK` ).
      client->nav_app_leave( ).
    ELSEIF client->check_on_event( `CHILD` ).
      client->nav_app_call( NEW ltd_page( ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


" a list report that opens the page on OPEN and notes what came back
CLASS ltd_list DEFINITION FINAL FOR TESTING
  INHERITING FROM z2ui5_cl_rap_list_report.

  PUBLIC SECTION.
    METHODS z2ui5_if_app~main REDEFINITION.
    DATA mv_events TYPE string_table.
    DATA mv_returned TYPE abap_bool.

ENDCLASS.


CLASS ltd_list IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    IF client->check_on_init( ).
      client->view_display( `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc">`
                         && `<Shell><Page title="List"/></Shell></mvc:View>` ).
      RETURN.
    ENDIF.
    IF client->check_on_navigated( ).
      mv_returned = xsdbool( client->get_app_prev( ) IS INSTANCE OF ltd_page ).
      RETURN.
    ENDIF.
    APPEND client->get( )-event TO mv_events.
    IF client->check_on_event( `OPEN` ).
      client->nav_app_call( NEW ltd_page( ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


" the host with the skeleton as the builder writes it - the transpiled
" run has no builder runtime (its escaping needs the core's context class)
CLASS ltd_fcl DEFINITION FINAL FOR TESTING
  INHERITING FROM z2ui5_cl_rap_fcl.

  PROTECTED SECTION.
    METHODS render_skeleton REDEFINITION.

ENDCLASS.


CLASS ltd_fcl IMPLEMENTATION.

  METHOD render_skeleton.
    result = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc" xmlns:f="sap.f" displayBlock="true" height="100%">`
          && `<f:FlexibleColumnLayout layout="{= ${/MV_LAYOUT} || 'OneColumn' }">`
          && `<f:beginColumnPages>` && cs_placeholder-begin && `</f:beginColumnPages>`
          && `<f:midColumnPages>` && cs_placeholder-mid && `</f:midColumnPages>`
          && `<f:endColumnPages>` && cs_placeholder-end && `</f:endColumnPages>`
          && `</f:FlexibleColumnLayout></mvc:View>`.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_fcl DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_list TYPE REF TO ltd_list.
    DATA mo_cut TYPE REF TO ltd_fcl.

    METHODS setup.
    METHODS roundtrip
      IMPORTING
        event TYPE string.

    METHODS start_shows_the_list FOR TESTING RAISING cx_static_check.
    METHODS row_opens_mid_column FOR TESTING RAISING cx_static_check.
    METHODS back_closes_column   FOR TESTING RAISING cx_static_check.
    METHODS child_in_end_column  FOR TESTING RAISING cx_static_check.
    METHODS events_and_proxy     FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_fcl IMPLEMENTATION.

  METHOD setup.
    mo_client = NEW #( ).
    mo_list = NEW #( cds_view_name = `Z_LIST` ).
    mo_cut = NEW #( list = mo_list ).
    mo_client->mv_init = abap_true.
    mo_cut->z2ui5_if_app~main( mo_client ).
    mo_client->mv_init = abap_false.
  ENDMETHOD.


  METHOD roundtrip.
    CLEAR mo_client->mv_view.
    mo_client->mv_event = event.
    mo_cut->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.


  METHOD start_shows_the_list.
    cl_abap_unit_assert=>assert_equals( exp = `OneColumn` act = mo_cut->mv_layout ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view
                                         exp = `*<f:FlexibleColumnLayout*<f:beginColumnPages><Page title="List"/></f:beginColumnPages>*` ).
    "the Shell of the floorplan's view is gone
    cl_abap_unit_assert=>assert_false( xsdbool( mo_client->mv_view CS `<Shell>` ) ).
  ENDMETHOD.


  METHOD row_opens_mid_column.
    roundtrip( `BEGIN~OPEN` ).
    cl_abap_unit_assert=>assert_bound( mo_cut->mo_mid ).
    cl_abap_unit_assert=>assert_equals( exp = `TwoColumnsMidExpanded` act = mo_cut->mv_layout ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view
                                         exp = `*<f:midColumnPages><Page title="Page"/></f:midColumnPages>*` ).
    "the namespaces of the page's view are declared on the root
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view
                                         exp = `<mvc:View * xmlns:uxap="sap.uxap"*` ).
    "the list is not a nav_app_call away
    cl_abap_unit_assert=>assert_false( mo_client->mv_called ).
  ENDMETHOD.


  METHOD back_closes_column.
    roundtrip( `BEGIN~OPEN` ).
    roundtrip( `MID~BACK` ).
    cl_abap_unit_assert=>assert_not_bound( mo_cut->mo_mid ).
    cl_abap_unit_assert=>assert_equals( exp = `OneColumn` act = mo_cut->mv_layout ).
    "the list is told the page returned
    cl_abap_unit_assert=>assert_true( mo_list->mv_returned ).
    cl_abap_unit_assert=>assert_false( xsdbool( mo_client->mv_view CS `title="Page"` ) ).
  ENDMETHOD.


  METHOD child_in_end_column.
    roundtrip( `BEGIN~OPEN` ).
    roundtrip( `MID~CHILD` ).
    cl_abap_unit_assert=>assert_bound( mo_cut->mo_end ).
    cl_abap_unit_assert=>assert_equals( exp = `ThreeColumnsMidExpanded` act = mo_cut->mv_layout ).
    "a new row of the list closes both
    roundtrip( `BEGIN~OPEN` ).
    cl_abap_unit_assert=>assert_not_bound( mo_cut->mo_end ).
    cl_abap_unit_assert=>assert_bound( mo_cut->mo_mid ).
  ENDMETHOD.


  METHOD events_and_proxy.

    "an event without a column is the first column's
    roundtrip( `GO` ).
    roundtrip( `BEGIN~SEARCH` ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `GO` ) ( `SEARCH` ) )
                                        act = mo_list->mv_events ).

    "the column's client names the column in the events it builds
    DATA(li_proxy) = CAST z2ui5_if_client( NEW z2ui5_cl_rap_fcl_client( client = mo_client
                                                                        column = `MID`
                                                                        event  = `SAVE`
                                                                        first  = abap_false ) ).
    cl_abap_unit_assert=>assert_equals( exp = `EV:MID~SAVE` act = li_proxy->_event( `SAVE` ) ).
    cl_abap_unit_assert=>assert_true( li_proxy->check_on_event( `SAVE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `SAVE` act = li_proxy->get( )-event ).
    cl_abap_unit_assert=>assert_true( li_proxy->check_app_prev_stack( ) ).

  ENDMETHOD.

ENDCLASS.
