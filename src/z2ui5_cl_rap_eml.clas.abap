"! The RAP write path of the floorplans: create, update, delete and actions
"! through dynamic EML (MODIFY ENTITIES OPERATIONS), committed with COMMIT
"! ENTITIES and answered with the messages of REPORTED and FAILED.
"!
"! Everything that depends on the entity is dynamic: the BDEF derived types
"! are created from their absolute names (\BDEF=...\ENTITY=...\TYPE=...), so
"! whether an operation exists is simply whether its type can be created -
"! a BDEF without `delete` has no TYPE=DELETE. The BDEF name is taken to be
"! the entity name, which holds for the root entity of a business object
"! (and for the root of a projection); child entities are not written here.
"!
"! This is the only class of the addon that contains EML statements. They
"! need a release with RAP; the floorplans ask
"! z2ui5_cl_rap_floorplan=>eml_available( ) first - which answers from RTTI
"! without loading this class - so a system that cannot activate it still
"! runs every floorplan read-only.
"!
"! A draft-enabled business object (its BDEF has the draft action Edit) is
"! written the way its own UI would: update = Edit (a draft of the active
"! instance), update the draft, Activate; create = create a draft, Activate
"! it. Everything runs before the one COMMIT ENTITIES, and a failed step
"! rolls the whole request back - no draft is left behind.
"!
"! Not verified in a system by an automated gate - see AGENTS.md.
CLASS z2ui5_cl_rap_eml DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_s_result TYPE z2ui5_cl_rap_floorplan=>ty_s_result.

    "! create one instance - fields with a value are sent
    CLASS-METHODS create
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! update one instance - only the fields that differ from original
    CLASS-METHODS update
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
        original      TYPE data
      RETURNING
        VALUE(result) TYPE ty_s_result.

    CLASS-METHODS delete
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the business object has a draft (the draft action Edit exists)
    CLASS-METHODS is_draft_enabled
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! execute an action for every row of rows (a table of the entity);
    "! param is the action's parameter structure, if it has one
    CLASS-METHODS execute_action
      IMPORTING
        entity_name   TYPE clike
        action        TYPE clike
        rows          TYPE ANY TABLE
        param         TYPE REF TO data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

  PRIVATE SECTION.

    "! the operation tables of one request, each run as its own MODIFY
    "! ENTITIES OPERATIONS - in order, before one COMMIT ENTITIES
    TYPES ty_t_steps TYPE STANDARD TABLE OF abp_behv_changes_tab WITH DEFAULT KEY.

    CLASS-METHODS run_steps
      IMPORTING
        steps         TYPE ty_t_steps
        read_keys     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! an action table of the entity, one instance of row - is_draft marks
    "! the draft instance, cid_ref refers to an instance of the same request
    CLASS-METHODS create_action_instances
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
        row           TYPE data
        is_draft      TYPE abap_bool DEFAULT abap_false
        cid_ref       TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

    CLASS-METHODS set_draft
      CHANGING
        instance TYPE data.

    CLASS-METHODS run
      IMPORTING
        entity_name   TYPE string
        op            TYPE clike
        sub_name      TYPE string OPTIONAL
        instances     TYPE REF TO data
      RETURNING
        VALUE(result) TYPE ty_s_result.

    CLASS-METHODS create_instances
      IMPORTING
        entity_name   TYPE string
        type_suffix   TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

    CLASS-METHODS collect_messages
      IMPORTING
        responses TYPE ANY TABLE
      CHANGING
        messages  TYPE string_table.

    "! the key fields of the first mapped instance - the key a business
    "! object with early numbering assigned on create
    CLASS-METHODS get_mapped_keys
      IMPORTING
        mapped        TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.

    CLASS-METHODS set_control
      IMPORTING
        row      TYPE data
        original TYPE data OPTIONAL
        mode     TYPE string
      CHANGING
        instance TYPE data.

ENDCLASS.



