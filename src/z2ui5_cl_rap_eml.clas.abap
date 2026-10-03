"! The RAP write path of the floorplans: create, update, delete and actions
"! through dynamic EML (MODIFY ENTITIES OPERATIONS), committed with COMMIT
"! ENTITIES and answered with the messages of REPORTED and FAILED.
"!
"! Everything that depends on the entity is dynamic: the BDEF derived types
"! are created from their absolute names (\BDEF=...\ENTITY=...\TYPE=...), so
"! whether an operation exists is simply whether its type can be created -
"! a BDEF without `delete` has no TYPE=DELETE. The BDEF is the root entity's
"! name: the entity itself for a root, context-bdef for a child (since
"! 2026-10). A child is created by association under its parent
"! (context-parent, -association); a change of a child of a draft business
"! object edits and activates the ROOT, whose keys are context-root_keys.
"!
"! This is the only class of the addon that contains EML statements abaplint
"! can parse. They need a release with RAP; the floorplans ask
"! z2ui5_cl_rap_floorplan=>eml_available( ) first - which answers from RTTI
"! without loading this class - so a system that cannot activate it still
"! runs every floorplan read-only.
"!
"! A draft-enabled business object (its BDEF has the draft action Edit) is
"! written the way its own UI would: update = Edit (a draft of the active
"! instance), update the draft, Activate; create = create a draft, Activate
"! it. Everything runs before the one COMMIT ENTITIES, and a failed step
"! rolls the whole request back - no draft is left behind. The object page
"! edits across roundtrips instead: run_root_action (Edit, Activate,
"! Discard) and update_draft, each committed.
"!
"! Not verified in a system by an automated gate - see AGENTS.md.
CLASS z2ui5_cl_rap_eml DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_s_result TYPE z2ui5_cl_rap_floorplan=>ty_s_result.
    TYPES ty_s_context TYPE z2ui5_cl_rap_floorplan=>ty_s_rap_context.

    "! create one instance - fields with a value are sent. With
    "! context-association it is created by association under
    "! context-parent
    CLASS-METHODS create
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
        context       TYPE ty_s_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! update one instance - only the fields that differ from original
    CLASS-METHODS update
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
        original      TYPE data
        context       TYPE ty_s_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    CLASS-METHODS delete
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
        context       TYPE ty_s_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the business object has a draft (the draft action Edit exists) -
    "! entity_name is its root, the BDEF
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
        context       TYPE ty_s_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! run one action of the root of a business object on the instance of
    "! keys, committed - what the object page's draft editing needs: Edit,
    "! Activate, Discard. is_draft addresses the draft instance; preserve
    "! sets Edit's preserve_changes
    CLASS-METHODS run_root_action
      IMPORTING
        bdef          TYPE clike
        action        TYPE clike
        keys          TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value
        is_draft      TYPE abap_bool DEFAULT abap_false
        preserve      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! update the draft instance of row (only the fields that differ from
    "! original), committed - the draft keeps the change between roundtrips
    CLASS-METHODS update_draft
      IMPORTING
        entity_name   TYPE clike
        row           TYPE data
        original      TYPE data
        context       TYPE ty_s_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

  PRIVATE SECTION.

    "! one MODIFY ENTITIES OPERATIONS of a request. keys_from_mapped: the
    "! key fields of its instances are set from what the previous step
    "! MAPPED - the draft a create just made, for its Activate
    TYPES:
      BEGIN OF ty_s_step,
        ops              TYPE abp_behv_changes_tab,
        keys_from_mapped TYPE abap_bool,
        "the step that creates: its MAPPED keys are the result's keys
        is_create        TYPE abap_bool,
      END OF ty_s_step.

    "! the steps of one request - in order, before one COMMIT ENTITIES
    TYPES ty_t_steps TYPE STANDARD TABLE OF ty_s_step WITH DEFAULT KEY.

    CLASS-METHODS run_steps
      IMPORTING
        steps         TYPE ty_t_steps
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! an action table of the entity, one instance of row (or of keys,
    "! when given) - is_draft marks the draft instance
    CLASS-METHODS create_action_instances
      IMPORTING
        bdef          TYPE string
        entity_name   TYPE string
        action        TYPE string
        row           TYPE data
        keys          TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value OPTIONAL
        is_draft      TYPE abap_bool DEFAULT abap_false
        preserve      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

    "! the BDEF of an entity: context-bdef for a child, else the entity
    CLASS-METHODS get_bdef
      IMPORTING
        entity_name   TYPE string
        context       TYPE ty_s_context
      RETURNING
        VALUE(result) TYPE string.

    "! wrap the steps of a change of a draft business object: Edit the
    "! root before them, Activate it after them - one request, one commit.
    "! root_keys empty: the root is the row itself
    CLASS-METHODS wrap_in_root_draft
      IMPORTING
        bdef      TYPE string
        root_keys TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value
        row       TYPE data
      CHANGING
        steps     TYPE ty_t_steps
      RAISING
        cx_sy_create_data_error.

    CLASS-METHODS create_by_association
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
        context       TYPE ty_s_context
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the update instances of row - only the fields that differ from
    "! original are flagged in %control
    CLASS-METHODS create_update_instances
      IMPORTING
        bdef          TYPE string
        entity_name   TYPE string
        row           TYPE data
        original      TYPE data
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

    "! set the fields of keys in a structure
    CLASS-METHODS set_fields
      IMPORTING
        keys      TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value
      CHANGING
        structure TYPE data.

    "! set the key fields of every instance of every operation
    CLASS-METHODS set_keys
      IMPORTING
        instances TYPE abp_behv_changes_tab
        keys      TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.

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

    "! a derived type of the BDEF bdef (the entity itself when empty)
    CLASS-METHODS create_instances
      IMPORTING
        entity_name   TYPE string
        type_suffix   TYPE string
        bdef          TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

    "! the texts of the %msg of every response entry - into messages, and
    "! with severity and the %element fields into details
    CLASS-METHODS collect_messages
      IMPORTING
        responses TYPE ANY TABLE
      CHANGING
        messages  TYPE string_table
        details   TYPE z2ui5_cl_rap_floorplan=>ty_t_message.

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
    IF context-association IS NOT INITIAL.
      result = create_by_association( entity_name = lv_entity
                                      row         = row
                                      context     = context ).
      RETURN.
    ENDIF.

    DATA(lv_bdef) = get_bdef( entity_name = lv_entity
                              context     = context ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity
                                          bdef        = lv_bdef
                                          type_suffix = `\TYPE=CREATE` ).
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

    IF is_draft_enabled( lv_bdef ) = abap_false.
      result = run( entity_name = lv_entity
                    op          = if_abap_behv=>op-m-create
                    instances   = lr_inst ).
      RETURN.
    ENDIF.

    "draft: create the draft, then activate it by the key the create
    "MAPPED - not by %cid_ref, which a draft action's type may not carry
    set_draft( CHANGING instance = <ls_inst> ).
    TRY.
        DATA(lr_activate) = create_action_instances( bdef        = lv_bdef
                                                     entity_name = lv_entity
                                                     action      = `ACTIVATE`
                                                     row         = row
                                                     is_draft    = abap_true ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity }: no draft action Activate| ) ).
        RETURN.
    ENDTRY.
    result = run_steps( VALUE #(
      ( ops       = VALUE #( ( op = if_abap_behv=>op-m-create entity_name = lv_entity instances = lr_inst ) )
        is_create = abap_true )
      ( ops              = VALUE #( ( op          = if_abap_behv=>op-m-action
                                      entity_name = lv_entity
                                      sub_name    = `ACTIVATE`
                                      instances   = lr_activate ) )
        keys_from_mapped = abap_true ) ) ).

  ENDMETHOD.


  METHOD create_by_association.

    "TABLE FOR CREATE parent\_assoc: the parent's keys, and in %target the
    "new child - the composition fills the child's foreign key
    DATA(lv_bdef) = get_bdef( entity_name = entity_name
                              context     = context ).
    DATA(lv_parent) = to_upper( context-parent ).
    DATA(lv_assoc) = to_upper( context-association ).
    DATA(lv_draft) = is_draft_enabled( lv_bdef ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_target> TYPE STANDARD TABLE.

    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_parent
                                          bdef        = lv_bdef
                                          type_suffix = |\\ASSOCIATION={ lv_assoc }\\TYPE=CREATE| ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ entity_name } cannot be created under { lv_parent }| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    set_fields( EXPORTING keys      = context-parent_keys
                CHANGING  structure = <ls_inst> ).
    IF lv_draft = abap_true.
      set_draft( CHANGING instance = <ls_inst> ).
    ENDIF.

    ASSIGN COMPONENT `%TARGET` OF STRUCTURE <ls_inst> TO <lt_target>.
    IF sy-subrc <> 0.
      result-messages = VALUE #( ( |{ entity_name } cannot be created under { lv_parent }| ) ).
      RETURN.
    ENDIF.
    APPEND INITIAL LINE TO <lt_target> ASSIGNING FIELD-SYMBOL(<ls_target>).
    MOVE-CORRESPONDING row TO <ls_target>.
    ASSIGN COMPONENT `%CID` OF STRUCTURE <ls_target> TO FIELD-SYMBOL(<lv_cid>).
    IF sy-subrc = 0.
      <lv_cid> = `Z2UI5_CREATE_1`.
    ENDIF.
    set_control( EXPORTING row      = row
                           mode     = `NOT_INITIAL`
                 CHANGING  instance = <ls_target> ).
    "the fields that point at the parent are the composition's to fill -
    "sent, they would be a write of read-only fields
    LOOP AT context-parent_fields INTO DATA(lv_parent_field).
      ASSIGN COMPONENT `%CONTROL` OF STRUCTURE <ls_target> TO FIELD-SYMBOL(<ls_control>).
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      ASSIGN COMPONENT lv_parent_field OF STRUCTURE <ls_control> TO FIELD-SYMBOL(<lv_flag>).
      IF sy-subrc = 0.
        <lv_flag> = if_abap_behv=>mk-off.
      ENDIF.
    ENDLOOP.
    IF lv_draft = abap_true.
      set_draft( CHANGING instance = <ls_target> ).
    ENDIF.

    DATA(lt_steps) = VALUE ty_t_steps(
      ( ops       = VALUE #( ( op          = if_abap_behv=>op-m-create_ba
                               entity_name = lv_parent
                               sub_name    = lv_assoc
                               instances   = lr_inst ) )
        is_create = abap_true ) ).
    IF lv_draft = abap_true.
      TRY.
          wrap_in_root_draft( EXPORTING bdef      = lv_bdef
                                        root_keys = context-root_keys
                                        row       = row
                              CHANGING  steps     = lt_steps ).
        CATCH cx_sy_create_data_error.
          result-messages = VALUE #( ( |{ lv_bdef }: no draft actions Edit and Activate| ) ).
          RETURN.
      ENDTRY.
    ENDIF.
    result = run_steps( lt_steps ).

  ENDMETHOD.


  METHOD update.

    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_bdef) = get_bdef( entity_name = lv_entity
                              context     = context ).
    TRY.
        DATA(lr_inst) = create_update_instances( bdef        = lv_bdef
                                                 entity_name = lv_entity
                                                 row         = row
                                                 original    = original ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be changed| ) ).
        RETURN.
    ENDTRY.

    IF is_draft_enabled( lv_bdef ) = abap_false.
      result = run( entity_name = lv_entity
                    op          = if_abap_behv=>op-m-update
                    instances   = lr_inst ).
      RETURN.
    ENDIF.

    "draft: Edit the root (a draft appears), change the draft, Activate
    "the root - an active instance of a draft BO is not changed directly
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    ASSIGN lr_inst->* TO <lt_inst>.
    LOOP AT <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
      set_draft( CHANGING instance = <ls_inst> ).
    ENDLOOP.
    DATA(lt_steps) = VALUE ty_t_steps(
      ( ops = VALUE #( ( op = if_abap_behv=>op-m-update entity_name = lv_entity instances = lr_inst ) ) ) ).
    TRY.
        wrap_in_root_draft( EXPORTING bdef      = lv_bdef
                                      root_keys = context-root_keys
                                      row       = row
                            CHANGING  steps     = lt_steps ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_bdef }: no draft actions Edit and Activate| ) ).
        RETURN.
    ENDTRY.
    result = run_steps( lt_steps ).

  ENDMETHOD.


  METHOD update_draft.

    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_bdef) = get_bdef( entity_name = lv_entity
                              context     = context ).
    TRY.
        DATA(lr_inst) = create_update_instances( bdef        = lv_bdef
                                                 entity_name = lv_entity
                                                 row         = row
                                                 original    = original ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be changed| ) ).
        RETURN.
    ENDTRY.
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    ASSIGN lr_inst->* TO <lt_inst>.
    LOOP AT <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
      set_draft( CHANGING instance = <ls_inst> ).
    ENDLOOP.
    result = run( entity_name = lv_entity
                  op          = if_abap_behv=>op-m-update
                  instances   = lr_inst ).

  ENDMETHOD.


  METHOD create_update_instances.

    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    result = create_instances( entity_name = entity_name
                               bdef        = bdef
                               type_suffix = `\TYPE=UPDATE` ).
    ASSIGN result->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    MOVE-CORRESPONDING row TO <ls_inst>.
    set_control( EXPORTING row      = row
                           original = original
                           mode     = `CHANGED`
                 CHANGING  instance = <ls_inst> ).

  ENDMETHOD.


  METHOD delete.

    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_bdef) = get_bdef( entity_name = lv_entity
                              context     = context ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity
                                          bdef        = lv_bdef
                                          type_suffix = `\TYPE=DELETE` ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_entity } cannot be deleted| ) ).
        RETURN.
    ENDTRY.
    ASSIGN lr_inst->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    MOVE-CORRESPONDING row TO <ls_inst>.

    "the root of a draft business object is deleted as the active instance
    "(its draft goes with it); a child of one is deleted in the root's draft
    IF lv_bdef = lv_entity OR is_draft_enabled( lv_bdef ) = abap_false.
      result = run( entity_name = lv_entity
                    op          = if_abap_behv=>op-m-delete
                    instances   = lr_inst ).
      RETURN.
    ENDIF.

    set_draft( CHANGING instance = <ls_inst> ).
    DATA(lt_steps) = VALUE ty_t_steps(
      ( ops = VALUE #( ( op = if_abap_behv=>op-m-delete entity_name = lv_entity instances = lr_inst ) ) ) ).
    TRY.
        wrap_in_root_draft( EXPORTING bdef      = lv_bdef
                                      root_keys = context-root_keys
                                      row       = row
                            CHANGING  steps     = lt_steps ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |{ lv_bdef }: no draft actions Edit and Activate| ) ).
        RETURN.
    ENDTRY.
    result = run_steps( lt_steps ).

  ENDMETHOD.


  METHOD execute_action.

    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_action) = to_upper( action ).
    DATA(lv_bdef) = get_bdef( entity_name = lv_entity
                              context     = context ).
    FIELD-SYMBOLS <lt_inst> TYPE STANDARD TABLE.
    TRY.
        DATA(lr_inst) = create_instances( entity_name = lv_entity
                                          bdef        = lv_bdef
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


  METHOD run_root_action.

    DATA(lv_bdef) = to_upper( bdef ).
    DATA(lv_action) = to_upper( action ).
    "the instance is the keys alone - there is no row to take them from
    DATA lv_row TYPE abap_bool.
    IF keys IS INITIAL.
      result-messages = VALUE #( ( |Action { lv_action } of { lv_bdef }: the instance's key is unknown| ) ).
      RETURN.
    ENDIF.
    TRY.
        DATA(lr_inst) = create_action_instances( bdef        = lv_bdef
                                                 entity_name = lv_bdef
                                                 action      = lv_action
                                                 row         = lv_row
                                                 keys        = keys
                                                 is_draft    = is_draft
                                                 preserve    = preserve ).
      CATCH cx_sy_create_data_error.
        result-messages = VALUE #( ( |Action { lv_action } of { lv_bdef } is not available| ) ).
        RETURN.
    ENDTRY.
    result = run( entity_name = lv_bdef
                  op          = if_abap_behv=>op-m-action
                  sub_name    = lv_action
                  instances   = lr_inst ).

  ENDMETHOD.


  METHOD get_bdef.
    result = COND #( WHEN context-bdef IS NOT INITIAL THEN to_upper( context-bdef ) ELSE entity_name ).
  ENDMETHOD.


  METHOD wrap_in_root_draft.

    DATA(lr_edit) = create_action_instances( bdef        = bdef
                                             entity_name = bdef
                                             action      = `EDIT`
                                             row         = row
                                             keys        = root_keys ).
    DATA(lr_activate) = create_action_instances( bdef        = bdef
                                                 entity_name = bdef
                                                 action      = `ACTIVATE`
                                                 row         = row
                                                 keys        = root_keys
                                                 is_draft    = abap_true ).
    INSERT VALUE #( ops = VALUE #( ( op          = if_abap_behv=>op-m-action
                                     entity_name = bdef
                                     sub_name    = `EDIT`
                                     instances   = lr_edit ) ) ) INTO steps INDEX 1.
    APPEND VALUE #( ops = VALUE #( ( op          = if_abap_behv=>op-m-action
                                     entity_name = bdef
                                     sub_name    = `ACTIVATE`
                                     instances   = lr_activate ) ) ) TO steps.

  ENDMETHOD.


  METHOD create_instances.
    DATA(lv_bdef) = COND string( WHEN bdef IS NOT INITIAL THEN bdef ELSE entity_name ).
    DATA(lv_type) = |\\BDEF={ lv_bdef }\\ENTITY={ entity_name }{ type_suffix }|.
    CREATE DATA result TYPE (lv_type).
  ENDMETHOD.


  METHOD run.

    DATA lt_op TYPE abp_behv_changes_tab.
    APPEND VALUE #( op          = op
                    entity_name = entity_name
                    sub_name    = sub_name
                    instances   = instances ) TO lt_op.
    result = run_steps( VALUE #( ( ops       = lt_op
                                   is_create = xsdbool( op = if_abap_behv=>op-m-create ) ) ) ).

  ENDMETHOD.


  METHOD run_steps.

    DATA lt_commit_failed TYPE abp_behv_response_tab.
    DATA lt_commit_reported TYPE abp_behv_response_tab.

    TRY.
        DATA lt_previous_keys TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.
        LOOP AT steps INTO DATA(ls_step).
          DATA(lt_op) = ls_step-ops.
          IF ls_step-keys_from_mapped = abap_true.
            IF lt_previous_keys IS INITIAL.
              APPEND `The new instance's key is unknown` TO result-messages.
              ROLLBACK ENTITIES.
              RETURN.
            ENDIF.
            set_keys( instances = lt_op
                      keys      = lt_previous_keys ).
          ENDIF.
          MODIFY ENTITIES OPERATIONS lt_op
            MAPPED DATA(lt_mapped)
            FAILED DATA(lt_failed)
            REPORTED DATA(lt_reported).

          collect_messages( EXPORTING responses = lt_reported
                            CHANGING  messages  = result-messages
                                      details   = result-details ).

          "an unevaluated failure poisons the whole LUW - evaluate it, and
          "roll back before anything else runs
          IF lt_failed IS NOT INITIAL.
            collect_messages( EXPORTING responses = lt_failed
                              CHANGING  messages  = result-messages
                                        details   = result-details ).
            ROLLBACK ENTITIES.
            IF result-messages IS INITIAL.
              APPEND `The operation was rejected` TO result-messages.
            ENDIF.
            RETURN.
          ENDIF.

          lt_previous_keys = get_mapped_keys( lt_mapped ).
          IF ls_step-is_create = abap_true.
            result-keys = lt_previous_keys.
          ENDIF.
        ENDLOOP.

        COMMIT ENTITIES RESPONSES FAILED lt_commit_failed REPORTED lt_commit_reported.
        IF sy-subrc <> 0.
          collect_messages( EXPORTING responses = lt_commit_reported
                            CHANGING  messages  = result-messages
                                      details   = result-details ).
          collect_messages( EXPORTING responses = lt_commit_failed
                            CHANGING  messages  = result-messages
                                      details   = result-details ).
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
                               bdef        = bdef
                               type_suffix = |\\ACTION={ action }\\TYPE=IMPORTING| ).
    ASSIGN result->* TO <lt_inst>.
    APPEND INITIAL LINE TO <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
    IF keys IS NOT INITIAL.
      set_fields( EXPORTING keys      = keys
                  CHANGING  structure = <ls_inst> ).
    ELSE.
      MOVE-CORRESPONDING row TO <ls_inst>.
    ENDIF.
    IF is_draft = abap_true.
      set_draft( CHANGING instance = <ls_inst> ).
    ENDIF.
    "Edit keeps an existing draft instead of discarding it - with it, a
    "draft of the same user (or a lock of another) is an error message,
    "never lost work
    IF action = `EDIT`.
      ASSIGN COMPONENT `%PARAM` OF STRUCTURE <ls_inst> TO FIELD-SYMBOL(<ls_param>).
      IF sy-subrc = 0.
        ASSIGN COMPONENT `PRESERVE_CHANGES` OF STRUCTURE <ls_param> TO FIELD-SYMBOL(<lv_preserve>).
        IF sy-subrc = 0.
          <lv_preserve> = preserve.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD set_fields.

    FIELD-SYMBOLS <lv_field> TYPE any.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_name) = to_upper( ls_key-name ).
      UNASSIGN <lv_field>.
      ASSIGN COMPONENT lv_name OF STRUCTURE structure TO <lv_field>.
      IF <lv_field> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( <lv_field> )->type_kind.
      TRY.
          "a date as 2024-01-15, a UUID with its dashes - in their internal form
          IF lv_kind = cl_abap_typedescr=>typekind_date
            OR lv_kind = cl_abap_typedescr=>typekind_time
            OR lv_kind = cl_abap_typedescr=>typekind_hex.
            <lv_field> = z2ui5_cl_rap_util=>normalize_value( ls_key-value ).
          ELSE.
            <lv_field> = ls_key-value.
          ENDIF.
        CATCH cx_root.
          CLEAR <lv_field>.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_keys.

    FIELD-SYMBOLS <lt_inst> TYPE ANY TABLE.

    LOOP AT instances INTO DATA(ls_op).
      IF ls_op-instances IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN ls_op-instances->* TO <lt_inst>.
      LOOP AT <lt_inst> ASSIGNING FIELD-SYMBOL(<ls_inst>).
        set_fields( EXPORTING keys      = keys
                    CHANGING  structure = <ls_inst> ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_draft.
    ASSIGN COMPONENT `%IS_DRAFT` OF STRUCTURE instance TO FIELD-SYMBOL(<lv_is_draft>).
    IF sy-subrc = 0.
      <lv_is_draft> = if_abap_behv=>mk-on.
    ENDIF.
  ENDMETHOD.


  METHOD collect_messages.

    "a response row names its entity and points at the entries of it; the
    "entries carry %msg, and %element flags the fields a message is about.
    "Read generically - every data reference in the row is followed,
    "whatever the component is called
    FIELD-SYMBOLS <lr_entries> TYPE any.
    FIELD-SYMBOLS <lt_entries> TYPE ANY TABLE.
    FIELD-SYMBOLS <lo_msg> TYPE any.
    FIELD-SYMBOLS <ls_element> TYPE any.
    FIELD-SYMBOLS <lv_flag> TYPE any.
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
              DATA(lo_message) = CAST if_message( <lo_msg> ).
              DATA(lv_text) = lo_message->get_text( ).
              IF lv_text IS INITIAL OR line_exists( messages[ table_line = lv_text ] ).
                CONTINUE.
              ENDIF.
              APPEND lv_text TO messages.

              DATA(ls_detail) = VALUE z2ui5_cl_rap_floorplan=>ty_s_message( text = lv_text type = `error` ).
              TRY.
                  ls_detail-type = SWITCH #( CAST if_abap_behv_message( <lo_msg> )->m_severity
                    WHEN if_abap_behv_message=>severity-warning     THEN `warning`
                    WHEN if_abap_behv_message=>severity-success     THEN `success`
                    WHEN if_abap_behv_message=>severity-information THEN `information`
                    WHEN if_abap_behv_message=>severity-none        THEN `information`
                    ELSE `error` ).
                CATCH cx_root ##NO_HANDLER.
              ENDTRY.
              UNASSIGN <ls_element>.
              ASSIGN COMPONENT `%ELEMENT` OF STRUCTURE <ls_entry> TO <ls_element>.
              IF <ls_element> IS ASSIGNED.
                DATA(lo_element) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <ls_element> ) ).
                LOOP AT lo_element->components INTO DATA(ls_comp).
                  ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_element> TO <lv_flag>.
                  IF sy-subrc = 0 AND <lv_flag> = if_abap_behv=>mk-on.
                    APPEND CONV string( ls_comp-name ) TO ls_detail-fields.
                  ENDIF.
                ENDLOOP.
              ENDIF.
              APPEND ls_detail TO details.
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
