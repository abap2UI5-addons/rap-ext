"! Object page for a single record of a CDS entity - header, status
"! attributes, sections and edit/save/delete all come from the
"! annotations (see README).
"!
"! Sections follow @UI.facet: #COLLECTION facets become sections with a
"! subsection per child facet, #FIELDGROUP_REFERENCE and
"! #IDENTIFICATION_REFERENCE become forms, #LINEITEM_REFERENCE becomes a
"! table of the associated entity. The annotations name the association,
"! not its target entity - get_association_target( ) asks the extension
"! (z2ui5_if_rap_ext~resolve_association) first, then the association as
"! the entity's DDL source declares it (since 2026-10), and a facet without
"! a target is left out. The rows of such a table are the ones the
"! association's ON condition selects.
"!
"! A record of a child entity carries its place in the business object
"! (context): it is written through the BDEF of the root, and a table of a
"! composition offers Create - a create by association under this record.
"!
"! A record of a draft-enabled business object is edited in a draft of its
"! own (since 2026-10): Edit creates it (committed), Save writes the changes
"! into it and activates it, Cancel discards it, and leaving the page while
"! editing keeps it with the changes. A draft that exists already is the
"! business object's message - one of the user's own can be discarded.
"!
"! Writing goes through z2ui5_cl_rap_floorplan->write_row( ): RAP (EML) for
"! a business object, ABAP SQL for a table. A CDS view that is neither is
"! read-only, and the page offers no Edit or Delete for it - up to 2026-09
"! it offered both and every save ended in an error.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event, so a subclass adds its
"! own actions the same way any abap2UI5 app handles them.
CLASS z2ui5_cl_rap_object_page DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        back       TYPE string VALUE `BACK`,
        edit       TYPE string VALUE `EDIT`,
        save       TYPE string VALUE `SAVE`,
        cancel     TYPE string VALUE `CANCEL`,
        delete     TYPE string VALUE `DELETE`,
        value_help TYPE string VALUE `VALUE_HELP`,
        action     TYPE string VALUE `ACTION`,
        child_row  TYPE string VALUE `CHILD_ROW`,
        "added 2026-10
        child_create   TYPE string VALUE `CHILD_CREATE`,
        draft_decision TYPE string VALUE `DRAFT_DECISION`,
        intent         TYPE string VALUE `INTENT`,
      END OF cs_event.

    "! val: the record, any structure typed after the CDS entity. Or,
    "! instead of val, cds_view_name and keys: the page reads the record
    "! itself (and can then be opened from a link or a bookmark)
    METHODS constructor
      IMPORTING
        val           TYPE data OPTIONAL
        title         TYPE string OPTIONAL
        editable      TYPE abap_bool DEFAULT abap_false
        is_create     TYPE abap_bool DEFAULT abap_false
        cds_view_name TYPE clike OPTIONAL
        keys          TYPE ty_t_name_value OPTIONAL
        "the record's place in a RAP business object - set by the page of
        "its parent for a child entity (added 2026-10)
        context       TYPE ty_s_rap_context OPTIONAL
          PREFERRED PARAMETER val.

    "! Check if user saved (for caller to detect on return)
    METHODS was_saved
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Get the saved data reference
    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    DATA ms_data TYPE REF TO data.
    DATA mv_editable TYPE abap_bool.

    "! the rows of the #LINEITEM_REFERENCE sections - one component per
    "! section (SECTION_1, ...), each a table of the associated entity
    DATA mr_child_rows TYPE REF TO data.

  PROTECTED SECTION.
    DATA mv_title     TYPE string.
    DATA ms_entity    TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mv_is_create TYPE abap_bool.
    DATA mv_saved     TYPE abap_bool.

    TYPES:
      BEGIN OF ty_s_section,
        title       TYPE string,
        field_group TYPE string,
        "added 2026-09 - appended so the existing layout stays as it was
        "the facet id; parent_id is the #COLLECTION the section belongs to
        id          TYPE string,
        parent_id   TYPE string,
        "FIELDGROUP (also the default), IDENTIFICATION, LINEITEM, COLLECTION
        type        TYPE string,
        association TYPE string,
      END OF ty_s_section.

    TYPES ty_t_section TYPE STANDARD TABLE OF ty_s_section WITH DEFAULT KEY.

    " a #LINEITEM_REFERENCE section with its entity
    TYPES:
      BEGIN OF ty_s_child,
        section_id TYPE string,
        component  TYPE string,
        entity     TYPE z2ui5_cl_rap_util=>ty_s_entity_info,
        "added 2026-10: the association, and whether a row can be created
        "under this record (a create by association)
        association TYPE string,
        can_create  TYPE abap_bool,
      END OF ty_s_child.

    TYPES ty_t_child TYPE STANDARD TABLE OF ty_s_child WITH DEFAULT KEY.

    DATA ms_data_backup TYPE REF TO data.
    DATA mv_entity_name TYPE string.
    DATA ms_caps TYPE ty_s_capabilities.
    DATA mt_child TYPE ty_t_child.
    DATA mt_keys TYPE ty_t_name_value.
    "! an action waiting for its parameter dialog to return
    DATA mv_pending_action TYPE string.
    "! the record's place in a RAP business object (see the constructor)
    DATA ms_context TYPE ty_s_rap_context.
    "! the messages of the last save - their fields are marked in edit mode
    DATA mt_messages TYPE ty_t_message.
    "! the page edits a draft of the business object (committed, kept
    "! between roundtrips)
    DATA mv_draft TYPE abap_bool.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! page skeleton - delegates to render_header_title,
    "! render_header_content and render_sections
    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_header_title
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    "! Edit / Save / Cancel / Delete buttons and the actions
    METHODS render_actions
      IMPORTING
        io_actions TYPE REF TO z2ui5_cl_ui5_view_builder
        client     TYPE REF TO z2ui5_if_client.

    "! key attributes + data points
    METHODS render_header_content
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    METHODS render_sections
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    METHODS get_sections
      RETURNING
        VALUE(result) TYPE ty_t_section.

    "! the form of the fields of one field group
    METHODS render_section_form
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_ui5_view_builder
        iv_group  TYPE string
        client    TYPE REF TO z2ui5_if_client.

    "! the content of one (sub)section, by its type
    METHODS render_section_content
      IMPORTING
        io_parent  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section TYPE ty_s_section
        client     TYPE REF TO z2ui5_if_client.

    "! a form of it_fields - inputs in edit mode, texts otherwise
    METHODS render_section_fields
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_ui5_view_builder
        it_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info
        client    TYPE REF TO z2ui5_if_client.

    "! the table of a #LINEITEM_REFERENCE section
    METHODS render_section_table
      IMPORTING
        io_parent  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section TYPE ty_s_section
        client     TYPE REF TO z2ui5_if_client.

    METHODS get_identification_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    METHODS get_datapoint_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    METHODS get_criticality_state
      IMPORTING
        iv_crit_value TYPE i
      RETURNING
        VALUE(result) TYPE string.

    METHODS get_crit_value
      IMPORTING
        iv_field      TYPE string
      RETURNING
        VALUE(result) TYPE i.

    METHODS get_field_value
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    METHODS format_value
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    METHODS save_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS delete_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! read the record again by its keys - after a save, and when the page
    "! was opened with keys instead of a record
    METHODS reload_data.

    "! the CDS entity an association leads to - the extension answers it;
    "! redefine it to answer it in a subclass
    METHODS get_association_target
      IMPORTING
        association   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! read the rows of every #LINEITEM_REFERENCE section into
    "! mr_child_rows
    METHODS load_child_rows.

    "! a RAP action of @UI.identification on this record
    METHODS on_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS execute_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        param  TYPE REF TO data OPTIONAL.

    "! a row of a #LINEITEM_REFERENCE table was pressed - its object page
    METHODS on_child_row
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the header content from the @UI.facet entries with purpose #HEADER:
    "! a #DATAPOINT_REFERENCE is a status, a #FIELDGROUP_REFERENCE a block of
    "! label/value pairs
    METHODS render_header_facets
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        client       TYPE REF TO z2ui5_if_client.

    "! the value of a field as the page displays it - with its text by
    "! @ObjectModel.text.element and @UI.textArrangement
    METHODS get_display_text
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! the labels of the mandatory fields that are still empty
    METHODS get_missing_fields
      RETURNING
        VALUE(result) TYPE string_table.

    "! a key field of the record is still initial
    METHODS has_initial_key
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the BDEF the record is written through - the root's for a child, the
    "! entity's own for the root of a business object, empty otherwise
    METHODS get_bdef
      RETURNING
        VALUE(result) TYPE string.

    "! the keys of the root instance of the business object
    METHODS get_root_keys
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! Edit of a draft business object: a draft of the root (committed) -
    "! abap_false when the business object refused it, which the user sees
    METHODS start_draft
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Save in draft mode: the changes into the draft, then Activate - when
    "! the activation is refused the draft keeps the changes and the page
    "! stays in edit mode
    METHODS save_draft
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the key fields of the record with their values
    METHODS get_own_keys
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the context of a record of the association - the BDEF and root of
    "! this record, and this record as the parent of a create
    METHODS get_child_context
      IMPORTING
        association   TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_rap_context.

    "! the condition of the child rows of a #LINEITEM_REFERENCE section:
    "! the field pairs of the association's ON condition, else the keys of
    "! this record under the same names - et_values are the values of the
    "! child's fields
    METHODS get_child_filter
      IMPORTING
        is_child  TYPE ty_s_child
      EXPORTING
        et_values TYPE ty_t_name_value.

    "! the Create of a #LINEITEM_REFERENCE table - an object page in create
    "! mode for a new child of this record
    METHODS on_child_create
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a created record whose key the business object assigned only on save
    "! (late numbering): the newest record created by this user since
    "! since_ts / since_utc, found by its @Semantics.user.createdBy and
    "! @Semantics.systemDateTime.createdAt fields - abap_false when the
    "! entity has neither or nothing was found
    METHODS find_created_record
      IMPORTING
        since_ts      TYPE timestampl
        since_utc     TYPE utclong
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_object_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-object_page.
    IF val IS SUPPLIED.
      CREATE DATA ms_data LIKE val.
      ms_data->* = val.
    ELSEIF cds_view_name IS NOT INITIAL.
      mv_entity_name = to_upper( cds_view_name ).
      CREATE DATA ms_data TYPE (mv_entity_name).
    ENDIF.
    IF cds_view_name IS NOT INITIAL.
      mv_entity_name = to_upper( cds_view_name ).
    ENDIF.
    mt_keys = keys.
    ms_context = context.
    mv_title = title.
    mv_editable = editable.
    mv_is_create = is_create.
  ENDMETHOD.


  METHOD was_saved.
    result = mv_saved.
  ENDMETHOD.


  METHOD result.
    result = ms_data.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      IF ms_data IS NOT BOUND.
        client->message_box_display( text = get_text( cs_text-load_error )
                                     type = `error` ).
        client->nav_app_leave( ).
        RETURN.
      ENDIF.
      IF mv_entity_name IS INITIAL.
        DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_data->* ).
        mv_entity_name = lo_datadescr->get_relative_name( ).
      ENDIF.
      ms_entity = z2ui5_cl_rap_util=>read_entity( mv_entity_name ).
      adjust_entity( CHANGING cs_entity = ms_entity ).
      ms_caps = get_entity_capabilities( entity_name = mv_entity_name
                                         context     = ms_context ).

      IF mt_keys IS NOT INITIAL.
        reload_data( ).
      ENDIF.

      "backup original data for cancel
      CREATE DATA ms_data_backup LIKE ms_data->*.
      ms_data_backup->* = ms_data->*.

      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name.
        ELSE.
          mv_title = ms_entity-name.
        ENDIF.
      ENDIF.

      prepare_value_lists( ms_entity-fields ).
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      "leaving a draft keeps it - with what was changed since the last save
      IF mv_draft = abap_true.
        FIELD-SYMBOLS <ls_now> TYPE any.
        FIELD-SYMBOLS <ls_before> TYPE any.
        ASSIGN ms_data->* TO <ls_now>.
        ASSIGN ms_data_backup->* TO <ls_before>.
        IF <ls_now> <> <ls_before>.
          write_draft( entity_name = mv_entity_name
                       row         = <ls_now>
                       original    = <ls_before>
                       context     = ms_context ).
        ENDIF.
        client->message_toast_display( get_text( cs_text-draft_kept ) ).
      ENDIF.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-edit ).
      IF ms_caps-can_update = abap_false.
        client->message_box_display( text = get_text( cs_text-read_only )
                                     type = `error` ).
        RETURN.
      ENDIF.
      "a draft business object is edited in a draft of its own
      IF is_draft_enabled( get_bdef( ) ) = abap_true AND start_draft( client ) = abap_false.
        RETURN.
      ENDIF.
      mv_editable = abap_true.
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-draft_decision ).
      "the user's answer to "a draft exists": discard it and edit anew
      IF client->get_event_arg( ) = get_text( cs_text-discard_draft ).
        DATA(ls_discard) = run_draft_action( bdef      = get_bdef( )
                                             action    = `DISCARD`
                                             root_keys = get_root_keys( )
                                             is_draft  = abap_true ).
        IF ls_discard-success = abap_false.
          show_messages( client   = client
                         messages = ls_discard-messages ).
          RETURN.
        ENDIF.
        IF start_draft( client ) = abap_true.
          mv_editable = abap_true.
          render_page( client ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      IF mv_is_create = abap_true.
        client->nav_app_leave( ).
        RETURN.
      ENDIF.
      IF mv_draft = abap_true.
        DATA(ls_cancel) = run_draft_action( bdef      = get_bdef( )
                                            action    = `DISCARD`
                                            root_keys = get_root_keys( )
                                            is_draft  = abap_true ).
        IF ls_cancel-success = abap_false.
          show_messages( client   = client
                         messages = ls_cancel-messages ).
          RETURN.
        ENDIF.
        mv_draft = abap_false.
        "the active record as it is - the draft had the changes
        reload_data( ).
        ms_data_backup->* = ms_data->*.
      ELSE.
        ms_data->* = ms_data_backup->*.
      ENDIF.
      mv_editable = abap_false.
      CLEAR mt_messages.
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-save ).
      DATA(lt_missing) = get_missing_fields( ).
      IF lt_missing IS NOT INITIAL.
        client->message_box_display(
          text = |{ get_text( cs_text-required ) }: { concat_lines_of( table = lt_missing sep = `, ` ) }|
          type = `warning` ).
        RETURN.
      ENDIF.
      DATA(lv_was_create) = mv_is_create.
      "the time before the save - a record created by late numbering is
      "found again by it
      DATA lv_since_ts TYPE timestampl.
      GET TIME STAMP FIELD lv_since_ts.
      DATA(lv_since_utc) = utclong_current( ).
      DATA(lv_saved) = COND abap_bool( WHEN mv_draft = abap_true THEN save_draft( client )
                                       ELSE save_data( client ) ).
      IF lv_saved = abap_true.
        mv_saved = abap_true.
        mv_editable = abap_false.
        mv_is_create = abap_false.
        CLEAR mt_messages.
        "a created record whose key the business object assigns and did not
        "hand back (late numbering): found by who created it when, else it
        "cannot be read again - the list shows it
        IF lv_was_create = abap_true AND mt_keys IS INITIAL AND has_initial_key( ) = abap_true
          AND find_created_record( since_ts  = lv_since_ts
                                   since_utc = lv_since_utc ) = abap_false.
          client->nav_app_leave( ).
          RETURN.
        ENDIF.
        "what the business object determined on save
        reload_data( ).
        ms_data_backup->* = ms_data->*.
        render_page( client ).
        client->message_toast_display( get_text( cs_text-saved ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-delete ).
      IF delete_data( client ).
        mv_saved = abap_true.
        client->message_toast_display( get_text( cs_text-deleted ) ).
        client->nav_app_leave( ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-value_help ).
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0.
        open_value_help( client   = client
                         is_field = ls_field
                         source   = ms_data->* ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-action ).
      on_action( client ).
      RETURN.
    ENDIF.

    "a #FOR_INTENT_BASED_NAVIGATION of @UI.identification - with the keys
    IF client->check_on_event( cs_event-intent ).
      READ TABLE ms_entity-actions INTO DATA(ls_intent) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0 AND ls_intent-semantic_object IS NOT INITIAL.
        navigate_to_intent( client          = client
                            semantic_object = ls_intent-semantic_object
                            action          = ls_intent-semantic_action
                            params          = get_own_keys( ) ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-child_row ).
      on_child_row( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-child_create ).
      on_child_create( client ).
      RETURN.
    ENDIF.

    "returning from a called app or a restored bookmark: check_on_init( ) is
    "false here and the browser still shows the OTHER app's view, so the view
    "has to be built again - a model push would reach nothing
    IF client->check_on_navigated( ).
      apply_value_help( EXPORTING client    = client
                                  it_fields = ms_entity-fields
                        CHANGING  target    = ms_data->* ).
      "decided by what this page called - check_app_prev_stack( ) only says
      "whether the page has a caller itself
      IF mv_pending_action IS NOT INITIAL.
        TRY.
            DATA(lo_dialog) = CAST z2ui5_cl_rap_action_dialog( client->get_app_prev( ) ).
            IF lo_dialog->was_confirmed( ).
              execute_action( client = client
                              param  = lo_dialog->result( ) ).
            ENDIF.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
        CLEAR mv_pending_action.
      ENDIF.
      "a child record may have changed
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD get_missing_fields.
    FIELD-SYMBOLS <fld> TYPE any.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_mandatory = abap_true AND is_hidden = abap_false.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_data->* TO <fld>.
      IF sy-subrc = 0 AND <fld> IS INITIAL.
        APPEND ls_field-label TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD save_data.

    DATA(ls_result) = write_row( entity_name = mv_entity_name
                                 operation   = COND #( WHEN mv_is_create = abap_true THEN `CREATE` ELSE `UPDATE` )
                                 row         = ms_data->*
                                 original    = ms_data_backup->*
                                 context     = ms_context ).
    result = ls_result-success.
    "the fields the messages are about are marked when the page shows again
    mt_messages = ls_result-details.
    "the keys RAP assigned on create - the record is read again by them
    IF result = abap_true AND ls_result-keys IS NOT INITIAL.
      mt_keys = ls_result-keys.
    ENDIF.
    IF result = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages ).
    ENDIF.

  ENDMETHOD.


  METHOD delete_data.

    DATA(ls_result) = write_row( entity_name = mv_entity_name
                                 operation   = `DELETE`
                                 row         = ms_data->*
                                 context     = ms_context ).
    result = ls_result-success.
    IF result = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages ).
    ENDIF.

  ENDMETHOD.


  METHOD has_initial_key.
    FIELD-SYMBOLS <lv_key> TYPE any.
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
      IF sy-subrc = 0 AND <lv_key> IS INITIAL.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reload_data.

    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lv_key> TYPE any.

    "the keys: those the page was opened with (or RAP assigned), else the
    "record's own - read each time, not kept, so an edited record is not
    "looked up by keys it no longer has
    DATA(lt_keys) = mt_keys.
    IF lt_keys IS INITIAL.
      LOOP AT ms_entity-keys INTO DATA(lv_key).
        ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
        IF sy-subrc = 0.
          APPEND VALUE #( name = lv_key value = |{ <lv_key> }| ) TO lt_keys.
        ENDIF.
      ENDLOOP.
    ENDIF.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    "compared with typed host variables, not literals - a RAW key (a UUID)
    "does not compare with a character literal
    LOOP AT lt_keys INTO DATA(ls_key).
      DATA(lv_name) = to_upper( ls_key-name ).
      IF NOT line_exists( ms_entity-fields[ name = lv_name ] ).
        RETURN.
      ENDIF.
      APPEND lv_name TO lt_names.
    ENDLOOP.

    DATA(lr_rows) = select_rows( entity_name = mv_entity_name
                                 where       = build_key_condition( lt_names )
                                 max_rows    = 1
                                 host        = create_host( entity_name = mv_entity_name
                                                            values      = lt_keys ) ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
    IF sy-subrc = 0.
      MOVE-CORRESPONDING <ls_row> TO ms_data->*.
    ENDIF.

  ENDMETHOD.


  METHOD get_association_target.
    IF mo_ext IS BOUND.
      mo_ext->resolve_association( EXPORTING entity_name = mv_entity_name
                                             association = association
                                   CHANGING  target      = result ).
    ENDIF.
    "the extension decides first, the DDL source otherwise
    IF result IS INITIAL.
      READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = to_upper( association ).
      IF sy-subrc = 0.
        result = ls_assoc-target.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD load_child_rows.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_rows TYPE STANDARD TABLE OF REF TO data WITH DEFAULT KEY.
    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_target> TYPE any.
    FIELD-SYMBOLS <lt_source> TYPE any.

    CLEAR: mr_child_rows, mt_child.
    IF mv_is_create = abap_true.
      RETURN.
    ENDIF.

    LOOP AT get_sections( ) INTO DATA(ls_section) WHERE type = `LINEITEM`.
      DATA(lv_target) = to_upper( get_association_target( ls_section-association ) ).
      IF lv_target IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_child) = VALUE ty_s_child(
        section_id  = ls_section-id
        component   = |SECTION_{ lines( mt_child ) + 1 }|
        association = to_upper( ls_section-association )
        entity      = z2ui5_cl_rap_util=>read_entity( lv_target ) ).
      adjust_entity( CHANGING cs_entity = ls_child-entity ).

      "the child rows of this record - compared with typed host variables
      get_child_filter( EXPORTING is_child  = ls_child
                        IMPORTING et_values = DATA(lt_values) ).
      IF lt_values IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR lt_names.
      LOOP AT lt_values INTO DATA(ls_value).
        APPEND ls_value-name TO lt_names.
      ENDLOOP.

      DATA(lr_rows) = select_rows( entity_name = lv_target
                                   where       = build_key_condition( lt_names )
                                   host        = create_host( entity_name = lv_target
                                                              values      = lt_values ) ).
      IF lr_rows IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ls_child-can_create = get_entity_capabilities(
        entity_name = lv_target
        context     = get_child_context( ls_child-association ) )-can_create.

      APPEND VALUE #( name = ls_child-component
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_rows ) ) ) TO lt_comp.
      APPEND lr_rows TO lt_rows.
      APPEND ls_child TO mt_child.
    ENDLOOP.

    IF lt_comp IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_struct) = cl_abap_structdescr=>create( lt_comp ).
    CREATE DATA mr_child_rows TYPE HANDLE lo_struct.
    ASSIGN mr_child_rows->* TO <ls_all>.
    LOOP AT lt_rows INTO DATA(lr_list).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE <ls_all> TO <lt_target>.
      ASSIGN lr_list->* TO <lt_source>.
      <lt_target> = <lt_source>.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_child_filter.

    FIELD-SYMBOLS <lv_value> TYPE any.
    CLEAR et_values.

    "the association's ON condition, when each of its fields is there
    READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = is_child-association.
    IF sy-subrc = 0 AND ls_assoc-conditions IS NOT INITIAL.
      LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT ls_condition-local OF STRUCTURE ms_data->* TO <lv_value>.
        IF <lv_value> IS NOT ASSIGNED OR NOT line_exists( is_child-entity-fields[ name = ls_condition-target ] ).
          CLEAR et_values.
          EXIT.
        ENDIF.
        APPEND VALUE #( name = ls_condition-target value = |{ <lv_value> }| ) TO et_values.
      ENDLOOP.
      IF et_values IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    "else the keys of this record, which a composition child carries under
    "the same names
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED OR NOT line_exists( is_child-entity-fields[ name = lv_key ] ).
        CLEAR et_values.
        RETURN.
      ENDIF.
      APPEND VALUE #( name = lv_key value = |{ <lv_value> }| ) TO et_values.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_bdef.
    IF ms_context-bdef IS NOT INITIAL.
      result = ms_context-bdef.
    ELSEIF ms_caps-is_rap_bo = abap_true.
      result = mv_entity_name.
    ENDIF.
  ENDMETHOD.


  METHOD get_root_keys.
    result = COND #( WHEN ms_context-bdef IS NOT INITIAL THEN ms_context-root_keys
                     ELSE get_own_keys( ) ).
  ENDMETHOD.


  METHOD start_draft.

    DATA(ls_result) = run_draft_action( bdef      = get_bdef( )
                                        action    = `EDIT`
                                        root_keys = get_root_keys( ) ).
    IF ls_result-success = abap_true.
      mv_draft = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    "a draft exists already - another user's lock, which the business
    "object names, or one of this user's that can be discarded
    client->message_box_display(
      text    = concat_lines_of( table = ls_result-messages sep = cl_abap_char_utilities=>newline )
      type    = `warning`
      actions = VALUE #( ( get_text( cs_text-discard_draft ) ) ( get_text( cs_text-cancel ) ) )
      onclose = cs_event-draft_decision ).

  ENDMETHOD.


  METHOD save_draft.

    DATA(ls_result) = write_draft( entity_name = mv_entity_name
                                   row         = ms_data->*
                                   original    = ms_data_backup->*
                                   context     = ms_context ).
    mt_messages = ls_result-details.
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages ).
      RETURN.
    ENDIF.
    "the draft has the changes now - the next change is compared with it
    ms_data_backup->* = ms_data->*.

    ls_result = run_draft_action( bdef      = get_bdef( )
                                  action    = `ACTIVATE`
                                  root_keys = get_root_keys( )
                                  is_draft  = abap_true ).
    mt_messages = ls_result-details.
    IF ls_result-success = abap_false.
      "the draft keeps the changes, the page stays in edit mode
      show_messages( client   = client
                     messages = ls_result-messages ).
      RETURN.
    ENDIF.

    mv_draft = abap_false.
    IF mo_ext IS BOUND.
      mo_ext->after_save( entity_name = mv_entity_name
                          operation   = `UPDATE`
                          data        = ms_data ).
    ENDIF.
    result = abap_true.

  ENDMETHOD.


  METHOD get_own_keys.

    FIELD-SYMBOLS <lv_key> TYPE any.
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      UNASSIGN <lv_key>.
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
      IF <lv_key> IS ASSIGNED.
        APPEND VALUE #( name = lv_key value = |{ <lv_key> }| ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_child_context.

    "an association that is no composition leads to an entity of its own -
    "written, if at all, as its own business object
    READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = to_upper( association ).
    IF sy-subrc = 0 AND ls_assoc-is_composition = abap_false.
      RETURN.
    ENDIF.

    "a child is written through the BDEF of the root - this record's root
    IF ms_context-bdef IS NOT INITIAL.
      result-bdef = ms_context-bdef.
      result-root_keys = ms_context-root_keys.
    ELSEIF ms_caps-is_rap_bo = abap_true.
      result-bdef = mv_entity_name.
      result-root_keys = get_own_keys( ).
    ELSE.
      RETURN.
    ENDIF.
    result-parent = mv_entity_name.
    result-parent_keys = get_own_keys( ).
    result-association = to_upper( association ).
    "the child's fields that point at this record - the composition fills them
    LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
      APPEND ls_condition-target TO result-parent_fields.
    ENDLOOP.

  ENDMETHOD.


  METHOD on_child_create.

    FIELD-SYMBOLS <ls_row> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR ls_child-can_create = abap_false.
      RETURN.
    ENDIF.

    "the fields that point at this record are filled - shown on the page
    get_child_filter( EXPORTING is_child  = ls_child
                      IMPORTING et_values = DATA(lt_values) ).
    DATA(lr_row) = create_host( entity_name = ls_child-entity-name
                                values      = lt_values ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO <ls_row>.

    DATA(lv_type) = COND string( WHEN ls_child-entity-header_info-type_name IS NOT INITIAL
                                 THEN ls_child-entity-header_info-type_name
                                 ELSE ls_child-entity-name ).
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page(
      val       = <ls_row>
      title     = |{ get_text( cs_text-create_title ) } { lv_type }|
      editable  = abap_true
      is_create = abap_true
      context   = get_child_context( ls_child-association ) ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD find_created_record.

    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <lv_at> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    READ TABLE ms_entity-fields INTO DATA(ls_by) WITH KEY admin_field = `CREATED_BY`.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ms_entity-fields INTO DATA(ls_at) WITH KEY admin_field = `CREATED_AT`.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lr_host) = create_host( entity_name = mv_entity_name
                                 values      = VALUE #( ( name = ls_by-name value = sy-uname ) ) ).
    IF lr_host IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_host->* TO <ls_host>.
    ASSIGN COMPONENT ls_at-name OF STRUCTURE <ls_host> TO <lv_at>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "a little before the save - a time stamp in seconds is rounded
    TRY.
        DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( <lv_at> )->type_kind.
        IF lv_kind = cl_abap_typedescr=>typekind_utclong.
          <lv_at> = utclong_add( val     = since_utc
                                 seconds = -2 ).
        ELSEIF lv_kind = cl_abap_typedescr=>typekind_packed.
          <lv_at> = cl_abap_tstmp=>add( tstmp = since_ts
                                        secs  = -2 ).
        ELSEIF lv_kind = cl_abap_typedescr=>typekind_date.
          <lv_at> = sy-datum.
        ELSE.
          RETURN.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(lr_rows) = select_rows(
      entity_name = mv_entity_name
      where       = |{ ls_by-name } = @{ cv_host }-{ ls_by-name } AND { ls_at-name } >= @{ cv_host }-{ ls_at-name }|
      max_rows    = 1
      order_by    = |{ ls_at-name } DESCENDING|
      host        = lr_host ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    MOVE-CORRESPONDING <ls_row> TO ms_data->*.
    mt_keys = get_own_keys( ).
    result = abap_true.

  ENDMETHOD.


  METHOD on_child_row.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    "arg 1 the section's component, args 2... the keys of the child row
    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lr_row) = find_row_by_event_keys( data       = REF #( <lt_rows> )
                                           key_fields = ls_child-entity-keys
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO FIELD-SYMBOL(<ls_row>).
    DATA(lr_entity_row) = to_entity_row( entity_name = ls_child-entity-name
                                         row         = <ls_row> ).
    ASSIGN lr_entity_row->* TO <ls_row>.
    "the child is changed in the business object of this record - no
    "create by association here
    DATA(ls_context) = get_child_context( ls_child-association ).
    CLEAR: ls_context-association, ls_context-parent_fields.
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( val     = <ls_row>
                                                context = ls_context ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD on_action.

    "only an action of @UI.identification, whatever the event names
    mv_pending_action = client->get_event_arg( ).
    IF NOT line_exists( ms_entity-actions[ name = mv_pending_action source = `IDENTIFICATION` semantic_object = `` ] ).
      CLEAR mv_pending_action.
      RETURN.
    ENDIF.
    DATA(lr_param) = create_action_parameter( entity_name = mv_entity_name
                                              action      = mv_pending_action
                                              context     = ms_context ).
    IF lr_param IS BOUND.
      "the parameter first - the action runs on the return
      ASSIGN lr_param->* TO FIELD-SYMBOL(<ls_param>).
      READ TABLE ms_entity-actions INTO DATA(ls_action) WITH KEY name = mv_pending_action.
      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog( val   = <ls_param>
                                                        title = ls_action-label ).
      lo_dialog->set_extension( mo_ext ).
      client->nav_app_call( lo_dialog ).
      RETURN.
    ENDIF.

    execute_action( client ).
    CLEAR mv_pending_action.
    render_page( client ).

  ENDMETHOD.


  METHOD execute_action.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    DATA(lr_rows) = create_entity_table( mv_entity_name ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
    MOVE-CORRESPONDING ms_data->* TO <ls_row>.

    DATA(ls_result) = run_action( entity_name = mv_entity_name
                                  action      = mv_pending_action
                                  rows        = lr_rows
                                  param       = param
                                  context     = ms_context ).
    IF ls_result-success = abap_true.
      mv_saved = abap_true.
      reload_data( ).
      ms_data_backup->* = ms_data->*.
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


  METHOD get_sections.

    "facet-driven - the header facets are the header's business
    DATA lt_facets TYPE z2ui5_cl_rap_util=>ty_t_facet.
    LOOP AT ms_entity-facets INTO DATA(ls_facet) WHERE purpose NS `HEADER`.
      APPEND ls_facet TO lt_facets.
    ENDLOOP.
    SORT lt_facets BY position.

    LOOP AT lt_facets INTO ls_facet.
      DATA(ls_section) = VALUE ty_s_section(
        id          = ls_facet-id
        title       = ls_facet-label
        field_group = ls_facet-target_qualifier
        association = ls_facet-target_element ).
      "a child facet whose collection is not among the facets stands alone
      IF ls_facet-parent_id IS NOT INITIAL AND line_exists( lt_facets[ id = ls_facet-parent_id ] ).
        ls_section-parent_id = ls_facet-parent_id.
      ENDIF.

      IF ls_facet-type CS `COLLECTION`.
        ls_section-type = `COLLECTION`.
      ELSEIF ls_facet-type CS `IDENTIFICATION`.
        ls_section-type = `IDENTIFICATION`.
        IF get_identification_fields( ) IS INITIAL.
          CONTINUE.
        ENDIF.
      ELSEIF ls_facet-type CS `LINEITEM`.
        ls_section-type = `LINEITEM`.
        IF ls_section-association IS INITIAL.
          CONTINUE.
        ENDIF.
      ELSEIF ( ls_facet-type IS INITIAL OR ls_facet-type CS `FIELDGROUP` )
        AND ls_facet-target_qualifier IS NOT INITIAL.
        ls_section-type = `FIELDGROUP`.
        IF NOT line_exists( ms_entity-fields[ field_group = ls_facet-target_qualifier ] ).
          "the field may sit in the group as its second entry
          DATA(lv_found) = abap_false.
          LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
            IF line_exists( ls_field-field_groups[ qualifier = ls_facet-target_qualifier ] ).
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
          IF lv_found = abap_false.
            CONTINUE.
          ENDIF.
        ENDIF.
      ELSE.
        CONTINUE.
      ENDIF.

      IF ls_section-title IS INITIAL.
        ls_section-title = COND #( WHEN ls_section-field_group IS NOT INITIAL THEN ls_section-field_group
                                   WHEN ls_section-association IS NOT INITIAL THEN ls_section-association
                                   ELSE ls_section-id ).
      ENDIF.
      APPEND ls_section TO result.
    ENDLOOP.

    "a collection without any content left is no section
    LOOP AT result INTO ls_section WHERE type = `COLLECTION`.
      IF NOT line_exists( result[ parent_id = ls_section-id ] ).
        DELETE result WHERE id = ls_section-id.
      ENDIF.
    ENDLOOP.

    "field groups not covered by facets, in order of appearance
    LOOP AT ms_entity-fields INTO ls_field WHERE is_hidden = abap_false.
      LOOP AT ls_field-field_groups INTO DATA(ls_group).
        IF NOT line_exists( result[ field_group = ls_group-qualifier ] ).
          APPEND VALUE ty_s_section(
            id          = ls_group-qualifier
            title       = COND #( WHEN ls_group-group_label IS NOT INITIAL THEN ls_group-group_label ELSE ls_group-qualifier )
            field_group = ls_group-qualifier
            type        = `FIELDGROUP` ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    "no field groups at all -> single section with all visible fields
    IF NOT line_exists( result[ type = `FIELDGROUP` ] ) AND NOT line_exists( result[ type = `IDENTIFICATION` ] ).
      INSERT VALUE ty_s_section( id    = `GENERAL`
                                 title = get_text( cs_text-general )
                                 type  = `FIELDGROUP` ) INTO result INDEX 1.
    ENDIF.

  ENDMETHOD.


  METHOD get_identification_fields.

    "fields annotated with @UI.identification, ordered by position
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE is_identification = abap_true AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result BY identification_pos.

    "fallback: first 3 visible fields (dataPoints are rendered separately)
    IF result IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false AND datapoint_qualifier IS INITIAL.
        APPEND ls_field TO result.
        IF lines( result ) >= 3.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD get_datapoint_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE datapoint_qualifier IS NOT INITIAL AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_criticality_state.
    result = criticality_state( iv_crit_value ).
  ENDMETHOD.


  METHOD get_crit_value.
    FIELD-SYMBOLS <lv_crit> TYPE any.
    ASSIGN COMPONENT iv_field OF STRUCTURE ms_data->* TO <lv_crit>.
    IF sy-subrc = 0.
      TRY.
          result = <lv_crit>.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD get_field_value.
    FIELD-SYMBOLS <lv_val> TYPE any.
    ASSIGN COMPONENT is_field-name OF STRUCTURE ms_data->* TO <lv_val>.
    IF sy-subrc = 0.
      result = format_value( is_field = is_field
                             val      = <lv_val> ).
    ENDIF.
  ENDMETHOD.


  METHOD format_value.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    IF is_field-is_boolean = abap_true.
      result = COND #( WHEN val = abap_true THEN get_text( cs_text-yes ) ELSE get_text( cs_text-no ) ).
      RETURN.
    ENDIF.

    TRY.
        CASE is_field-type_kind.
          WHEN `DATS`.
            lv_date = val.
            IF lv_date IS NOT INITIAL.
              result = |{ lv_date DATE = USER }|.
            ENDIF.
          WHEN `TIMS`.
            lv_time = val.
            IF lv_time IS NOT INITIAL.
              result = |{ lv_time TIME = USER }|.
            ENDIF.
          WHEN OTHERS.
            result = |{ val }|.
        ENDCASE.
      CATCH cx_root.
        result = |{ val }|.
    ENDTRY.

  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_op) = lo_view->ele( n  = `View`
                                 ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `xmlns:uxap`
              v = `sap.uxap`
        )->a( n = `xmlns:form`
              v = `sap.ui.layout.form`
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
                      v = client->_event( cs_event-back )

                )->ele( n  = `ObjectPageLayout`
                         ns = `uxap`
                    )->a( n = `upperCaseAnchorBar`
                          v = `false` ).

    render_header_title( io_op  = lo_op
                         client = client ).

    render_header_content( io_op  = lo_op
                           client = client ).

    render_sections( io_op  = lo_op
                     client = client ).

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_header_title.

    DATA(lo_ht) = io_op->ele( n  = `headerTitle`
                               ns = `uxap`
        )->ele( n  = `ObjectPageDynamicHeaderTitle`
                 ns = `uxap` ).

    "expanded heading - show title
    DATA(lv_title_text) = mv_title.
    IF ms_entity-header_info-title_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_t> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-title_field OF STRUCTURE ms_data->* TO <lv_t>.
      IF sy-subrc = 0 AND <lv_t> IS NOT INITIAL.
        lv_title_text = <lv_t>.
      ENDIF.
    ENDIF.
    lo_ht->ele( n  = `expandedHeading`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    "snapped heading
    lo_ht->ele( n  = `snappedHeading`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    "snapped title on mobile
    lo_ht->ele( n  = `snappedTitleOnMobile`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    DATA(lo_actions) = lo_ht->ele( n  = `actions`
                                    ns = `uxap` ).
    render_actions( io_actions = lo_actions
                    client     = client ).

    "expanded content - show subtitle/description
    IF ms_entity-header_info-description_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_d> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-description_field OF STRUCTURE ms_data->* TO <lv_d>.
      IF sy-subrc = 0 AND <lv_d> IS NOT INITIAL.
        lo_ht->ele( n  = `expandedContent`
                     ns = `uxap`
            )->tag( `Label`
                )->a( n = `text`
                      t = CONV #( <lv_d> ) ).
        lo_ht->ele( n  = `snappedContent`
                     ns = `uxap`
            )->tag( `Label`
                )->a( n = `text`
                      t = CONV #( <lv_d> ) ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD render_actions.

    IF mv_editable = abap_false.
      render_extension( spot         = cs_spot-header_actions
                        io_container = io_actions
                        client       = client ).
      "@UI.identification actions of type #FOR_ACTION
      IF ms_caps-is_rap_bo = abap_true.
        LOOP AT ms_entity-actions INTO DATA(ls_action)
          WHERE source = `IDENTIFICATION` AND semantic_object IS INITIAL.
          io_actions->tag( `Button`
              )->a( n = `text`
                    t = ls_action-label
              )->a( n = `press`
                    v = client->_event( val = cs_event-action
                                        arg = ls_action-name ) ).
        ENDLOOP.
      ENDIF.
      "and of type #FOR_INTENT_BASED_NAVIGATION - to another app
      LOOP AT ms_entity-actions INTO DATA(ls_intent)
        WHERE source = `IDENTIFICATION` AND semantic_object IS NOT INITIAL.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = ls_intent-label
            )->a( n = `press`
                  v = client->_event( val = cs_event-intent
                                      arg = ls_intent-name ) ).
      ENDLOOP.
      IF ms_caps-can_update = abap_true.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-edit )
            )->a( n = `press`
                  v = client->_event( cs_event-edit )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `icon`
                  v = `sap-icon://edit` ).
      ENDIF.
      IF ms_caps-can_delete = abap_true.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-delete )
            )->a( n = `press`
                  v = client->_event( cs_event-delete )
            )->a( n = `type`
                  v = `Reject`
            )->a( n = `icon`
                  v = `sap-icon://delete` ).
      ENDIF.
    ELSE.
      io_actions->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-save )
          )->a( n = `press`
                v = client->_event( cs_event-save )
          )->a( n = `type`
                v = `Emphasized`
          )->a( n = `icon`
                v = `sap-icon://save` ).
      io_actions->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-cancel )
          )->a( n = `press`
                v = client->_event( cs_event-cancel )
          )->a( n = `icon`
                v = `sap-icon://decline` ).
    ENDIF.

  ENDMETHOD.


  METHOD render_header_facets.

    DATA lt_facets TYPE z2ui5_cl_rap_util=>ty_t_facet.
    LOOP AT ms_entity-facets INTO DATA(ls_facet) WHERE purpose CS `HEADER`.
      APPEND ls_facet TO lt_facets.
    ENDLOOP.
    SORT lt_facets BY position.

    LOOP AT lt_facets INTO ls_facet.

      "a data point facet names its data point - without a qualifier it
      "would match the first field that has none
      IF ls_facet-type CS `DATAPOINT` AND ls_facet-target_qualifier IS NOT INITIAL.
        "the target qualifier names the data point
        LOOP AT ms_entity-fields INTO DATA(ls_dp)
          WHERE datapoint_qualifier = ls_facet-target_qualifier AND is_hidden = abap_false.
          DATA(lv_state) = `None`.
          IF ls_dp-datapoint_crit_field IS NOT INITIAL.
            lv_state = get_criticality_state( get_crit_value( ls_dp-datapoint_crit_field ) ).
          ENDIF.
          io_container->ele( `VBox`
              )->a( n = `class`
                    v = `sapUiMediumMarginEnd sapUiSmallMarginBottom`
              )->tag( `Label`
                  )->a( n = `text`
                        t = COND #( WHEN ls_facet-label IS NOT INITIAL THEN ls_facet-label ELSE ls_dp-label )
              )->tag( `ObjectStatus`
                  )->a( n = `text`
                        t = get_display_text( ls_dp )
                  )->a( n = `state`
                        t = lv_state
                  )->a( n = `class`
                        v = `sapMObjectStatusLarge` ).
          EXIT.
        ENDLOOP.

      ELSEIF ls_facet-type CS `FIELDGROUP` AND ls_facet-target_qualifier IS NOT INITIAL.
        DATA(lo_block) = io_container->ele( `VBox`
            )->a( n = `class`
                  v = `sapUiMediumMarginEnd sapUiSmallMarginBottom` ).
        IF ls_facet-label IS NOT INITIAL.
          lo_block->tag( `Title`
              )->a( n = `text`
                    t = ls_facet-label
              )->a( n = `level`
                    v = `H5` ).
        ENDIF.
        DATA lt_group TYPE z2ui5_cl_rap_util=>ty_t_field_info.
        CLEAR lt_group.
        LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
          READ TABLE ls_field-field_groups INTO DATA(ls_group) WITH KEY qualifier = ls_facet-target_qualifier.
          IF sy-subrc = 0.
            ls_field-field_group_pos = ls_group-position.
            APPEND ls_field TO lt_group.
          ENDIF.
        ENDLOOP.
        SORT lt_group BY field_group_pos.
        LOOP AT lt_group INTO ls_field.
          lo_block->ele( `HBox`
              )->tag( `Label`
                  )->a( n = `text`
                        t = |{ ls_field-label }:|
                  )->a( n = `class`
                        v = `sapUiTinyMarginEnd`
              )->tag( `Text`
                  )->a( n = `text`
                        t = get_display_text( ls_field ) ).
        ENDLOOP.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_display_text.

    FIELD-SYMBOLS <lv_text> TYPE any.

    result = get_field_value( is_field ).
    IF is_field-text_element IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT is_field-text_element OF STRUCTURE ms_data->* TO <lv_text>.
    IF sy-subrc <> 0 OR <lv_text> IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_text) = |{ <lv_text> }|.
    result = SWITCH #( is_field-text_arrangement
      WHEN `TEXT_LAST`     THEN |{ result } ({ lv_text })|
      WHEN `TEXT_ONLY`     THEN lv_text
      WHEN `TEXT_SEPARATE` THEN result
      ELSE |{ lv_text } ({ result })| ).

  ENDMETHOD.


  METHOD render_header_content.

    DATA(lo_hc) = io_op->ele( n  = `headerContent`
                               ns = `uxap` ).
    DATA(lo_hbox) = lo_hc->ele( `FlexBox`
        )->a( n = `wrap`
              v = `Wrap`
        )->a( n = `fitContainer`
              v = `true` ).

    "@UI.facet with purpose #HEADER decides the header when there is one
    IF line_exists( ms_entity-facets[ purpose = `#HEADER` ] ) OR line_exists( ms_entity-facets[ purpose = `HEADER` ] ).
      render_header_facets( io_container = lo_hbox
                            client       = client ).
      RETURN.
    ENDIF.

    "identification fields as header attributes
    LOOP AT get_identification_fields( ) INTO DATA(ls_id).
      DATA(lv_val_str) = get_field_value( ls_id ).
      IF lv_val_str IS NOT INITIAL.
        lo_hbox->ele( `VBox`
            )->a( n = `class`
                  v = `sapUiSmallMarginEnd sapUiSmallMarginBottom`
            )->tag( `Label`
                )->a( n = `text`
                      t = ls_id-label
            )->tag( `Text`
                )->a( n = `text`
                      t = lv_val_str ).
      ENDIF.
    ENDLOOP.

    "@UI.dataPoint fields as status attributes with criticality
    LOOP AT get_datapoint_fields( ) INTO DATA(ls_dp).
      lv_val_str = get_field_value( ls_dp ).
      IF lv_val_str IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_state) = `None`.
      IF ls_dp-datapoint_crit_field IS NOT INITIAL.
        lv_state = get_criticality_state( get_crit_value( ls_dp-datapoint_crit_field ) ).
      ENDIF.
      lo_hbox->ele( `VBox`
          )->a( n = `class`
                v = `sapUiSmallMarginEnd sapUiSmallMarginBottom`
          )->tag( `Label`
              )->a( n = `text`
                    t = ls_dp-label
          )->tag( `ObjectStatus`
              )->a( n = `text`
                    t = lv_val_str
              )->a( n = `state`
                    t = lv_state ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_sections.

    DATA(lo_sections) = io_op->ele( n  = `sections`
                                     ns = `uxap` ).

    DATA(lt_sections) = get_sections( ).
    LOOP AT lt_sections INTO DATA(ls_section) WHERE parent_id IS INITIAL.

      "a table section whose target no one resolved has nothing to show
      IF ls_section-type = `LINEITEM` AND NOT line_exists( mt_child[ section_id = ls_section-id ] ).
        CONTINUE.
      ENDIF.

      DATA(lo_section) = lo_sections->ele( n  = `ObjectPageSection`
                                            ns = `uxap`
          )->a( n = `titleUppercase`
                v = `false`
          )->a( n = `title`
                t = ls_section-title ).

      DATA(lo_sub_sections) = lo_section->ele( n  = `subSections`
                                                ns = `uxap` ).

      IF ls_section-type = `COLLECTION`.
        "one subsection per facet of the collection, each with its title
        LOOP AT lt_sections INTO DATA(ls_sub) WHERE parent_id = ls_section-id.
          IF ls_sub-type = `LINEITEM` AND NOT line_exists( mt_child[ section_id = ls_sub-id ] ).
            CONTINUE.
          ENDIF.
          DATA(lo_sub_blocks) = lo_sub_sections->ele( n  = `ObjectPageSubSection`
                                                       ns = `uxap`
              )->a( n = `title`
                    t = ls_sub-title
              )->ele( n  = `blocks`
                      ns = `uxap` ).
          render_section_content( io_parent  = lo_sub_blocks
                                  is_section = ls_sub
                                  client     = client ).
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "showTitle is @since 1.77 - the repo's UI5 floor (abap2ui5lint.jsonc)
      "is set accordingly
      DATA(lo_blocks) = lo_sub_sections->ele( n  = `ObjectPageSubSection`
                                               ns = `uxap`
          )->a( n = `title`
                t = ls_section-title
          )->a( n = `showTitle`
                v = `false`
          )->ele( n  = `blocks`
                   ns = `uxap` ).

      render_section_content( io_parent  = lo_blocks
                              is_section = ls_section
                              client     = client ).
    ENDLOOP.

    render_extension( spot         = cs_spot-sections
                      io_container = lo_sections
                      client       = client ).

  ENDMETHOD.


  METHOD render_section_content.

    CASE is_section-type.
      WHEN `IDENTIFICATION`.
        render_section_fields( io_parent = io_parent
                               it_fields = get_identification_fields( )
                               client    = client ).
      WHEN `LINEITEM`.
        render_section_table( io_parent  = io_parent
                              is_section = is_section
                              client     = client ).
      WHEN OTHERS.
        render_section_form( io_parent = io_parent
                             iv_group  = is_section-field_group
                             client    = client ).
    ENDCASE.

  ENDMETHOD.


  METHOD render_section_form.

    "collect and sort fields for this group
    "(empty group = fields without any fieldGroup annotation)
    DATA lt_sorted TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
      IF iv_group IS INITIAL.
        IF ls_field-field_groups IS INITIAL AND ls_field-field_group IS INITIAL.
          APPEND ls_field TO lt_sorted.
        ENDIF.
        CONTINUE.
      ENDIF.
      READ TABLE ls_field-field_groups INTO DATA(ls_group) WITH KEY qualifier = iv_group.
      IF sy-subrc = 0.
        "the position within THIS group
        ls_field-field_group_pos = ls_group-position.
        APPEND ls_field TO lt_sorted.
      ELSEIF ls_field-field_group = iv_group.
        APPEND ls_field TO lt_sorted.
      ENDIF.
    ENDLOOP.
    SORT lt_sorted BY field_group_pos.

    render_section_fields( io_parent = io_parent
                           it_fields = lt_sorted
                           client    = client ).

  ENDMETHOD.


  METHOD render_section_fields.

    DATA(lo_form) = io_parent->ele( n  = `SimpleForm`
                                     ns = `form`
        )->a( n = `class`
              v = `sapUxAPObjectPageSubSectionAlignContent`
        )->a( n = `editable`
              b = mv_editable
        )->a( n = `layout`
              v = `ColumnLayout`
        )->a( n = `columnsM`
              v = `2`
        )->a( n = `columnsL`
              v = `3`
        )->a( n = `columnsXL`
              v = `4` ).

    LOOP AT it_fields INTO DATA(ls_field).
      FIELD-SYMBOLS <field> TYPE any.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_data->* TO <field>.
      CHECK sy-subrc = 0.

      lo_form->tag( `Label`
          )->a( n = `text`
                t = ls_field-label
          )->a( n = `required`
                b = xsdbool( mv_editable = abap_true AND ls_field-is_mandatory = abap_true ) ).

      "=== EDIT MODE: render input controls ===
      IF mv_editable = abap_true.

        "the message of the last save about this field, if there is one
        DATA(lv_value_state) = ``.
        DATA(lv_value_state_text) = ``.
        LOOP AT mt_messages INTO DATA(ls_message).
          IF line_exists( ls_message-fields[ table_line = ls_field-name ] ).
            lv_value_state = SWITCH #( ls_message-type
              WHEN `error`   THEN `Error`
              WHEN `warning` THEN `Warning`
              WHEN `success` THEN `Success`
              ELSE `Information` ).
            lv_value_state_text = ls_message-text.
            EXIT.
          ENDIF.
        ENDLOOP.

        "a key is set once - on create, never on change
        render_field_input( io_container     = lo_form
                            is_field         = ls_field
                            client           = client
                            value            = <field>
                            editable         = xsdbool( ls_field-is_key = abap_false OR mv_is_create = abap_true )
                            vh_event         = cs_event-value_help
                            value_state      = lv_value_state
                            value_state_text = lv_value_state_text ).

      "=== DISPLAY MODE: render read-only controls ===
      ELSE.

        DATA(lv_display_val) = format_value( is_field = ls_field
                                             val      = <field> ).

        "criticality -> ObjectStatus
        IF ls_field-datapoint_crit_field IS NOT INITIAL.
          lo_form->tag( `ObjectStatus`
              )->a( n = `text`
                    t = lv_display_val
              )->a( n = `state`
                    v = get_criticality_state( get_crit_value( ls_field-datapoint_crit_field ) ) ).

        "amount + currency -> ObjectNumber
        ELSEIF ls_field-is_amount_field = abap_true
          AND ls_field-semantics_currency_code IS NOT INITIAL.
          DATA(ls_currency) = VALUE z2ui5_cl_rap_util=>ty_s_field_info(
            name = ls_field-semantics_currency_code ).
          lo_form->tag( `ObjectNumber`
              )->a( n = `number`
                    t = lv_display_val
              )->a( n = `unit`
                    t = get_field_value( ls_currency )
              )->a( n = `emphasized`
                    v = `false` ).

        "quantity + unit -> ObjectNumber
        ELSEIF ls_field-is_quantity_field = abap_true
          AND ls_field-semantics_unit_of_measure IS NOT INITIAL.
          DATA(ls_unit) = VALUE z2ui5_cl_rap_util=>ty_s_field_info(
            name = ls_field-semantics_unit_of_measure ).
          lo_form->tag( `ObjectNumber`
              )->a( n = `number`
                    t = lv_display_val
              )->a( n = `unit`
                    t = get_field_value( ls_unit )
              )->a( n = `emphasized`
                    v = `false` ).

        ELSE.
          lo_form->tag( `Text`
              )->a( n = `text`
                    t = get_display_text( ls_field ) ).
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD render_section_table.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY section_id = is_section-id.
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "the columns of the child's @UI.lineItem, else its first visible fields
    DATA lt_columns TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    LOOP AT ls_child-entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO lt_columns.
    ENDLOOP.
    SORT lt_columns BY line_item_pos.
    IF lt_columns IS INITIAL.
      LOOP AT ls_child-entity-fields INTO ls_field WHERE is_hidden = abap_false.
        APPEND ls_field TO lt_columns.
        IF lines( lt_columns ) >= 6.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA(lo_table) = io_parent->ele( `Table`
        )->a( n = `items`
              v = `{path:'` && client->_bind( val  = <lt_rows>
                                              path = abap_true ) && `'}`
        )->a( n = `growing`
              v = `true` ).

    "a new child of this record - a create by association
    IF ls_child-can_create = abap_true AND mv_editable = abap_false.
      DATA(lo_toolbar) = lo_table->ele( `headerToolbar`
          )->ele( `OverflowToolbar` ).
      lo_toolbar->tag( `ToolbarSpacer` ).
      lo_toolbar->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-create )
          )->a( n = `icon`
                v = `sap-icon://add`
          )->a( n = `press`
                v = client->_event( val = cs_event-child_create
                                    arg = ls_child-component ) ).
    ENDIF.

    DATA(lo_columns) = lo_table->ele( `columns` ).
    LOOP AT lt_columns INTO ls_field.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = COND #( WHEN ls_field-line_item_label IS NOT INITIAL THEN ls_field-line_item_label
                                ELSE ls_field-label ) ).
    ENDLOOP.

    DATA(lt_arg) = VALUE string_table( ( ls_child-component ) ).
    LOOP AT ls_child-entity-keys INTO DATA(lv_key).
      APPEND `${` && lv_key && `}` TO lt_arg.
    ENDLOOP.

    DATA(lo_item) = lo_table->ele( `items`
        )->ele( `ColumnListItem` ).
    "a row opens its own object page - which needs the child's keys
    IF ls_child-entity-keys IS NOT INITIAL.
      lo_item->a( n = `type`
                  v = `Navigation`
          )->a( n = `press`
                v = client->_event( val   = cs_event-child_row
                                    t_arg = lt_arg ) ).
    ENDIF.
    DATA(lo_cells) = lo_item->ele( `cells` ).

    LOOP AT lt_columns INTO ls_field.
      IF ls_field-datapoint_crit_field IS NOT INITIAL OR ls_field-line_item_crit_field IS NOT INITIAL.
        lo_cells->tag( `ObjectStatus`
            )->a( n = `text`
                  v = |\{{ ls_field-name }\}|
            )->a( n = `state`
                  v = criticality_expression( COND #( WHEN ls_field-line_item_crit_field IS NOT INITIAL
                                                      THEN ls_field-line_item_crit_field
                                                      ELSE ls_field-datapoint_crit_field ) ) ).
      ELSE.
        lo_cells->tag( `Text`
            )->a( n = `text`
                  v = |\{{ ls_field-name }\}| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
