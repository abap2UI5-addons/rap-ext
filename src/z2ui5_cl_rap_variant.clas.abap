"! The views a user saved of a list report or worklist: the filter values,
"! the search, the sort order and the hidden columns, by name, one of them
"! the default. Kept in table z2ui5_t_rap_var per user and entity.
"!
"! Since 2026-10 (third round) a view also keeps the filter fields, the
"! order and width of the columns and the group field, it can be public
"! (every user sees it, only its owner changes or deletes it) and it can
"! apply automatically (the list is read as soon as it is chosen) - two
"! columns of the table, IS_PUBLIC and AUTO_APPLY. A system whose table
"! has them not yet keeps the private views as before.
"!
"! The table is named dynamically: a system where it did not arrive still
"! activates every class, and is_available( ) answers abap_false there -
"! the floorplans then offer no views.
CLASS z2ui5_cl_rap_variant DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_data,
        filters        TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value,
        search         TYPE string,
        sort_field     TYPE string,
        sort_desc      TYPE abap_bool,
        hidden_columns TYPE string_table,
        "added 2026-10, third round: the fields of the filter bar (adapt
        "filters), the columns' order and widths, the group field
        filter_fields  TYPE string_table,
        column_order   TYPE string_table,
        column_widths  TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value,
        group_field    TYPE string,
      END OF ty_s_data.

    TYPES:
      BEGIN OF ty_s_variant,
        name       TYPE string,
        is_default TYPE abap_bool,
        data       TYPE ty_s_data,
        "added 2026-10, third round: every user sees it, it is read as
        "soon as it is chosen, and whose it is (empty: the user's own)
        is_public  TYPE abap_bool,
        auto_apply TYPE abap_bool,
        owner      TYPE string,
      END OF ty_s_variant.

    TYPES ty_t_variant TYPE STANDARD TABLE OF ty_s_variant WITH EMPTY KEY.

    CONSTANTS cv_table TYPE string VALUE `Z2UI5_T_RAP_VAR`.

    "! the table is there
    CLASS-METHODS is_available
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the table has the columns of public and automatically applied views
    "! (added 2026-10, third round)
    CLASS-METHODS has_public_views
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the views of the user for entity_name, by name - and since 2026-10
    "! (third round) the public views of the other users, their owner set
    CLASS-METHODS read_all
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_variant.

    "! save a view of the user (a view of the same name is replaced); the
    "! default view is the only default - committed
    CLASS-METHODS save
      IMPORTING
        entity_name   TYPE clike
        variant       TYPE ty_s_variant
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! delete a view of the user - committed
    CLASS-METHODS delete
      IMPORTING
        entity_name   TYPE clike
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.

    "! the user's own rows of entity_name - the condition every statement
    "! uses (host variables of the method that runs it)
    CONSTANTS cv_owner_where TYPE string VALUE `UNAME = @LV_UNAME AND ENTITY = @LV_ENTITY`.
    "! the user's own rows and the public ones of the others
    CONSTANTS cv_visible_where TYPE string
      VALUE `ENTITY = @LV_ENTITY AND ( UNAME = @LV_UNAME OR IS_PUBLIC = 'X' )`.

ENDCLASS.



