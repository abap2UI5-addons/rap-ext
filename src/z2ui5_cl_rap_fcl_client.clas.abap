"! The client a floorplan in a column of the flexible column layout
"! (z2ui5_cl_rap_fcl) is called with - added 2026-10, third round.
"!
"! It hands every call to the real client, except what makes a floorplan
"! an app of its own:
"! - view_display keeps the view (mv_view) - the host puts the views of
"!   its columns into one; view_model_update does nothing, the core
"!   sends a changed model by itself
"! - _event names the column (z2ui5_cl_rap_util=>to_column_event), get,
"!   get_event and check_on_event answer the event without it - so the
"!   host knows which floorplan an event is for, and the floorplan sees
"!   its own events
"! - nav_app_call of an object page is noted (mo_call) - the host opens
"!   it in the next column; any other app (a value help, a dialog) is
"!   called, and the host notes the column it returns to
"! - nav_app_leave in the second or third column is noted (mv_leave) -
"!   the host closes the column; in the first it leaves the host
"! - check_on_init, check_on_navigated and get_app_prev answer what the
"!   host says; check_app_prev_stack is true beyond the first column
"!   (the back button closes the column)
"!
"! It lives for one call of a floorplan's main - it is never kept, so it
"! never travels through the draft.
CLASS z2ui5_cl_rap_fcl_client DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_client.

    "! client: the real one; column: the column of the floorplan
    "! (z2ui5_cl_rap_fcl=>cs_column); event: the event without the
    "! column; init, navigated, app_prev: what check_on_init,
    "! check_on_navigated and get_app_prev answer
    METHODS constructor
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        column    TYPE string
        event     TYPE string OPTIONAL
        init      TYPE abap_bool DEFAULT abap_false
        navigated TYPE abap_bool DEFAULT abap_false
        app_prev  TYPE REF TO z2ui5_if_app OPTIONAL
        first     TYPE abap_bool DEFAULT abap_true.

    "! the view the floorplan displayed, and whether it did
    DATA mv_view TYPE string READ-ONLY.
    DATA mv_view_set TYPE abap_bool READ-ONLY.
    "! the object page the floorplan wants to open
    DATA mo_call TYPE REF TO z2ui5_if_app READ-ONLY.
    "! the floorplan called another app (a value help, a dialog)
    DATA mv_called TYPE abap_bool READ-ONLY.
    "! the floorplan left - its column closes
    DATA mv_leave TYPE abap_bool READ-ONLY.

  PROTECTED SECTION.
    DATA mi_client TYPE REF TO z2ui5_if_client.
    DATA mv_column TYPE string.
    DATA mv_event TYPE string.
    DATA mv_init TYPE abap_bool.
    DATA mv_navigated TYPE abap_bool.
    DATA mi_app_prev TYPE REF TO z2ui5_if_app.
    "! the floorplan is in the first column
    DATA mv_first TYPE abap_bool.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_fcl_client IMPLEMENTATION.

  METHOD constructor.
    mi_client = client.
    mv_column = column.
    mv_event = event.
    mv_init = init.
    mv_navigated = navigated.
    mi_app_prev = app_prev.
    mv_first = first.
  ENDMETHOD.


  METHOD z2ui5_if_client~view_destroy.
    CLEAR: mv_view, mv_view_set.
  ENDMETHOD.


  METHOD z2ui5_if_client~view_display.
    mv_view = val.
    mv_view_set = abap_true.
  ENDMETHOD.


  METHOD z2ui5_if_client~view_model_update.
    RETURN.
  ENDMETHOD.


  METHOD z2ui5_if_client~set_session_stateful.
    mi_client->set_session_stateful( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~app_state_set_active.
    mi_client->app_state_set_active( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~app_state_get_href.
    result = mi_client->app_state_get_href( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~hash_set.
    mi_client->hash_set( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~hash_replace.
    mi_client->hash_replace( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest_view_display.
    mi_client->nest_view_display( val            = val
                                  id             = id
                                  method_insert  = method_insert
                                  method_destroy = method_destroy ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest_view_destroy.
    mi_client->nest_view_destroy( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest_view_model_update.
    mi_client->nest_view_model_update( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest2_view_display.
    mi_client->nest2_view_display( val            = val
                                   id             = id
                                   method_insert  = method_insert
                                   method_destroy = method_destroy ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest2_view_destroy.
    mi_client->nest2_view_destroy( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~nest2_view_model_update.
    mi_client->nest2_view_model_update( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popup_display.
    mi_client->popup_display( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popup_model_update.
    mi_client->popup_model_update( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popup_destroy.
    mi_client->popup_destroy( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popover_model_update.
    mi_client->popover_model_update( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popover_display.
    mi_client->popover_display( xml   = xml
                                by_id = by_id ).
  ENDMETHOD.


  METHOD z2ui5_if_client~popover_destroy.
    mi_client->popover_destroy( ).
  ENDMETHOD.


  METHOD z2ui5_if_client~get.
    result = mi_client->get( ).
    result-event = mv_event.
    result-check_on_navigated = mv_navigated.
  ENDMETHOD.


  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.


  METHOD z2ui5_if_client~get_event_arg.
    result = mi_client->get_event_arg( v ).
  ENDMETHOD.


  METHOD z2ui5_if_client~get_app.
    result = mi_client->get_app( id ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_event_nav_app_leave.
    "leaving is the column's back button, a roundtrip of the column
    IF mv_first = abap_true.
      result = mi_client->_event_nav_app_leave( ).
    ELSE.
      result = mi_client->_event( z2ui5_cl_rap_util=>to_column_event( column = mv_column
                                                                      event  = `FCL_LEAVE` ) ).
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_client~nav_app_leave.
    IF mv_first = abap_false.
      mv_leave = abap_true.
      RETURN.
    ENDIF.
    IF r_data IS SUPPLIED.
      result = mi_client->nav_app_leave( app    = app
                                         event  = event
                                         r_data = r_data ).
    ELSE.
      result = mi_client->nav_app_leave( app   = app
                                         event = event ).
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_client~nav_app_call.
    "an object page opens in the next column
    IF app IS INSTANCE OF z2ui5_cl_rap_object_page.
      mo_call = app.
      RETURN.
    ENDIF.
    mv_called = abap_true.
    result = mi_client->nav_app_call( app ).
  ENDMETHOD.


  METHOD z2ui5_if_client~message_box_display.
    mi_client->message_box_display( text             = text
                                    type             = type
                                    title            = title
                                    styleclass       = styleclass
                                    onclose          = onclose
                                    actions          = actions
                                    emphasizedaction = emphasizedaction
                                    initialfocus     = initialfocus
                                    details          = details ).
  ENDMETHOD.


  METHOD z2ui5_if_client~message_toast_display.
    mi_client->message_toast_display( text     = text
                                      duration = duration
                                      onclose  = onclose ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_event.
    "arg folded into t_arg as the core does it - an empty one on purpose
    "is a filled slot
    DATA(lt_arg) = t_arg.
    IF arg IS SUPPLIED.
      APPEND CONV string( arg ) TO lt_arg.
    ENDIF.
    DATA(lv_event) = CONV string( val ).
    IF lv_event IS NOT INITIAL.
      lv_event = z2ui5_cl_rap_util=>to_column_event( column = mv_column
                                                     event  = lv_event ).
    ENDIF.
    result = mi_client->_event( val    = lv_event
                                t_arg  = lt_arg
                                s_ctrl = s_ctrl ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_event_client.
    result = mi_client->_event_client( val   = val
                                       view  = view
                                       t_arg = t_arg ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_bind.
    result = mi_client->_bind( val                  = val
                               path                 = path
                               custom_mapper        = custom_mapper
                               custom_filter        = custom_filter
                               tab                  = tab
                               tab_index            = tab_index
                               switch_default_model = switch_default_model
                               omit_initial         = omit_initial
                               omit_initial_paths   = omit_initial_paths
                               json                 = json ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_bind_edit.
    result = mi_client->_bind_edit( val                  = val
                                    path                 = path
                                    custom_mapper        = custom_mapper
                                    custom_mapper_back   = custom_mapper_back
                                    custom_filter        = custom_filter
                                    custom_filter_back   = custom_filter_back
                                    tab                  = tab
                                    tab_index            = tab_index
                                    switch_default_model = switch_default_model ).
  ENDMETHOD.


  METHOD z2ui5_if_client~_bind_path.
    result = mi_client->_bind_path( val ).
  ENDMETHOD.


  METHOD z2ui5_if_client~follow_up_action.
    result = mi_client->follow_up_action( val   = val
                                          view  = view
                                          t_arg = t_arg ).
  ENDMETHOD.


  METHOD z2ui5_if_client~check_on_event.
    IF val IS NOT INITIAL.
      result = xsdbool( mv_event = val ).
    ELSE.
      result = xsdbool( mv_event IS NOT INITIAL ).
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.


  METHOD z2ui5_if_client~check_app_prev_stack.
    IF mv_first = abap_true.
      result = mi_client->check_app_prev_stack( ).
    ELSE.
      result = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_navigated.
  ENDMETHOD.


  METHOD z2ui5_if_client~get_app_prev.
    IF mi_app_prev IS BOUND.
      result = mi_app_prev.
    ELSE.
      result = mi_client->get_app_prev( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
