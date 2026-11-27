"! Flexible column layout: the list report and the object page side by
"! side (sap.f.FlexibleColumnLayout) - added 2026-10, third round.
"!
"! The floorplans stay apps of their own and are not changed: this host
"! holds them as public attributes (the core resolves their bindings
"! through them, MO_BEGIN->MR_DATA) and calls their main( ) with a client
"! of its own (z2ui5_cl_rap_fcl_client). The view each of them displays
"! becomes the content of a column of one view: the list report (or any
"! list report subclass, the worklist, the tree) in the first, the object
"! page a row opens in the second, the object page of a child in the
"! third. An event names its column, so it reaches the floorplan it came
"! from. The back button of the second and third column closes it, and
"! the floorplan to its left is told as if the page had returned
"! (check_on_navigated, get_app_prev) - the list report reads its rows
"! again after a save. A value help or an action dialog is called as
"! before; it returns to the column that called it.
"!
"! A page replaced by another (a row pressed while the object page of
"! another row is open) is treated the same way since 2026-11: with
"! unsaved changes the user is asked first (cv_event_discard), and after
"! a save the column to its left reads again.
"!
"! Without this class nothing changes: a row press still calls the object
"! page with nav_app_call. The host is opt-in - start it instead of the
"! list report:
"!   client->nav_app_call( NEW z2ui5_cl_rap_fcl( `/DMO/C_TRAVEL_M` ) ).
CLASS z2ui5_cl_rap_fcl DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_column,
        begin TYPE string VALUE `BEGIN`,
        mid   TYPE string VALUE `MID`,
        end   TYPE string VALUE `END`,
      END OF cs_column.

    "! the event a column's back button sends when the floorplan leaves
    "! through _event_nav_app_leave
    CONSTANTS cv_event_leave TYPE string VALUE `FCL_LEAVE`.
    "! the answer to "discard your changes?" - asked before a page with
    "! unsaved changes is replaced in its column (added 2026-11)
    CONSTANTS cv_event_discard TYPE string VALUE `FCL_DISCARD`.

    " the placeholders of render_skeleton, as the builder writes them
    CONSTANTS:
      BEGIN OF cs_placeholder,
        begin TYPE string VALUE `<Text text="Z2UI5_RAP_FCL_BEGIN"/>`,
        mid   TYPE string VALUE `<Text text="Z2UI5_RAP_FCL_MID"/>`,
        end   TYPE string VALUE `<Text text="Z2UI5_RAP_FCL_END"/>`,
      END OF cs_placeholder.

    "! cds_view_name: the list report of the first column; list: a list
    "! report (a worklist, a tree, a subclass) to use instead
    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike OPTIONAL
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500
        list          TYPE REF TO z2ui5_cl_rap_list_report OPTIONAL.

    "! the floorplans of the columns - public, the core resolves their
    "! bindings through them
    DATA mo_begin TYPE REF TO z2ui5_if_app.
    DATA mo_mid TYPE REF TO z2ui5_if_app.
    DATA mo_end TYPE REF TO z2ui5_if_app.
    "! the layout of the columns (sap.f.LayoutType)
    DATA mv_layout TYPE string.

  PROTECTED SECTION.

    "! the views the floorplans displayed last, one per column
    DATA mv_view_begin TYPE string.
    DATA mv_view_mid TYPE string.
    DATA mv_view_end TYPE string.
    "! the column whose called app (a value help, a dialog) is open
    DATA mv_wait_column TYPE string.
    "! a column changed its view in this roundtrip
    DATA mv_render TYPE abap_bool.
    "! the page waiting to be opened, and its column, while the user
    "! decides whether the changes of the page it replaces are discarded
    "! (added 2026-11)
    DATA mo_pending TYPE REF TO z2ui5_if_app.
    DATA mv_pending_column TYPE string.

    "! call the floorplan of column with the client of the column - and
    "! do what it asked for: keep its view, open an object page in the
    "! next column, close its column
    METHODS dispatch
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        column    TYPE string
        event     TYPE string OPTIONAL
        init      TYPE abap_bool DEFAULT abap_false
        navigated TYPE abap_bool DEFAULT abap_false
        app_prev  TYPE REF TO z2ui5_if_app OPTIONAL.

    "! open app in column - every column right of it closes. A page there
    "! with unsaved changes is replaced only once the user agreed
    "! (confirmed; cv_event_discard), and the column left of a page that
    "! saved is told, as if the page had returned (since 2026-11)
    METHODS open_column
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        column    TYPE string
        app       TYPE REF TO z2ui5_if_app
        confirmed TYPE abap_bool DEFAULT abap_false.

    "! an object page in column or right of it has changes it would lose
    "! (z2ui5_cl_rap_object_page->is_dirty) - added 2026-11
    METHODS is_column_dirty
      IMPORTING
        column        TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! close column and every column right of it - the floorplan to its
    "! left is told the page returned
    METHODS close_column
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        column TYPE string.

    "! the views of the columns as one view: the flexible column layout
    "! with each column's page
    METHODS render
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the view around the columns - the flexible column layout with a
    "! placeholder per column (cs_placeholder)
    METHODS render_skeleton
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE string.

    "! the layout for the open columns (z2ui5_cl_rap_util=>get_fcl_layout)
    METHODS update_layout.

    "! the floorplan of a column
    METHODS get_column_app
      IMPORTING
        column        TYPE string
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_if_app.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_fcl IMPLEMENTATION.

  METHOD constructor.
    IF list IS BOUND.
      mo_begin = list.
    ELSEIF cds_view_name IS NOT INITIAL.
      mo_begin = NEW z2ui5_cl_rap_list_report( cds_view_name = cds_view_name
                                               title         = title
                                               max_rows      = max_rows ).
    ENDIF.
    update_layout( ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    DATA lv_column TYPE string.
    DATA lv_event TYPE string.

    CLEAR mv_render.

    IF client->check_on_init( ).
      dispatch( client = client
                column = cs_column-begin
                init   = abap_true ).
      mv_render = abap_true.

    ELSEIF client->check_on_navigated( ).
      "back from what a column called: a value help, a dialog
      lv_column = mv_wait_column.
      CLEAR mv_wait_column.
      IF get_column_app( lv_column ) IS NOT BOUND.
        lv_column = cs_column-begin.
      ENDIF.
      dispatch( client    = client
                column    = lv_column
                navigated = abap_true ).
      "the called app showed its own view or popup - this one again
      render( client ).
      RETURN.

    ELSE.
      z2ui5_cl_rap_util=>split_column_event( EXPORTING val    = client->get( )-event
                                             IMPORTING column = lv_column
                                                       event  = lv_event ).
      "the host's own question: replace the page with unsaved changes?
      IF lv_column IS INITIAL AND lv_event = cv_event_discard.
        DATA(li_pending) = mo_pending.
        DATA(lv_pending_column) = mv_pending_column.
        CLEAR: mo_pending, mv_pending_column.
        IF li_pending IS BOUND AND client->get_event_arg( )
          = z2ui5_cl_rap_floorplan=>get_default_text( z2ui5_cl_rap_floorplan=>cs_text-discard_changes ).
          open_column( client    = client
                       column    = lv_pending_column
                       app       = li_pending
                       confirmed = abap_true ).
        ENDIF.
        IF mv_render = abap_true.
          render( client ).
        ENDIF.
        RETURN.
      ENDIF.
      IF get_column_app( lv_column ) IS NOT BOUND.
        lv_column = cs_column-begin.
      ENDIF.
      IF lv_event = cv_event_leave AND lv_column <> cs_column-begin.
        close_column( client = client
                      column = lv_column ).
      ELSE.
        dispatch( client = client
                  column = lv_column
                  event  = lv_event ).
      ENDIF.
    ENDIF.

    "a column without a new view only changed its data - the core sends
    "the model by itself
    IF mv_render = abap_true.
      render( client ).
    ENDIF.

  ENDMETHOD.


  METHOD get_column_app.
    CASE column.
      WHEN cs_column-begin.
        result = mo_begin.
      WHEN cs_column-mid.
        result = mo_mid.
      WHEN cs_column-end.
        result = mo_end.
    ENDCASE.
  ENDMETHOD.


  METHOD dispatch.

    DATA(li_app) = get_column_app( column ).
    IF li_app IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lo_client) = NEW z2ui5_cl_rap_fcl_client( client    = client
                                                   column    = column
                                                   event     = event
                                                   init      = init
                                                   navigated = navigated
                                                   app_prev  = app_prev
                                                   first     = xsdbool( column = cs_column-begin ) ).
    li_app->main( lo_client ).

    IF lo_client->mv_view_set = abap_true.
      CASE column.
        WHEN cs_column-begin.
          mv_view_begin = lo_client->mv_view.
        WHEN cs_column-mid.
          mv_view_mid = lo_client->mv_view.
        WHEN cs_column-end.
          mv_view_end = lo_client->mv_view.
      ENDCASE.
      mv_render = abap_true.
    ENDIF.
    IF lo_client->mv_called = abap_true.
      mv_wait_column = column.
    ENDIF.
    IF lo_client->mo_call IS BOUND.
      open_column( client = client
                   column = COND #( WHEN column = cs_column-begin THEN cs_column-mid ELSE cs_column-end )
                   app    = lo_client->mo_call ).
    ELSEIF lo_client->mv_leave = abap_true.
      close_column( client = client
                    column = column ).
    ENDIF.

  ENDMETHOD.


  METHOD open_column.

    "the page there (or right of it) holds changes it would lose - the
    "user decides first
    IF confirmed = abap_false AND is_column_dirty( column ) = abap_true.
      mo_pending = app.
      mv_pending_column = column.
      client->message_box_display(
        text    = z2ui5_cl_rap_floorplan=>get_default_text( z2ui5_cl_rap_floorplan=>cs_text-leave_changes )
        type    = `confirm`
        actions = VALUE #( ( z2ui5_cl_rap_floorplan=>get_default_text( z2ui5_cl_rap_floorplan=>cs_text-discard_changes ) )
                           ( z2ui5_cl_rap_floorplan=>get_default_text( z2ui5_cl_rap_floorplan=>cs_text-cancel ) ) )
        onclose = cv_event_discard ).
      RETURN.
    ENDIF.

    "the page replaced saved: the column to its left reads again, as when
    "a page returns (the list shows the saved values at once)
    DATA(li_old) = get_column_app( column ).
    "(an initial reference is no instance - the CAST is not reached)
    IF li_old IS INSTANCE OF z2ui5_cl_rap_object_page
      AND CAST z2ui5_cl_rap_object_page( li_old )->was_saved( ) = abap_true.
      dispatch( client    = client
                column    = COND #( WHEN column = cs_column-mid THEN cs_column-begin ELSE cs_column-mid )
                navigated = abap_true
                app_prev  = li_old ).
    ENDIF.

    IF column = cs_column-mid.
      mo_mid = app.
      CLEAR: mo_end, mv_view_mid, mv_view_end.
    ELSE.
      mo_end = app.
      CLEAR mv_view_end.
    ENDIF.
    update_layout( ).
    mv_render = abap_true.
    dispatch( client = client
              column = column
              init   = abap_true ).

  ENDMETHOD.


  METHOD is_column_dirty.

    DATA lt_apps TYPE STANDARD TABLE OF REF TO z2ui5_if_app WITH EMPTY KEY.

    "a page in the middle column goes with the one right of it
    APPEND get_column_app( column ) TO lt_apps.
    IF column = cs_column-mid.
      APPEND mo_end TO lt_apps.
    ENDIF.
    LOOP AT lt_apps INTO DATA(li_app) WHERE table_line IS BOUND.
      IF li_app IS INSTANCE OF z2ui5_cl_rap_object_page
        AND CAST z2ui5_cl_rap_object_page( li_app )->is_dirty( ) = abap_true.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD close_column.

    DATA lv_left TYPE string.

    DATA(li_closed) = get_column_app( column ).
    CASE column.
      WHEN cs_column-mid.
        CLEAR: mo_mid, mo_end, mv_view_mid, mv_view_end.
        lv_left = cs_column-begin.
      WHEN cs_column-end.
        CLEAR: mo_end, mv_view_end.
        lv_left = cs_column-mid.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    update_layout( ).
    mv_render = abap_true.
    dispatch( client    = client
              column    = lv_left
              navigated = abap_true
              app_prev  = li_closed ).

  ENDMETHOD.


  METHOD update_layout.
    DATA(lv_columns) = 1.
    IF mo_mid IS BOUND.
      lv_columns = 2.
    ENDIF.
    IF mo_end IS BOUND.
      lv_columns = 3.
    ENDIF.
    mv_layout = z2ui5_cl_rap_util=>get_fcl_layout( lv_columns ).
  ENDMETHOD.


  METHOD render_skeleton.

    "sap.f under a prefix of its own - a column's view may declare f for
    "another library (xmlns:f="sap.ui.layout.form"), and the composed
    "view keeps the first declaration of a prefix (since 2026-11)
    DATA(lo_fcl_view) = z2ui5_cl_ui5_view_builder=>factory( ).
    lo_fcl_view->ele( n  = `View`
                      ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `xmlns:zfcl`
              v = `sap.f`
        )->a( n = `displayBlock`
              v = `true`
        )->a( n = `height`
              v = `100%`
        )->ele( n  = `FlexibleColumnLayout`
                ns = `zfcl`
            )->a( n = `layout`
                  v = `{= $` && client->_bind( mv_layout ) && ` || 'OneColumn' }`
            )->ele( n  = `beginColumnPages`
                    ns = `zfcl`
                )->tag( `Text`
                    )->a( n = `text`
                          v = `Z2UI5_RAP_FCL_BEGIN`
            )->end(
            )->ele( n  = `midColumnPages`
                    ns = `zfcl`
                )->tag( `Text`
                    )->a( n = `text`
                          v = `Z2UI5_RAP_FCL_MID`
            )->end(
            )->ele( n  = `endColumnPages`
                    ns = `zfcl`
                )->tag( `Text`
                    )->a( n = `text`
                          v = `Z2UI5_RAP_FCL_END` ).
    result = lo_fcl_view->stringify( ).

  ENDMETHOD.


  METHOD render.

    DATA lt_namespaces TYPE z2ui5_cl_rap_util=>ty_t_name_value.

    "the namespaces the columns' views declare
    LOOP AT VALUE string_table( ( mv_view_begin ) ( mv_view_mid ) ( mv_view_end ) ) INTO DATA(lv_view).
      APPEND LINES OF z2ui5_cl_rap_util=>get_view_namespaces( lv_view ) TO lt_namespaces.
    ENDLOOP.

    DATA(lv_composed) = z2ui5_cl_rap_util=>compose_view(
      skeleton      = render_skeleton( client )
      it_parts      = VALUE #( ( name  = cs_placeholder-begin
                                 value = z2ui5_cl_rap_util=>get_view_body( mv_view_begin ) )
                               ( name  = cs_placeholder-mid
                                 value = z2ui5_cl_rap_util=>get_view_body( mv_view_mid ) )
                               ( name  = cs_placeholder-end
                                 value = z2ui5_cl_rap_util=>get_view_body( mv_view_end ) ) )
      it_namespaces = lt_namespaces ).
    client->view_display( lv_composed ).

  ENDMETHOD.

ENDCLASS.
