"! What every floorplan of the addon shares: reading rows of a CDS entity,
"! the filter and search syntax, the control for a field, calling and
"! applying a value help, writing through RAP (or a database table), the
"! texts and the extension points (z2ui5_if_rap_ext).
"!
"! Everything here is PROTECTED and therefore part of the escape hatch: a
"! subclass of any floorplan can call or redefine it. The floorplans keep
"! their own steps (render_page, load_data, ...) - this class only holds
"! what used to be copied between them.
CLASS z2ui5_cl_rap_floorplan DEFINITION
  PUBLIC
  CREATE PROTECTED.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_floorplan,
        list_report   TYPE string VALUE `LIST_REPORT`,
        worklist      TYPE string VALUE `WORKLIST`,
        object_page   TYPE string VALUE `OBJECT_PAGE`,
        value_help    TYPE string VALUE `VALUE_HELP`,
        action_dialog TYPE string VALUE `ACTION_DIALOG`,
        overview_page TYPE string VALUE `OVERVIEW_PAGE`,
      END OF cs_floorplan.

    " The keys of get_text( ) - z2ui5_if_rap_ext~get_text translates them
    CONSTANTS:
      BEGIN OF cs_text,
        create         TYPE string VALUE `CREATE`,
        edit           TYPE string VALUE `EDIT`,
        delete         TYPE string VALUE `DELETE`,
        save           TYPE string VALUE `SAVE`,
        cancel         TYPE string VALUE `CANCEL`,
        ok             TYPE string VALUE `OK`,
        go             TYPE string VALUE `GO`,
        refresh        TYPE string VALUE `REFRESH`,
        search         TYPE string VALUE `SEARCH`,
        yes            TYPE string VALUE `YES`,
        no             TYPE string VALUE `NO`,
        all            TYPE string VALUE `ALL`,
        general        TYPE string VALUE `GENERAL`,
        items          TYPE string VALUE `ITEMS`,
        saved          TYPE string VALUE `SAVED`,
        deleted        TYPE string VALUE `DELETED`,
        refreshed      TYPE string VALUE `REFRESHED`,
        action_done    TYPE string VALUE `ACTION_DONE`,
        required       TYPE string VALUE `REQUIRED`,
        read_only      TYPE string VALUE `READ_ONLY`,
        load_error     TYPE string VALUE `LOAD_ERROR`,
        no_selection   TYPE string VALUE `NO_SELECTION`,
        filter_hint    TYPE string VALUE `FILTER_HINT`,
        create_title   TYPE string VALUE `CREATE_TITLE`,
        sort           TYPE string VALUE `SORT`,
        more           TYPE string VALUE `MORE`,
        "added 2026-10
        no_authority   TYPE string VALUE `NO_AUTHORITY`,
        locked         TYPE string VALUE `LOCKED`,
        changed        TYPE string VALUE `CHANGED`,
      END OF cs_text.

    " Where z2ui5_if_rap_ext~extend_view may add controls
    CONSTANTS:
      BEGIN OF cs_spot,
        "the table toolbar of the list report and the worklist
        toolbar        TYPE string VALUE `TOOLBAR`,
        "the header actions of the object page
        header_actions TYPE string VALUE `HEADER_ACTIONS`,
        "the sections of the object page - add ObjectPageSections
        sections       TYPE string VALUE `SECTIONS`,
        "the content of the action dialog, below the form
        dialog_content TYPE string VALUE `DIALOG_CONTENT`,
        "the grid of the overview page - add cards
        cards          TYPE string VALUE `CARDS`,
      END OF cs_spot.

    "! The selection column added to rows a table or dialog lets the user
    "! select - the name the core's own select popup uses
    CONSTANTS cv_select_column TYPE string VALUE `ZZSELKZ`.

    TYPES:
      BEGIN OF ty_s_capabilities,
        "a RAP business object (a BDEF with this entity as root)
        is_rap_bo  TYPE abap_bool,
        "a transparent database table - written with ABAP SQL, and only
        "where z2ui5_if_rap_ext~adjust_capabilities allows it
        is_table   TYPE abap_bool,
        can_create TYPE abap_bool,
        can_update TYPE abap_bool,
        can_delete TYPE abap_bool,
      END OF ty_s_capabilities.


    TYPES:
      BEGIN OF ty_s_name_value,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_name_value.

    TYPES ty_t_name_value TYPE STANDARD TABLE OF ty_s_name_value WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_result,
        success  TYPE abap_bool,
        messages TYPE string_table,
        "the keys of a created instance, as RAP assigned them (MAPPED)
        keys     TYPE ty_t_name_value,
      END OF ty_s_result.

    "! The dropdown entries of the fields that have a small value help
    "! (sizeCategory #XS) - one component per field, each a table of the
    "! value help entity. PUBLIC and a REF TO data because that is what the
    "! abap2UI5 model resolves a binding into and carries through the draft.
    DATA mr_value_lists TYPE REF TO data.

    "! Hand the floorplan an implementation of the extension points
    METHODS set_extension
      IMPORTING
        ext TYPE REF TO z2ui5_if_rap_ext.

    "! What can be written to an entity - asked from the BDEF derived types
    "! (a BDEF without `delete` has no delete type). A transparent table is
    "! recognized (is_table) but answered read-only: up to 2026-10 every
    "! table a floorplan was opened on could be changed and deleted by
    "! anyone who reached the app. The writes of a table are switched on per
    "! entity by z2ui5_if_rap_ext~adjust_capabilities - what the floorplans
    "! ask is get_entity_capabilities( ), which applies it
    CLASS-METHODS get_capabilities
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_capabilities.

    "! RAP is there (IF_ABAP_BEHV exists) - answered from RTTI, so asking
    "! never loads z2ui5_cl_rap_eml
    CLASS-METHODS eml_available
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.

    DATA mo_ext TYPE REF TO z2ui5_if_rap_ext.
    "! one of cs_floorplan - set by the constructor of each floorplan
    DATA mv_floorplan TYPE string.
    "! the field a called value help fills on return
    DATA mv_vh_target TYPE string.

    "! the name select_rows( ) gives the host structure - a dynamic WHERE
    "! compares with its components as @<LS_HOST>-name
    CONSTANTS cv_host TYPE string VALUE `<LS_HOST>`.

    "! what this floorplan lets the user write to entity_name: the
    "! capabilities of the entity, as the extension adjusts them
    "! (z2ui5_if_rap_ext~adjust_capabilities). Every write and action goes
    "! through it, not only the buttons - an event a browser sends without
    "! the button is refused the same way
    METHODS get_entity_capabilities
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_capabilities.

    "! the WHERE condition that compares every field of names with the
    "! component of the same name of the host structure (select_rows,
    "! parameter host) - typed host variables instead of literals, so a RAW
    "! key (a UUID) or a date compares with a value of its own type
    METHODS build_key_condition
      IMPORTING
        names         TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! a structure of the entity with the fields of values set - the host
    "! structure of a key condition (build_key_condition). A value is the
    "! text form a row, an event argument or a URL carries: a date as
    "! 2024-01-15 or 20240115, a RAW as its hex digits
    METHODS create_host
      IMPORTING
        entity_name   TYPE string
        values        TYPE ty_t_name_value
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the text for a key of cs_text - the extension can change it
    METHODS get_text
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! let the extension adjust the metadata
    METHODS adjust_entity
      CHANGING
        cs_entity TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    "! let the extension add controls at one of the cs_spot places
    METHODS render_extension
      IMPORTING
        spot         TYPE string
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        client       TYPE REF TO z2ui5_if_client.

    "! let the extension take an event over - abap_true when it did
    METHODS ext_on_event
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! SELECT * FROM entity_name WHERE where UP TO max_rows into a table of
    "! the entity - with_selection adds the column cv_select_column
    METHODS select_rows
      IMPORTING
        entity_name    TYPE string
        where          TYPE string OPTIONAL
        max_rows       TYPE i DEFAULT 500
        with_selection TYPE abap_bool DEFAULT abap_false
        "an ABAP SQL ORDER BY list, e.g. `TRAVELID DESCENDING, STATUS`
        order_by       TYPE string OPTIONAL
        "a structure where compares with as @<LS_HOST>-name (cv_host,
        "build_key_condition) - added 2026-10
        host           TYPE REF TO data OPTIONAL
      RETURNING
        VALUE(result)  TYPE REF TO data.

    "! where, as the extension adjusts it (z2ui5_if_rap_ext~adjust_where) -
    "! every read of rows goes through it, aggregates included
    METHODS get_ext_where
      IMPORTING
        entity_name   TYPE string
        where         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! the number of rows of entity_name that match where
    METHODS count_rows
      IMPORTING
        entity_name   TYPE string
        where         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE i.

    "! the WHERE condition for the user's filter text on one field - the
    "! syntax is z2ui5_cl_rap_util=>build_filter_condition's
    METHODS build_filter_condition
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the WHERE condition of a free-text search over the searchable text
    "! fields (@Search.defaultSearchElement, else every visible text field)
    METHODS build_search_condition
      IMPORTING
        it_fields     TYPE z2ui5_cl_rap_util=>ty_t_field_info
        search        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the expression binding that maps a criticality field (0-3) to a
    "! ValueState - for an ObjectStatus in a table cell
    METHODS criticality_expression
      IMPORTING
        crit_field    TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! criticality 1/2/3 as the ValueState Error/Warning/Success
    METHODS criticality_state
      IMPORTING
        value         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! fill mr_value_lists for every field of it_fields with a dropdown
    "! value help - run it before rendering the controls of those fields
    METHODS prepare_value_lists
      IMPORTING
        it_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the input control for one field, bound to value (a component of a
    "! public attribute): CheckBox, DatePicker, TimePicker, TextArea,
    "! ComboBox (dropdown value help), Input with value help, Input
    METHODS render_field_input
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_field     TYPE z2ui5_cl_rap_util=>ty_s_field_info
        client       TYPE REF TO z2ui5_if_client
        value        TYPE data
        editable     TYPE abap_bool DEFAULT abap_true
        vh_event     TYPE string OPTIONAL.

    "! call the value help of is_field; source holds the values for the
    "! additional bindings with usage FILTER (the structure being edited)
    METHODS open_value_help
      IMPORTING
        client       TYPE REF TO z2ui5_if_client
        is_field     TYPE z2ui5_cl_rap_util=>ty_s_field_info
        source       TYPE data OPTIONAL
        multi_select TYPE abap_bool DEFAULT abap_false.

    "! the value help this floorplan called, when the roundtrip is its
    "! return and the user confirmed - unbound otherwise
    METHODS get_value_help_result
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_rap_value_help.

    "! on the return from open_value_help: write the selected value (and
    "! the additional bindings with usage RESULT) into target
    METHODS apply_value_help
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
        it_fields     TYPE z2ui5_cl_rap_util=>ty_t_field_info
      CHANGING
        target        TYPE data
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the row of data (a table) whose key fields equal the event arguments
    "! arg_offset + 1 ... - how a row press identifies its row
    METHODS find_row_by_event_keys
      IMPORTING
        data          TYPE REF TO data
        key_fields    TYPE string_table
        client        TYPE REF TO z2ui5_if_client
        arg_offset    TYPE i DEFAULT 0
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the row of data (a table) whose key fields equal key_values
    METHODS find_row_by_keys
      IMPORTING
        data          TYPE REF TO data
        key_fields    TYPE string_table
        key_values    TYPE string_table
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! an empty table of the entity
    METHODS create_entity_table
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! a copy of row typed as the entity - drops the selection column
    METHODS to_entity_row
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the rows of data (a table with the selection column) the user
    "! selected, as a table of the entity
    METHODS get_selected_rows
      IMPORTING
        entity_name   TYPE string
        data          TYPE REF TO data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! write one row: operation is CREATE, UPDATE or DELETE. Through RAP when
    "! the entity is a business object, with ABAP SQL when it is a table
    "! whose writes the extension allowed (get_entity_capabilities) - an
    "! operation the entity does not allow is refused here, whoever asks
    METHODS write_row
      IMPORTING
        entity_name   TYPE string
        operation     TYPE string
        row           TYPE data
        original      TYPE data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! run a RAP action on rows (a table of the entity)
    METHODS run_action
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
        rows          TYPE REF TO data
        param         TYPE REF TO data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the parameter structure of a RAP action, unbound when it has none
    METHODS create_action_parameter
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! a message box with every message
    METHODS show_messages
      IMPORTING
        client   TYPE REF TO z2ui5_if_client
        messages TYPE string_table
        type     TYPE string DEFAULT `error`.

    "! write one row of a database table with ABAP SQL: the authorization
    "! S_TABU_NAM (activity 02) for the table, a lock (ENQUEUE_E_TABLE) on
    "! the row's key, and for UPDATE and DELETE the check that the row is
    "! still what the user saw (original) - a change of somebody else in
    "! between is reported instead of overwritten
    METHODS write_table_row
      IMPORTING
        entity_name   TYPE string
        operation     TYPE string
        row           TYPE data
        original      TYPE data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! align ABAP and JSON model representations (dates, times, padding)
    METHODS normalize_key_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

    CLASS-METHODS try_create_data
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the lock argument of ENQUEUE_E_TABLE for one row: the key fields in
    "! their internal form, one after the other - empty (the whole table)
    "! when a key field is not character-like or the key is too long
    METHODS get_table_varkey
      IMPORTING
        row           TYPE data
        key_fields    TYPE ddfields
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.



CLASS z2ui5_cl_rap_floorplan IMPLEMENTATION.

  METHOD set_extension.
    mo_ext = ext.
  ENDMETHOD.


  METHOD eml_available.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = `IF_ABAP_BEHV`
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD get_capabilities.

    DATA(lv_entity) = to_upper( entity_name ).
    IF lv_entity IS INITIAL.
      RETURN.
    ENDIF.

    IF eml_available( ) = abap_true.
      DATA(lv_base) = |\\BDEF={ lv_entity }\\ENTITY={ lv_entity }|.
      result-can_create = try_create_data( lv_base && `\TYPE=CREATE` ).
      result-can_update = try_create_data( lv_base && `\TYPE=UPDATE` ).
      result-can_delete = try_create_data( lv_base && `\TYPE=DELETE` ).
      result-is_rap_bo = xsdbool( result-can_create = abap_true
                               OR result-can_update = abap_true
                               OR result-can_delete = abap_true
                               OR try_create_data( lv_base && `\TYPE=READ_R` ) = abap_true ).
      IF result-is_rap_bo = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    "a transparent table - what the object page wrote before RAP support.
    "A CDS view is never writable with ABAP SQL, so it ends here read-only,
    "and so does a table until get_entity_capabilities( ) is told otherwise
    TRY.
        DATA lv_tabclass TYPE c LENGTH 8.
        SELECT SINGLE tabclass FROM dd02l
          WHERE tabname  = @lv_entity
            AND as4local = 'A'
          INTO @lv_tabclass.
        "read-only until the extension allows the writes
        result-is_table = xsdbool( sy-subrc = 0 AND lv_tabclass = `TRANSP` ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD try_create_data.
    DATA lr_data TYPE REF TO data.
    TRY.
        CREATE DATA lr_data TYPE (name).
        result = abap_true.
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD get_text.

    "German for a German logon, English otherwise - every other language
    "goes through z2ui5_if_rap_ext~get_text
    IF sy-langu = 'D'.
      result = SWITCH #( key
        WHEN cs_text-create       THEN `Anlegen`
        WHEN cs_text-edit         THEN `Bearbeiten`
        WHEN cs_text-delete       THEN `Löschen`
        WHEN cs_text-save         THEN `Sichern`
        WHEN cs_text-cancel       THEN `Abbrechen`
        WHEN cs_text-ok           THEN `OK`
        WHEN cs_text-go           THEN `Start`
        WHEN cs_text-refresh      THEN `Aktualisieren`
        WHEN cs_text-search       THEN `Suchen`
        WHEN cs_text-yes          THEN `Ja`
        WHEN cs_text-no           THEN `Nein`
        WHEN cs_text-all          THEN `Alle`
        WHEN cs_text-general      THEN `Allgemein`
        WHEN cs_text-items        THEN `Einträge`
        WHEN cs_text-saved        THEN `Daten gesichert`
        WHEN cs_text-deleted      THEN `Daten gelöscht`
        WHEN cs_text-refreshed    THEN `Daten aktualisiert`
        WHEN cs_text-action_done  THEN `Aktion ausgeführt`
        WHEN cs_text-required     THEN `Bitte alle Pflichtfelder füllen`
        WHEN cs_text-read_only    THEN `Diese Entität kann nicht geändert werden`
        WHEN cs_text-load_error   THEN `Daten konnten nicht gelesen werden`
        WHEN cs_text-no_selection THEN `Bitte mindestens eine Zeile markieren`
        WHEN cs_text-filter_hint  THEN `abc, a*c, =abc, !abc, a..z, >x - mehrere mit ; trennen`
        WHEN cs_text-create_title THEN `Anlegen`
        WHEN cs_text-sort         THEN `Sortieren`
        WHEN cs_text-more         THEN `Mehr`
        WHEN cs_text-no_authority THEN `Keine Berechtigung`
        WHEN cs_text-locked       THEN `Der Eintrag ist gesperrt`
        WHEN cs_text-changed      THEN `Der Eintrag wurde inzwischen geändert - bitte neu lesen`
        ELSE key ).
    ELSE.
      result = SWITCH #( key
      WHEN cs_text-create       THEN `Create`
      WHEN cs_text-edit         THEN `Edit`
      WHEN cs_text-delete       THEN `Delete`
      WHEN cs_text-save         THEN `Save`
      WHEN cs_text-cancel       THEN `Cancel`
      WHEN cs_text-ok           THEN `OK`
      WHEN cs_text-go           THEN `Go`
      WHEN cs_text-refresh      THEN `Refresh`
      WHEN cs_text-search       THEN `Search`
      WHEN cs_text-yes          THEN `Yes`
      WHEN cs_text-no           THEN `No`
      WHEN cs_text-all          THEN `All`
      WHEN cs_text-general      THEN `General`
      WHEN cs_text-items        THEN `items`
      WHEN cs_text-saved        THEN `Data saved`
      WHEN cs_text-deleted      THEN `Data deleted`
      WHEN cs_text-refreshed    THEN `Data refreshed`
      WHEN cs_text-action_done  THEN `Action executed`
      WHEN cs_text-required     THEN `Fill in all required fields`
      WHEN cs_text-read_only    THEN `This entity cannot be changed`
      WHEN cs_text-load_error   THEN `Could not load data`
      WHEN cs_text-no_selection THEN `Select at least one row`
      WHEN cs_text-filter_hint  THEN `abc, a*c, =abc, !abc, a..z, >x - separate several with ;`
      WHEN cs_text-create_title THEN `Create`
      WHEN cs_text-sort         THEN `Sort`
      WHEN cs_text-more         THEN `More`
      WHEN cs_text-no_authority THEN `No authorization`
      WHEN cs_text-locked       THEN `The record is locked`
      WHEN cs_text-changed      THEN `The record was changed meanwhile - read it again`
      ELSE key ).
    ENDIF.

    IF mo_ext IS BOUND.
      mo_ext->get_text( EXPORTING key  = key
                        CHANGING  text = result ).
    ENDIF.

  ENDMETHOD.


  METHOD adjust_entity.
    IF mo_ext IS BOUND.
      mo_ext->adjust_entity( EXPORTING floorplan = mv_floorplan
                             CHANGING  entity    = cs_entity ).
    ENDIF.
  ENDMETHOD.


  METHOD render_extension.
    IF mo_ext IS BOUND.
      mo_ext->extend_view( floorplan = mv_floorplan
                           spot      = spot
                           container = io_container
                           client    = client ).
    ENDIF.
  ENDMETHOD.


  METHOD ext_on_event.
    IF mo_ext IS BOUND.
      result = mo_ext->on_event( floorplan = mv_floorplan
                                 client    = client ).
    ENDIF.
  ENDMETHOD.


  METHOD select_rows.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    "the host structure - a dynamic WHERE names it as @<LS_HOST>-field
    "(cv_host), so the name of this field symbol is part of the contract
    FIELD-SYMBOLS <ls_host> TYPE any.

    IF host IS BOUND.
      ASSIGN host->* TO <ls_host>.
    ENDIF.

    DATA(lv_where) = get_ext_where( entity_name = entity_name
                                    where       = where ).

    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        IF with_selection = abap_true.
          DATA(lt_comp) = lo_struct->get_components( ).
          IF NOT line_exists( lt_comp[ name = cv_select_column ] ).
            APPEND VALUE #( name = cv_select_column
                            type = CAST #( cl_abap_typedescr=>describe_by_name( `ABAP_BOOL` ) ) ) TO lt_comp.
          ENDIF.
          lo_struct = cl_abap_structdescr=>create( lt_comp ).
        ENDIF.
        DATA(lo_table) = cl_abap_tabledescr=>create( lo_struct ).
        CREATE DATA result TYPE HANDLE lo_table.
        ASSIGN result->* TO <lt_data>.

        "sorted in the database - UP TO n ROWS without an ORDER BY is n
        "arbitrary rows, and sorting them afterwards sorts the wrong ones
        IF with_selection = abap_true AND order_by IS NOT INITIAL.
          SELECT * FROM (entity_name)
            WHERE (lv_where)
            ORDER BY (order_by)
            INTO CORRESPONDING FIELDS OF TABLE @<lt_data>
            UP TO @max_rows ROWS.
        ELSEIF with_selection = abap_true.
          SELECT * FROM (entity_name)
            WHERE (lv_where)
            INTO CORRESPONDING FIELDS OF TABLE @<lt_data>
            UP TO @max_rows ROWS.
        ELSEIF order_by IS NOT INITIAL.
          SELECT * FROM (entity_name)
            WHERE (lv_where)
            ORDER BY (order_by)
            INTO TABLE @<lt_data>
            UP TO @max_rows ROWS.
        ELSE.
          SELECT * FROM (entity_name)
            WHERE (lv_where)
            INTO TABLE @<lt_data>
            UP TO @max_rows ROWS.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
        RETURN.
    ENDTRY.

    IF mo_ext IS BOUND.
      mo_ext->after_load( floorplan   = mv_floorplan
                          entity_name = entity_name
                          data        = result ).
    ENDIF.

  ENDMETHOD.


  METHOD get_ext_where.
    result = where.
    IF mo_ext IS BOUND.
      mo_ext->adjust_where( EXPORTING floorplan   = mv_floorplan
                                      entity_name = entity_name
                            CHANGING  where       = result ).
    ENDIF.
  ENDMETHOD.


  METHOD count_rows.

    DATA(lv_where) = get_ext_where( entity_name = entity_name
                                    where       = where ).
    TRY.
        SELECT COUNT(*) FROM (entity_name)
          WHERE (lv_where)
          INTO @result.
      CATCH cx_root.
        result = 0.
    ENDTRY.

  ENDMETHOD.


  METHOD build_filter_condition.
    result = z2ui5_cl_rap_util=>build_filter_condition( is_field = is_field
                                                        value    = value ).
  ENDMETHOD.


  METHOD build_search_condition.
    result = z2ui5_cl_rap_util=>build_search_condition( it_fields = it_fields
                                                        search    = search ).
  ENDMETHOD.


  METHOD criticality_expression.
    result = `{= ${` && crit_field &&
             `} === 3 ? 'Success' : (${` && crit_field &&
             `} === 1 ? 'Error' : (${` && crit_field &&
             `} === 2 ? 'Warning' : 'None')) }`.
  ENDMETHOD.


  METHOD criticality_state.
    result = SWITCH #( value
      WHEN 1 THEN `Error`
      WHEN 2 THEN `Warning`
      WHEN 3 THEN `Success`
      ELSE `None` ).
  ENDMETHOD.


  METHOD prepare_value_lists.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_lists TYPE STANDARD TABLE OF REF TO data WITH DEFAULT KEY.
    FIELD-SYMBOLS <ls_lists> TYPE any.
    FIELD-SYMBOLS <lt_target> TYPE any.
    FIELD-SYMBOLS <lt_source> TYPE any.

    CLEAR mr_value_lists.

    LOOP AT it_fields INTO DATA(ls_field)
      WHERE value_help-is_dropdown = abap_true AND is_hidden = abap_false.
      DATA(lr_rows) = select_rows( entity_name = ls_field-value_help-entity_name ).
      IF lr_rows IS NOT BOUND OR line_exists( lt_comp[ name = ls_field-name ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = ls_field-name
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_rows ) ) )
        TO lt_comp.
      APPEND lr_rows TO lt_lists.
    ENDLOOP.

    IF lt_comp IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_struct) = cl_abap_structdescr=>create( lt_comp ).
    CREATE DATA mr_value_lists TYPE HANDLE lo_struct.
    ASSIGN mr_value_lists->* TO <ls_lists>.
    LOOP AT lt_lists INTO DATA(lr_list).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE <ls_lists> TO <lt_target>.
      ASSIGN lr_list->* TO <lt_source>.
      <lt_target> = <lt_source>.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_field_input.

    FIELD-SYMBOLS <ls_lists> TYPE any.
    FIELD-SYMBOLS <lt_list> TYPE any.

    DATA(lv_editable) = xsdbool( editable = abap_true AND is_field-is_readonly = abap_false ).

    IF is_field-is_boolean = abap_true.
      io_container->tag( `CheckBox`
          )->a( n = `selected`
                v = client->_bind( value )
          )->a( n = `editable`
                b = lv_editable ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `DATS`.
      "the model carries a date as 2024-01-15 (the core's JSON)
      io_container->tag( `DatePicker`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `valueFormat`
                v = `yyyy-MM-dd`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `TIMS`.
      io_container->tag( `TimePicker`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `valueFormat`
                v = `HH:mm:ss`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      RETURN.
    ENDIF.

    IF is_field-is_multiline = abap_true OR is_field-type_kind = `STRING`.
      io_container->tag( `TextArea`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `rows`
                v = `3`
          )->a( n = `width`
                v = `100%`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      RETURN.
    ENDIF.

    IF is_field-value_help-is_dropdown = abap_true AND mr_value_lists IS BOUND.
      ASSIGN mr_value_lists->* TO <ls_lists>.
      ASSIGN COMPONENT is_field-name OF STRUCTURE <ls_lists> TO <lt_list>.
      IF sy-subrc = 0.
        DATA(lv_key_path) = |\{{ is_field-value_help-element }\}|.
        "the core prefix is declared here, so no view has to carry it for
        "a ComboBox it may never render
        io_container->ele( `ComboBox`
            )->a( n = `xmlns:core`
                  v = `sap.ui.core`
            )->a( n = `selectedKey`
                  v = client->_bind( value )
            )->a( n = `items`
                  v = client->_bind( <lt_list> )
            )->a( n = `editable`
                  b = lv_editable
            )->a( n = `required`
                  b = is_field-is_mandatory
            )->tag( n  = `Item`
                    ns = `core`
                )->a( n = `key`
                      v = lv_key_path
                )->a( n = `text`
                      v = lv_key_path ).
        RETURN.
      ENDIF.
    ENDIF.

    IF is_field-value_help-entity_name IS NOT INITIAL AND vh_event IS NOT INITIAL.
      io_container->tag( `Input`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `showValueHelp`
                v = `true`
          )->a( n = `valueHelpRequest`
                v = client->_event( val = vh_event
                                    arg = is_field-name )
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `CHAR` AND is_field-length > 0.
      io_container->tag( `Input`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `maxLength`
                v = |{ is_field-length }|
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      RETURN.
    ENDIF.

    io_container->tag( `Input`
        )->a( n = `value`
              v = client->_bind( value )
        )->a( n = `editable`
              b = lv_editable
        )->a( n = `required`
              b = is_field-is_mandatory ).

  ENDMETHOD.


  METHOD open_value_help.

    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lt_filter TYPE ty_t_name_value.

    "additional bindings with usage FILTER (or no usage, which is both)
    "restrict the value help by what is already entered
    IF source IS SUPPLIED.
      LOOP AT is_field-value_help-additional_binding INTO DATA(ls_bind)
        WHERE local_element IS NOT INITIAL AND element IS NOT INITIAL.
        IF ls_bind-usage IS NOT INITIAL AND ls_bind-usage NS `FILTER`.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-local_element OF STRUCTURE source TO <lv_value>.
        IF sy-subrc = 0 AND <lv_value> IS NOT INITIAL.
          APPEND VALUE #( name = ls_bind-element value = |{ <lv_value> }| ) TO lt_filter.
        ENDIF.
      ENDLOOP.
    ENDIF.

    mv_vh_target = is_field-name.

    DATA(lo_vh) = NEW z2ui5_cl_rap_value_help(
      cds_view_name = is_field-value_help-entity_name
      element       = is_field-value_help-element
      title         = is_field-label
      multi_select  = multi_select
      filters       = lt_filter ).
    lo_vh->set_extension( mo_ext ).
    client->nav_app_call( lo_vh ).

  ENDMETHOD.


  METHOD get_value_help_result.

    "mv_vh_target says a value help was called - not check_app_prev_stack( ),
    "which answers whether THIS app has a caller: a floorplan that is the
    "root app (started directly, restored from a bookmark) has none, and its
    "value help results were dropped
    IF mv_vh_target IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_vh) = CAST z2ui5_cl_rap_value_help( client->get_app_prev( ) ).
        IF lo_vh->was_confirmed( ) = abap_true.
          result = lo_vh.
        ELSEIF lo_vh->load_error( ) IS NOT INITIAL.
          "the value help could not say it itself - a message queued before
          "nav_app_leave( ) does not reach the browser
          client->message_box_display( text = lo_vh->load_error( )
                                       type = `error` ).
        ENDIF.
      "a cast error, or a previous app the draft no longer has
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD apply_value_help.

    FIELD-SYMBOLS <lv_target> TYPE any.
    FIELD-SYMBOLS <lv_source> TYPE any.
    FIELD-SYMBOLS <ls_row> TYPE any.

    DATA(lo_vh) = get_value_help_result( client ).
    DATA(lv_field) = mv_vh_target.
    CLEAR mv_vh_target.
    IF lo_vh IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT lv_field OF STRUCTURE target TO <lv_target>.
    IF sy-subrc = 0.
      <lv_target> = lo_vh->result_value( ).
    ENDIF.

    "additional bindings with usage RESULT (or no usage, which is both)
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = lv_field.
    DATA(lv_found) = xsdbool( sy-subrc = 0 ).
    DATA(lr_row) = lo_vh->result( ).
    IF lv_found = abap_true AND lr_row IS BOUND.
      ASSIGN lr_row->* TO <ls_row>.
      LOOP AT ls_field-value_help-additional_binding INTO DATA(ls_bind)
        WHERE local_element IS NOT INITIAL AND element IS NOT INITIAL.
        IF ls_bind-usage IS NOT INITIAL AND ls_bind-usage NS `RESULT`.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-element OF STRUCTURE <ls_row> TO <lv_source>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-local_element OF STRUCTURE target TO <lv_target>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        <lv_target> = <lv_source>.
      ENDLOOP.
    ENDIF.

    result = abap_true.

  ENDMETHOD.


  METHOD find_row_by_event_keys.

    DATA lt_values TYPE string_table.
    DO lines( key_fields ) TIMES.
      APPEND client->get_event_arg( arg_offset + sy-index ) TO lt_values.
    ENDDO.
    result = find_row_by_keys( data       = data
                               key_fields = key_fields
                               key_values = lt_values ).

  ENDMETHOD.


  METHOD find_row_by_keys.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_val> TYPE any.

    IF data IS NOT BOUND OR key_fields IS INITIAL OR lines( key_values ) < lines( key_fields ).
      RETURN.
    ENDIF.
    ASSIGN data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_match) = abap_true.
      LOOP AT key_fields INTO DATA(lv_key).
        DATA(lv_idx) = sy-tabix.
        ASSIGN COMPONENT lv_key OF STRUCTURE <ls_row> TO <lv_val>.
        IF sy-subrc <> 0
          OR normalize_key_value( |{ <lv_val> }| ) <> normalize_key_value( key_values[ lv_idx ] ).
          lv_match = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_match = abap_true.
        result = REF #( <ls_row> ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD create_entity_table.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        DATA(lo_table) = cl_abap_tabledescr=>create( lo_struct ).
        CREATE DATA result TYPE HANDLE lo_table.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD to_entity_row.

    FIELD-SYMBOLS <ls_row> TYPE any.
    TRY.
        CREATE DATA result TYPE (entity_name).
        ASSIGN result->* TO <ls_row>.
        MOVE-CORRESPONDING row TO <ls_row>.
      CATCH cx_root.
        CREATE DATA result LIKE row.
        ASSIGN result->* TO <ls_row>.
        <ls_row> = row.
    ENDTRY.

  ENDMETHOD.


  METHOD get_selected_rows.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_result> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_selected> TYPE any.

    IF data IS NOT BOUND.
      RETURN.
    ENDIF.
    result = create_entity_table( entity_name ).
    IF result IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN result->* TO <lt_result>.
    ASSIGN data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT cv_select_column OF STRUCTURE <ls_row> TO <lv_selected>.
      IF sy-subrc <> 0 OR <lv_selected> = abap_false.
        CONTINUE.
      ENDIF.
      APPEND INITIAL LINE TO <lt_result> ASSIGNING FIELD-SYMBOL(<ls_result>).
      MOVE-CORRESPONDING <ls_row> TO <ls_result>.
    ENDLOOP.

  ENDMETHOD.


  METHOD write_row.

    DATA lv_cancel TYPE abap_bool.
    DATA lr_row TYPE REF TO data.
    FIELD-SYMBOLS <ls_row> TYPE any.

    "decided here, not by the buttons - an event can arrive without one
    DATA(ls_caps) = get_entity_capabilities( entity_name ).
    DATA(lv_allowed) = SWITCH abap_bool( operation
      WHEN `CREATE` THEN ls_caps-can_create
      WHEN `UPDATE` THEN ls_caps-can_update
      WHEN `DELETE` THEN ls_caps-can_delete
      ELSE abap_false ).
    IF lv_allowed = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.

    CREATE DATA lr_row LIKE row.
    ASSIGN lr_row->* TO <ls_row>.
    <ls_row> = row.

    IF mo_ext IS BOUND.
      mo_ext->before_save( EXPORTING entity_name = entity_name
                                     operation   = operation
                                     data        = lr_row
                           CHANGING  messages    = result-messages
                                     cancel      = lv_cancel ).
      IF lv_cancel = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    IF ls_caps-is_rap_bo = abap_true.
      CASE operation.
        WHEN `CREATE`.
          result = z2ui5_cl_rap_eml=>create( entity_name = entity_name
                                             row         = <ls_row> ).
        WHEN `UPDATE`.
          result = z2ui5_cl_rap_eml=>update( entity_name = entity_name
                                             row         = <ls_row>
                                             original    = original ).
        WHEN `DELETE`.
          result = z2ui5_cl_rap_eml=>delete( entity_name = entity_name
                                             row         = <ls_row> ).
      ENDCASE.
    ELSE.
      result = write_table_row( entity_name = entity_name
                                operation   = operation
                                row         = <ls_row>
                                original    = original ).
    ENDIF.

    IF result-success = abap_true AND mo_ext IS BOUND.
      mo_ext->after_save( entity_name = entity_name
                          operation   = operation
                          data        = lr_row ).
    ENDIF.

  ENDMETHOD.


  METHOD write_table_row.

    DATA lv_tabname TYPE c LENGTH 30.
    DATA lv_varkey TYPE c LENGTH 120.
    DATA lt_ddic TYPE ddfields.
    DATA lt_keys TYPE string_table.
    DATA lr_current TYPE REF TO data.
    DATA lr_seen TYPE REF TO data.
    "the host structure of the key condition (build_key_condition)
    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <ls_current> TYPE any.
    FIELD-SYMBOLS <ls_seen> TYPE any.
    FIELD-SYMBOLS <lv_from> TYPE any.
    FIELD-SYMBOLS <lv_to> TYPE any.

    lv_tabname = to_upper( entity_name ).

    "the authorization of table maintenance by table name - what SM30 and
    "SE16 ask before a change
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD lv_tabname.
    IF sy-subrc <> 0.
      APPEND |{ get_text( cs_text-no_authority ) }: { lv_tabname }| TO result-messages.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( lv_tabname ) ).
        lo_struct->get_ddic_field_list(
          RECEIVING
            p_field_list = lt_ddic
          EXCEPTIONS
            not_found    = 1
            no_ddic_type = 2
            OTHERS       = 3 ).
        IF sy-subrc <> 0.
          CLEAR lt_ddic.
        ENDIF.
      CATCH cx_root.
        CLEAR lt_ddic.
    ENDTRY.
    "the key without the client - ABAP SQL adds the client by itself
    LOOP AT lt_ddic INTO DATA(ls_ddic) WHERE keyflag = abap_true AND datatype <> `CLNT`.
      APPEND CONV string( ls_ddic-fieldname ) TO lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      APPEND |{ get_text( cs_text-read_only ) }: { lv_tabname }| TO result-messages.
      RETURN.
    ENDIF.

    lv_varkey = get_table_varkey( row        = row
                                  key_fields = lt_ddic ).
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = lv_tabname
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc = 1.
      APPEND |{ get_text( cs_text-locked ) } ({ sy-msgv1 })| TO result-messages.
      RETURN.
    ELSEIF sy-subrc <> 0.
      APPEND get_text( cs_text-locked ) TO result-messages.
      RETURN.
    ENDIF.

    TRY.
        "still what the user saw? A change made meanwhile is reported, not
        "overwritten - and a row deleted meanwhile is not created again
        IF operation <> `CREATE`.
          CREATE DATA lr_current TYPE (lv_tabname).
          ASSIGN lr_current->* TO <ls_current>.
          CREATE DATA lr_seen TYPE (lv_tabname).
          ASSIGN lr_seen->* TO <ls_seen>.
          IF operation = `UPDATE` AND original IS SUPPLIED.
            MOVE-CORRESPONDING original TO <ls_seen>.
          ELSE.
            MOVE-CORRESPONDING row TO <ls_seen>.
          ENDIF.
          ASSIGN row TO <ls_host>.
          DATA(lv_where) = build_key_condition( lt_keys ).
          SELECT SINGLE * FROM (lv_tabname)
            WHERE (lv_where)
            INTO @<ls_current>.
          IF sy-subrc <> 0.
            APPEND get_text( cs_text-changed ) TO result-messages.
          ELSE.
            "the client is the database's - not part of what was seen
            LOOP AT lt_ddic INTO ls_ddic WHERE datatype = `CLNT`.
              ASSIGN COMPONENT ls_ddic-fieldname OF STRUCTURE <ls_current> TO <lv_from>.
              ASSIGN COMPONENT ls_ddic-fieldname OF STRUCTURE <ls_seen> TO <lv_to>.
              IF <lv_from> IS ASSIGNED AND <lv_to> IS ASSIGNED.
                <lv_to> = <lv_from>.
              ENDIF.
              UNASSIGN: <lv_from>, <lv_to>.
            ENDLOOP.
            IF <ls_seen> <> <ls_current>.
              APPEND get_text( cs_text-changed ) TO result-messages.
            ENDIF.
          ENDIF.
        ENDIF.

        IF result-messages IS INITIAL.
          CASE operation.
            WHEN `CREATE`.
              INSERT (lv_tabname) FROM @row.
            WHEN `UPDATE`.
              UPDATE (lv_tabname) FROM @row.
            WHEN `DELETE`.
              DELETE (lv_tabname) FROM @row.
          ENDCASE.
          "committed here: after main( ) the core rolls back the LUW of every
          "non-sticky app, so an uncommitted write showed "saved" and was gone
          IF sy-subrc = 0.
            COMMIT WORK.
            result-success = abap_true.
          ELSE.
            APPEND |{ operation } failed (sy-subrc { sy-subrc })| TO result-messages.
            ROLLBACK WORK.                               "#EC CI_ROLLBACK
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
        APPEND lx->get_text( ) TO result-messages.
    ENDTRY.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = lv_tabname
        varkey       = lv_varkey.

  ENDMETHOD.


  METHOD get_table_varkey.

    DATA lv_buffer TYPE c LENGTH 120.
    DATA lv_offset TYPE i.
    FIELD-SYMBOLS <lv_value> TYPE any.

    LOOP AT key_fields INTO DATA(ls_field) WHERE keyflag = abap_true.
      DATA(lv_length) = CONV i( ls_field-leng ).
      "only character-like keys have an internal form that is their text
      IF ls_field-inttype NA `CNDT` OR lv_offset + lv_length > 120.
        RETURN.
      ENDIF.
      IF ls_field-datatype = `CLNT`.
        lv_buffer+lv_offset(lv_length) = sy-mandt.
      ELSE.
        ASSIGN COMPONENT ls_field-fieldname OF STRUCTURE row TO <lv_value>.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        lv_buffer+lv_offset(lv_length) = <lv_value>.
      ENDIF.
      lv_offset = lv_offset + lv_length.
    ENDLOOP.
    result = lv_buffer.

  ENDMETHOD.


  METHOD get_entity_capabilities.

    DATA(ls_entity) = get_capabilities( entity_name ).
    result = ls_entity.
    IF mo_ext IS NOT BOUND.
      RETURN.
    ENDIF.
    mo_ext->adjust_capabilities( EXPORTING floorplan   = mv_floorplan
                                           entity_name = to_upper( entity_name )
                                 CHANGING  caps        = result ).

    "the extension decides what is offered, not what the entity is: it may
    "withhold an operation of a business object and allow the writes of a
    "table, but it cannot give a business object an operation its BDEF
    "does not have, nor make a CDS view writable
    result-is_rap_bo = ls_entity-is_rap_bo.
    result-is_table = ls_entity-is_table.
    IF ls_entity-is_rap_bo = abap_true.
      result-can_create = xsdbool( result-can_create = abap_true AND ls_entity-can_create = abap_true ).
      result-can_update = xsdbool( result-can_update = abap_true AND ls_entity-can_update = abap_true ).
      result-can_delete = xsdbool( result-can_delete = abap_true AND ls_entity-can_delete = abap_true ).
    ELSEIF ls_entity-is_table = abap_false.
      CLEAR: result-can_create, result-can_update, result-can_delete.
    ENDIF.

  ENDMETHOD.


  METHOD build_key_condition.

    DATA lt_and TYPE string_table.
    LOOP AT names INTO DATA(lv_name).
      DATA(lv_field) = to_upper( lv_name ).
      APPEND |{ lv_field } = @{ cv_host }-{ lv_field }| TO lt_and.
    ENDLOOP.
    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD create_host.

    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.

    TRY.
        CREATE DATA result TYPE (entity_name).
      CATCH cx_root.
        CLEAR result.
        RETURN.
    ENDTRY.
    ASSIGN result->* TO <ls_host>.

    LOOP AT values INTO DATA(ls_value).
      DATA(lv_name) = to_upper( ls_value-name ).
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT lv_name OF STRUCTURE <ls_host> TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( <lv_value> )->type_kind.
      TRY.
          "a date or time as the JSON model writes it (2024-01-15), a RAW
          "as hex digits - a UUID may come with its dashes
          IF lv_kind = cl_abap_typedescr=>typekind_date
            OR lv_kind = cl_abap_typedescr=>typekind_time
            OR lv_kind = cl_abap_typedescr=>typekind_hex.
            <lv_value> = z2ui5_cl_rap_util=>normalize_value( ls_value-value ).
          ELSE.
            <lv_value> = ls_value-value.
          ENDIF.
        CATCH cx_root.
          CLEAR <lv_value>.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD run_action.

    DATA lv_cancel TYPE abap_bool.
    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.

    IF rows IS NOT BOUND.
      APPEND get_text( cs_text-no_selection ) TO result-messages.
      RETURN.
    ENDIF.
    ASSIGN rows->* TO <lt_rows>.
    IF <lt_rows> IS INITIAL.
      APPEND get_text( cs_text-no_selection ) TO result-messages.
      RETURN.
    ENDIF.

    IF mo_ext IS BOUND.
      mo_ext->before_save( EXPORTING entity_name = entity_name
                                     operation   = |ACTION:{ action }|
                                     data        = rows
                           CHANGING  messages    = result-messages
                                     cancel      = lv_cancel ).
      IF lv_cancel = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    IF eml_available( ) = abap_false OR get_entity_capabilities( entity_name )-is_rap_bo = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.

    result = z2ui5_cl_rap_eml=>execute_action( entity_name = entity_name
                                               action      = action
                                               rows        = <lt_rows>
                                               param       = param ).

    IF result-success = abap_true AND mo_ext IS BOUND.
      mo_ext->after_save( entity_name = entity_name
                          operation   = |ACTION:{ action }|
                          data        = rows ).
    ENDIF.

  ENDMETHOD.


  METHOD create_action_parameter.

    DATA lr_table TYPE REF TO data.
    FIELD-SYMBOLS <lt_table> TYPE STANDARD TABLE.

    IF eml_available( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_type) = |\\BDEF={ lv_entity }\\ENTITY={ lv_entity }\\ACTION={ to_upper( action ) }\\TYPE=IMPORTING|.
    TRY.
        CREATE DATA lr_table TYPE (lv_type).
        ASSIGN lr_table->* TO <lt_table>.
        APPEND INITIAL LINE TO <lt_table> ASSIGNING FIELD-SYMBOL(<ls_line>).
        ASSIGN COMPONENT `%PARAM` OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<ls_param>).
        IF sy-subrc = 0.
          CREATE DATA result LIKE <ls_param>.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD show_messages.

    IF messages IS INITIAL.
      RETURN.
    ENDIF.
    client->message_box_display( text = concat_lines_of( table = messages sep = cl_abap_char_utilities=>newline )
                                 type = type ).

  ENDMETHOD.


  METHOD normalize_key_value.
    result = z2ui5_cl_rap_util=>normalize_value( val ).
  ENDMETHOD.

ENDCLASS.