CLASS z2ui5_cl_rap_eml IMPLEMENTATION.

  METHOD create.

    DATA(lv_entity) = to_upper( entity_name ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity type_suffix = `\TYPE=CREATE` ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be created| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    MOVE-CORRESPONDING row TO <ls_inst>.
    ASSIGN COMPONENT `%CID` OF STRUCTURE <ls_inst> TO FIELD-SYMBOL(<lv_cid>).
    IF sy-subrc = 0.
      <lv_cid> = `Z2UI5_CREATE_1`.
    ENDIF.
    set_control( EXPORTING row      = row
                           mode     = `NOT_INITIAL`
                 CHANGING  instance = <ls_inst> ).

    IF is_draft_enabled( lv_entity ) = abap_false.
      result = run( entity_name = lv_entity
                    op          = if_abap_behv=>op-m-create
                    instances   = lr_inst ).
      RETURN.
    ENDIF.

    "draft: create the draft and activate it - in ONE statement, since the
    "activation refers to the new instance by its %cid
    set_draft( CHANGING instance = <ls_inst> ).
    TRY.
        DATA(lr_activate) = create_action_instances( entity_name = lv_entity
                                                     action      = `ACTIVATE`
                                                     row         = row
                                                     is_draft    = abap_true
                                                     cid_ref     = `Z2UI5_CREATE_1` ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity }: no draft action Activate| ) ).
        RETURN.
    ENDTRY.
    result = run_steps( read_keys = abap_true
                        steps     = VALUE #( ( VALUE #( ( op          = if_abap_behv=>op-m-create
                                                          entity_name = lv_entity
                                                          instances   = lr_inst )
                                                        ( op          = if_abap_behv=>op-m-action
                                                          entity_name = lv_entity
                                                          sub_name    = `ACTIVATE`
                                                          instances   = lr_activate ) ) ) ) ).

  ENDMETHOD.


  METHOD update.

    DATA(lv_entity) = to_upper( entity_name ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity type_suffix = `\TYPE=UPDATE` ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be changed| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    MOVE-CORRESPONDING row TO <ls_inst>.
    set_control( EXPORTING row      = row
                           original = original
                           mode     = `CHANGED`
                 CHANGING  instance = <ls_inst> ).

    IF is_draft_enabled( lv_entity ) = abap_false.
      result = run( entity_name = lv_entity
                    op          = if_abap_behv=>op-m-update
                    instances   = lr_inst ).
      RETURN.
    ENDIF.

    "draft: Edit the active instance (a draft appears), change the draft,
    "Activate it - an active instance of a draft BO is not changed directly
    set_draft( CHANGING instance = <ls_inst> ).
    TRY.
        DATA(lr_edit) = create_action_instances( entity_name = lv_entity
                                                 action      = `EDIT`
                                                 row         = row ).
        DATA(lr_activate) = create_action_instances( entity_name = lv_entity
                                                     action      = `ACTIVATE`
                                                     row         = row
                                                     is_draft    = abap_true ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity }: no draft actions Edit and Activate| ) ).
        RETURN.
    ENDTRY.
    result = run_steps( VALUE #(
      ( VALUE #( ( op = if_abap_behv=>op-m-action entity_name = lv_entity sub_name = `EDIT`     instances = lr_edit ) ) )
      ( VALUE #( ( op = if_abap_behv=>op-m-update entity_name = lv_entity                       instances = lr_inst ) ) )
      ( VALUE #( ( op = if_abap_behv=>op-m-action entity_name = lv_entity sub_name = `ACTIVATE` instances = lr_activate ) ) ) ) ).

  ENDMETHOD.


  METHOD delete.

    DATA(lv_entity) = to_upper( entity_name ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity type_suffix = `\TYPE=DELETE` ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be deleted| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    MOVE-CORRESPONDING row TO <ls_inst>.

    result = run( entity_name = lv_entity
                  op          = if_abap_behv=>op-m-delete
                  instances   = lr_inst ).

  ENDMETHOD.


  METHOD execute_action.

    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_action) = to_upper( action ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity
                                          type_suffix = |\\ACTION={ lv_action }\\TYPE=IMPORTING| ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |Action { lv_action } of { lv_entity } is not available| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.

    LOOP AT rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
      MOVE-CORRESPONDING <ls_row> TO <ls_inst>.
      IF param IS BOUND.
        ASSIGN COMPONENT `%PARAM` OF STRUCTURE <ls_inst> TO FIELD-SYMBOL(<ls_param>).
        IF sy-subrc = 0.
          ASSIGN param->* TO FIELD-SYMBOL(<ls_param_value>).
          MOVE-CORRESPONDING <ls_param_value> TO <ls_param>.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF <lt_inst> IS INITIAL.
      result-messages = VALUE #( ( `Select at least one row` ) ).
      RETURN.
    ENDIF.

    result = run( entity_name = lv_entity
                  op          = if_abap_behv=>op-m-action
                  sub_name    = lv_action
                  instances   = lr_inst ).

  ENDMETHOD.


  METHOD create_instances.
    DATA(lv_type) = |\\BDEF={ entity_name }\\ENTITY={ entity_name }{ type_suffix }|.
    CREATE DATA result TYPE (lv_type).
  ENDMETHOD.


  METHOD run.

    DATA lt_op TYPE abp_behv_changes_tab.
    APPEND VALUE #( op          = op
                    entity_name = entity_name
                    sub_name    = sub_name
                    instances   = instances ) TO lt_op.
    result = run_steps( steps     = VALUE #( ( lt_op ) )
                        read_keys = xsdbool( op = if_abap_behv=>op-m-create ) ).

  ENDMETHOD.


  METHOD run_steps.

    DATA lt_commit_failed TYPE abp_behv_response_tab.
    DATA lt_commit_reported TYPE abp_behv_response_tab.

    TRY.
        LOOP AT steps INTO DATA(lt_op).
          DATA(lv_step) = sy-tabix.
          MODIFY ENTITIES OPERATIONS lt_op
            MAPPED DATA(lt_mapped)
            FAILED DATA(lt_failed)
            REPORTED DATA(lt_reported).

          collect_messages( EXPORTING responses = lt_reported
                            CHANGING  messages  = result-messages ).

          "an unevaluated failure poisons the whole LUW - evaluate it, and
          "roll back before anything else runs
          IF lt_failed IS NOT INITIAL.
            collect_messages( EXPORTING responses = lt_failed
                              CHANGING  messages  = result-messages ).
            ROLLBACK ENTITIES.
            IF result-messages IS INITIAL.
              APPEND `The operation was rejected` TO result-messages.
            ENDIF.
            RETURN.
          ENDIF.

          IF read_keys = abap_true AND lv_step = 1.
            result-keys = get_mapped_keys( lt_mapped ).
          ENDIF.
        ENDLOOP.

        COMMIT ENTITIES RESPONSES FAILED lt_commit_failed REPORTED lt_commit_reported.
        IF sy-subrc <> 0.
          collect_messages( EXPORTING responses = lt_commit_reported
                            CHANGING  messages  = result-messages ).
          collect_messages( EXPORTING responses = lt_commit_failed
                            CHANGING  messages  = result-messages ).
          ROLLBACK ENTITIES.
          CLEAR result-keys.
          IF result-messages IS INITIAL.
            APPEND `Saving was rejected` TO result-messages.
          ENDIF.
          RETURN.
        ENDIF.

        result-success = abap_true.

      CATCH cx_root INTO DATA(lx).
        ROLLBACK ENTITIES.
        CLEAR result-keys.
        APPEND lx->get_text( ) TO result-messages.
    ENDTRY.

  ENDMETHOD.


  METHOD is_draft_enabled.
    DATA(lv_entity) = to_upper( entity_name ).
    TRY.
        DATA(lr_edit) = create_instances( entity_name = lv_entity
                                          type_suffix = `\ACTION=EDIT\TYPE=IMPORTING` ).
        result = xsdbool( lr_edit IS BOUND ).
      CATCH cx_sy_create_data_error.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD create_action_instances.

    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.

    result = create_instances( entity_name = entity_name
                               type_suffix = |\\ACTION={ action }\\TYPE=IMPORTING| ).
    ASSIGN result->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    IF cid_ref IS NOT INITIAL.
      ASSIGN COMPONENT `%CID_REF` OF STRUCTURE <ls_inst> TO FIELD-SYMBOL(<lv_cid_ref>).
      IF sy-subrc = 0.
        <lv_cid_ref> = cid_ref.
      ENDIF.
    ELSE.
      MOVE-CORRESPONDING row TO <ls_inst>.
    ENDIF.
    IF is_draft = abap_true.
      set_draft( CHANGING instance = <ls_inst> ).
    ENDIF.

  ENDMETHOD.


  METHOD set_draft.
    ASSIGN COMPONENT `%IS_DRAFT` OF STRUCTURE instance TO FIELD-SYMBOL(<lv_is_draft>).
    IF sy-subrc = 0.
      <lv_is_draft> = if_abap_behv=>mk-on.
    ENDIF.
  ENDMETHOD.


  METHOD collect_messages.

    "a response row names its entity and points at the entries of it; the
    "entries carry %msg. Read generically - every data reference in the
    "row is followed, whatever the component is called
    FIELD-SYMBOLS <lr_entries> TYPE any.
    FIELD-SYMBOLS <lt_entries> TYPE ANY TABLE.
    FIELD-SYMBOLS <lo_msg> TYPE any.
    DATA lr_ref TYPE REF TO data.

    LOOP AT responses ASSIGNING FIELD-SYMBOL(<ls_response>).
      DO.
        ASSIGN COMPONENT sy-index OF STRUCTURE <ls_response> TO <lr_entries>.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        IF cl_abap_typedescr=>describe_by_data( <lr_entries> )->type_kind <> cl_abap_typedescr=>typekind_dref.
          CONTINUE.
        ENDIF.
        lr_ref = <lr_entries>.
        IF lr_ref IS NOT BOUND.
          CONTINUE.
        ENDIF.
        ASSIGN lr_ref->* TO <lt_entries>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        LOOP AT <lt_entries> ASSIGNING FIELD-SYMBOL(<ls_entry>).
          ASSIGN COMPONENT `%MSG` OF STRUCTURE <ls_entry> TO <lo_msg>.
          IF sy-subrc <> 0 OR <lo_msg> IS INITIAL.
            CONTINUE.
          ENDIF.
          TRY.
              DATA(lv_text) = CAST if_message( <lo_msg> )->get_text( ).
              IF lv_text IS NOT INITIAL AND NOT line_exists( messages[ table_line = lv_text ] ).
                APPEND lv_text TO messages.
              ENDIF.
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
        ENDLOOP.
      ENDDO.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_mapped_keys.

    FIELD-SYMBOLS <lr_entries> TYPE any.
    FIELD-SYMBOLS <lt_entries> TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lr_ref TYPE REF TO data.

    LOOP AT mapped ASSIGNING FIELD-SYMBOL(<ls_response>).
      DO.
        ASSIGN COMPONENT sy-index OF STRUCTURE <ls_response> TO <lr_entries>.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        IF cl_abap_typedescr=>describe_by_data( <lr_entries> )->type_kind <> cl_abap_typedescr=>typekind_dref.
          CONTINUE.
        ENDIF.
        lr_ref = <lr_entries>.
        IF lr_ref IS NOT BOUND.
          CONTINUE.
        ENDIF.
        ASSIGN lr_ref->* TO <lt_entries>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        LOOP AT <lt_entries> ASSIGNING FIELD-SYMBOL(<ls_entry>).
          "the flat components - %cid, %pid, %key, %tky are RAP's own
          DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <ls_entry> ) ).
          LOOP AT lo_struct->components INTO DATA(ls_comp).
            IF ls_comp-name(1) = `%`.
              CONTINUE.
            ENDIF.
            ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_entry> TO <lv_value>.
            IF sy-subrc = 0 AND <lv_value> IS NOT INITIAL.
              APPEND VALUE #( name = ls_comp-name value = |{ <lv_value> }| ) TO result.
            ENDIF.
          ENDLOOP.
          RETURN.
        ENDLOOP.
      ENDDO.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_control.

    "%control flags the fields the operation carries: on create every field
    "with a value, on update every field whose value changed - sending the
    "unchanged ones would ask RAP to write read-only fields
    FIELD-SYMBOLS <ls_control> TYPE any.
    FIELD-SYMBOLS <lv_flag> TYPE any.
    FIELD-SYMBOLS <lv_new> TYPE any.
    FIELD-SYMBOLS <lv_old> TYPE any.

    ASSIGN COMPONENT `%CONTROL` OF STRUCTURE instance TO <ls_control>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_control) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <ls_control> ) ).
    LOOP AT lo_control->components INTO DATA(ls_comp).
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_control> TO <lv_flag>.
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE row TO <lv_new>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF mode = `CHANGED`.
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE original TO <lv_old>.
        IF sy-subrc = 0 AND <lv_old> = <lv_new>.
          CONTINUE.
        ENDIF.
      ELSEIF <lv_new> IS INITIAL.
        CONTINUE.
      ENDIF.
      <lv_flag> = if_abap_behv=>mk-on.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
