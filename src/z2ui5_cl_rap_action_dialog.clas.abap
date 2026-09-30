"! Popup dialog for an abstract CDS entity, driven by its annotations
"! (labels, tooltips, default values, value helps, multiline texts,
"! hidden fields, mandatory fields).
"!
"! A value help is the addon's z2ui5_cl_rap_value_help, called as an app of
"! its own (render_value_help) and applied on the return
"! (handle_value_help_confirm) - one value help for every floorplan instead
"! of a second copy in here. A small value help (sizeCategory #XS) is a
"! ComboBox whose entries live in mr_value_lists: a table the dialog
"! loaded into a local variable, as it did up to 2026-09, is nothing the
"! abap2UI5 model can bind.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code - e.g.
"! get_control_for_field to swap the control rendered for a single
"! field. Events the floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_action_dialog DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        confirm    TYPE string VALUE `CONFIRM`,
        cancel     TYPE string VALUE `CANCEL`,
        value_help TYPE string VALUE `VALUE_HELP`,
        vh_confirm TYPE string VALUE `VH_CONFIRM`,
        vh_cancel  TYPE string VALUE `VH_CANCEL`,
      END OF cs_event.

    METHODS constructor
      IMPORTING
        val   TYPE data
        title TYPE string OPTIONAL.

    DATA ms_cds TYPE REF TO data.

    "! the rows the last value help returned (a table of its entity)
    DATA mt_vh_data TYPE REF TO data.

    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    METHODS was_confirmed
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.
    DATA mv_title     TYPE string.
    DATA ms_entity    TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mv_vh_field  TYPE string.
    DATA mv_confirmed TYPE abap_bool.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS apply_default_values.

    METHODS render_action_dialog
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! call the value help of field_name
    METHODS render_value_help
      IMPORTING
        client     TYPE REF TO z2ui5_if_client
        field_name TYPE string.

    "! apply what the value help returned, then show the dialog again
    METHODS handle_value_help_confirm
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS get_control_for_field
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_field     TYPE z2ui5_cl_rap_util=>ty_s_field_info
        client       TYPE REF TO z2ui5_if_client.

    METHODS load_dropdown_data
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the label and the control of one field
    METHODS render_dialog_field
      IMPORTING
        io_form  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_field TYPE z2ui5_cl_rap_util=>ty_s_field_info
        client   TYPE REF TO z2ui5_if_client.

    "! the labels of the mandatory fields that are still empty
    METHODS get_missing_fields
      RETURNING
        VALUE(result) TYPE string_table.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_action_dialog IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-action_dialog.
    CREATE DATA ms_cds LIKE val.
    ms_cds->* = val.
    mv_title = title.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_cds->* ).
      DATA(lv_entity_name) = lo_datadescr->get_relative_name( ).
      ms_entity = z2ui5_cl_rap_util=>read_entity( lv_entity_name ).
      adjust_entity( CHANGING cs_entity = ms_entity ).
      IF mv_title IS INITIAL.
        mv_title = COND #( WHEN ms_entity-description IS NOT INITIAL THEN ms_entity-description
                           ELSE ms_entity-name ).
      ENDIF.
      apply_default_values( ).
      prepare_value_lists( ms_entity-fields ).
      render_action_dialog( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-confirm ).
      DATA(lt_missing) = get_missing_fields( ).
      IF lt_missing IS NOT INITIAL.
        "the dialog stays open - a button press does not close it
        client->message_box_display(
          text = |{ get_text( cs_text-required ) }: { concat_lines_of( table = lt_missing sep = `, ` ) }|
          type = `warning` ).
        RETURN.
      ENDIF.
      mv_confirmed = abap_true.
      client->popup_destroy( ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      mv_confirmed = abap_false.
      client->popup_destroy( ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-value_help ).
      render_value_help( client     = client
                         field_name = client->get_event_arg( ) ).
      RETURN.
    ENDIF.

    "kept for subclasses that still render the value help popup of their
    "own with these two events
    IF client->check_on_event( cs_event-vh_confirm ).
      handle_value_help_confirm( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-vh_cancel ).
      client->popup_destroy( ).
      render_action_dialog( client ).
      RETURN.
    ENDIF.

    "returning from the value help, another called app or a restored
    "bookmark: check_on_init( ) is false here and the browser still shows
    "the OTHER app's view, so the view has to be built again
    IF client->check_on_navigated( ).
      handle_value_help_confirm( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD apply_default_values.
    FIELD-SYMBOLS <fld> TYPE any.
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE default_value IS NOT INITIAL.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_cds->* TO <fld>.
      IF sy-subrc = 0 AND <fld> IS INITIAL.
        TRY.
            <fld> = ls_field-default_value.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_dropdown_data.
    result = select_rows( entity_name = to_upper( entity_name ) ).
  ENDMETHOD.


  METHOD get_missing_fields.
    FIELD-SYMBOLS <fld> TYPE any.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_mandatory = abap_true AND is_hidden = abap_false.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_cds->* TO <fld>.
      IF sy-subrc = 0 AND <fld> IS INITIAL.
        APPEND ls_field-label TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD render_action_dialog.

    DATA(lo_popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_dialog) = lo_popup->ele( n  = `FragmentDefinition`
                                      ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->a( n = `xmlns:form`
              v = `sap.ui.layout.form`

        )->ele( `Dialog`
            )->a( n = `title`
                  t = mv_title
            )->a( n = `contentWidth`
                  v = `450px`
            )->a( n = `draggable`
                  v = `true`
            )->a( n = `resizable`
                  v = `true` ).

    DATA(lo_content) = lo_dialog->ele( `content` ).
    DATA(lo_form) = lo_content->ele( n  = `SimpleForm`
                                      ns = `form`
        )->a( n = `editable`
              v = `true`
        )->a( n = `layout`
              v = `ResponsiveGridLayout`
        )->ele( n  = `content`
                 ns = `form` ).

    "@UI.fieldGroup: one titled group per qualifier, in the order the
    "groups first appear; fields without a group come first, untitled
    DATA lt_groups TYPE z2ui5_cl_rap_util=>ty_t_field_group.
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
      LOOP AT ls_field-field_groups INTO DATA(ls_group).
        IF NOT line_exists( lt_groups[ qualifier = ls_group-qualifier ] ).
          APPEND ls_group TO lt_groups.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT ms_entity-fields INTO ls_field
      WHERE is_hidden = abap_false AND field_groups IS INITIAL.
      render_dialog_field( io_form  = lo_form
                           is_field = ls_field
                           client   = client ).
    ENDLOOP.

    LOOP AT lt_groups INTO ls_group.
      lo_form->tag( n  = `Title`
                    ns = `core`
          )->a( n = `text`
                t = COND #( WHEN ls_group-label IS NOT INITIAL THEN ls_group-label ELSE ls_group-qualifier ) ).
      DATA lt_in_group TYPE z2ui5_cl_rap_util=>ty_t_field_info.
      CLEAR lt_in_group.
      LOOP AT ms_entity-fields INTO ls_field WHERE is_hidden = abap_false.
        READ TABLE ls_field-field_groups INTO DATA(ls_membership) WITH KEY qualifier = ls_group-qualifier.
        IF sy-subrc = 0.
          ls_field-field_group_pos = ls_membership-position.
          APPEND ls_field TO lt_in_group.
        ENDIF.
      ENDLOOP.
      SORT lt_in_group BY field_group_pos.
      LOOP AT lt_in_group INTO ls_field.
        render_dialog_field( io_form  = lo_form
                             is_field = ls_field
                             client   = client ).
      ENDLOOP.
    ENDLOOP.

    render_extension( spot         = cs_spot-dialog_content
                      io_container = lo_content
                      client       = client ).

    lo_dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-ok )
            )->a( n = `press`
                  v = client->_event( cs_event-confirm )
            )->a( n = `type`
                  v = `Emphasized` ).

    lo_dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_event-cancel ) ).

    client->popup_display( lo_popup->stringify( ) ).

  ENDMETHOD.


  METHOD render_dialog_field.

    io_form->tag( `Label`
        )->a( n = `text`
              t = is_field-label
        )->a( n = `required`
              b = is_field-is_mandatory ).
    get_control_for_field(
      io_container = io_form
      is_field     = is_field
      client       = client ).

  ENDMETHOD.


  METHOD get_control_for_field.

    FIELD-SYMBOLS <field> TYPE any.
    ASSIGN COMPONENT is_field-name OF STRUCTURE ms_cds->* TO <field>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    render_field_input( io_container = io_container
                        is_field     = is_field
                        client       = client
                        value        = <field>
                        vh_event     = cs_event-value_help ).

  ENDMETHOD.


  METHOD render_value_help.

    READ TABLE ms_entity-fields INTO DATA(ls_field)
      WITH KEY name = to_upper( field_name ).
    IF sy-subrc <> 0 OR ls_field-value_help-entity_name IS INITIAL.
      RETURN.
    ENDIF.

    mv_vh_field = ls_field-name.
    open_value_help( client   = client
                     is_field = ls_field
                     source   = ms_cds->* ).

  ENDMETHOD.


  METHOD handle_value_help_confirm.

    DATA(lo_vh) = get_value_help_result( client ).
    IF lo_vh IS BOUND.
      mt_vh_data = lo_vh->result_table( ).
    ENDIF.

    apply_value_help( EXPORTING client    = client
                                it_fields = ms_entity-fields
                      CHANGING  target    = ms_cds->* ).
    CLEAR mv_vh_field.

    render_action_dialog( client ).

  ENDMETHOD.


  METHOD result.
    result = ms_cds.
  ENDMETHOD.


  METHOD was_confirmed.
    result = mv_confirmed.
  ENDMETHOD.

ENDCLASS.