CLASS z2ui5_cl_rap_variant IMPLEMENTATION.

  METHOD is_available.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = cv_table
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD has_public_views.

    TRY.
        DATA(lo_table) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( cv_table ) ).
        result = xsdbool( line_exists( lo_table->components[ name = `IS_PUBLIC` ] )
                      AND line_exists( lo_table->components[ name = `AUTO_APPLY` ] ) ).
      CATCH cx_root.
        result = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD read_all.

    DATA lr_rows TYPE REF TO data.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_value> TYPE any.

    IF is_available( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_uname) = sy-uname.
    DATA(lv_entity) = to_upper( entity_name ).

    TRY.
        CREATE DATA lr_rows TYPE STANDARD TABLE OF (cv_table).
        ASSIGN lr_rows->* TO <lt_rows>.
        DATA(lv_where) = COND string( WHEN has_public_views( ) = abap_true THEN cv_visible_where
                                      ELSE cv_owner_where ).
        SELECT * FROM (cv_table)
          WHERE (lv_where)
          ORDER BY PRIMARY KEY
          INTO TABLE @<lt_rows>.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_variant) = VALUE ty_s_variant( ).
      ASSIGN COMPONENT `NAME` OF STRUCTURE <ls_row> TO <lv_value>.
      ls_variant-name = <lv_value>.
      ASSIGN COMPONENT `IS_DEFAULT` OF STRUCTURE <ls_row> TO <lv_value>.
      ls_variant-is_default = <lv_value>.
      ASSIGN COMPONENT `UNAME` OF STRUCTURE <ls_row> TO <lv_value>.
      IF <lv_value> <> lv_uname.
        ls_variant-owner = <lv_value>.
        "another user's default is not this user's
        CLEAR ls_variant-is_default.
      ENDIF.
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT `IS_PUBLIC` OF STRUCTURE <ls_row> TO <lv_value>.
      IF <lv_value> IS ASSIGNED.
        ls_variant-is_public = <lv_value>.
      ENDIF.
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT `AUTO_APPLY` OF STRUCTURE <ls_row> TO <lv_value>.
      IF <lv_value> IS ASSIGNED.
        ls_variant-auto_apply = <lv_value>.
      ELSE.
        "a table without the column: every view applies, as before
        ls_variant-auto_apply = abap_true.
      ENDIF.
      ASSIGN COMPONENT `DATA` OF STRUCTURE <ls_row> TO <lv_value>.
      DATA(lv_xml) = CONV string( <lv_value> ).
      TRY.
          CALL TRANSFORMATION id SOURCE XML lv_xml RESULT data = ls_variant-data.
        CATCH cx_root.
          "a view saved by another release of this class - left out
          CONTINUE.
      ENDTRY.
      APPEND ls_variant TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD save.

    DATA lr_row TYPE REF TO data.
    DATA lv_xml TYPE string.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.

    IF is_available( ) = abap_false OR variant-name IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_uname) = sy-uname.
    DATA(lv_entity) = to_upper( entity_name ).

    TRY.
        CALL TRANSFORMATION id SOURCE data = variant-data RESULT XML lv_xml.

        CREATE DATA lr_row TYPE (cv_table).
        ASSIGN lr_row->* TO <ls_row>.
        ASSIGN COMPONENT `UNAME` OF STRUCTURE <ls_row> TO <lv_value>.
        <lv_value> = lv_uname.
        ASSIGN COMPONENT `ENTITY` OF STRUCTURE <ls_row> TO <lv_value>.
        <lv_value> = lv_entity.
        ASSIGN COMPONENT `NAME` OF STRUCTURE <ls_row> TO <lv_value>.
        <lv_value> = variant-name.
        ASSIGN COMPONENT `IS_DEFAULT` OF STRUCTURE <ls_row> TO <lv_value>.
        <lv_value> = variant-is_default.
        ASSIGN COMPONENT `DATA` OF STRUCTURE <ls_row> TO <lv_value>.
        <lv_value> = lv_xml.
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT `IS_PUBLIC` OF STRUCTURE <ls_row> TO <lv_value>.
        IF <lv_value> IS ASSIGNED.
          <lv_value> = variant-is_public.
        ENDIF.
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT `AUTO_APPLY` OF STRUCTURE <ls_row> TO <lv_value>.
        IF <lv_value> IS ASSIGNED.
          <lv_value> = variant-auto_apply.
        ENDIF.

        "one default per user and entity
        IF variant-is_default = abap_true.
          DATA(lv_set) = `IS_DEFAULT = ' '`.
          UPDATE (cv_table) SET (lv_set) WHERE (cv_owner_where).
        ENDIF.
        MODIFY (cv_table) FROM @<ls_row>.
        IF sy-subrc = 0.
          COMMIT WORK.
          result = abap_true.
        ELSE.
          ROLLBACK WORK.                                 "#EC CI_ROLLBACK
        ENDIF.
      CATCH cx_root.
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
    ENDTRY.

  ENDMETHOD.


  METHOD delete.

    IF is_available( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_uname) = sy-uname.
    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_name) = CONV string( name ).
    DATA(lv_where) = |{ cv_owner_where } AND NAME = @LV_NAME|.

    TRY.
        DELETE FROM (cv_table) WHERE (lv_where).
        IF sy-subrc = 0.
          COMMIT WORK.
          result = abap_true.
        ENDIF.
      CATCH cx_root.
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
