"! Everything rap-ext reads or calls that ABAP Cloud does not release, in
"! one class: the annotation service CL_DD_DDL_ANNOTATION_SERVICE, the
"! dictionary (GET_DDIC_FIELD_LIST / DDFIELDS, GET_DDIC_FIXED_VALUES /
"! DDFIXVALUES, DD02L, DDDDLSRC, DDLDEPENDENCY) and the maintenance path of
"! a database table (S_TABU_NAM, ENQUEUE_E_TABLE, DEQUEUE_E_TABLE).
"!
"! This is the ON-PREMISE version, on main. The branch cloud is built from
"! main with cloud/z2ui5_cl_rap_platform.clas.abap in place of this file:
"! the same public section, nothing on-premise behind it
"! (scripts/cloud.mjs, README "ABAP Cloud"). The ABAP Cloud syntax check
"! reports an unreleased object even where it is only named by a literal
"! in a dynamic statement - so no other class may name one, and a change
"! to the public section is made in both files (npm run lint:cloud
"! compiles the other classes against the cloud version).
CLASS z2ui5_cl_rap_platform DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES:
      "! the answer of enqueue_table: subrc 0 locked, 1 locked by someone
      "! else (user), anything else an error
      BEGIN OF ty_s_enqueue,
        subrc TYPE i,
        user  TYPE string,
      END OF ty_s_enqueue.

    "! z2ui5_cl_rap_util=&gt;cs_environment-on_premise here, -cloud in the
    "! cloud version
    CLASS-METHODS get_environment
      RETURNING
        VALUE(result) TYPE string.

    "! the annotations of an entity, metadata extensions included -
    "! CL_DD_DDL_ANNOTATION_SERVICE=&gt;GET_ANNOS; raises when it cannot be
    "! called
    CLASS-METHODS read_annos_effective
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_raw_annotations
      RAISING
        cx_root.

    "! the annotations written in the entity itself and its elements -
    "! GET_DIRECT_ANNOS_4_ENTITY and _4_ELEMENT
    CLASS-METHODS read_annos_direct
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_raw_annotations.

    "! the dictionary fields of a structure (key flags, types, data element
    "! texts) - GET_DDIC_FIELD_LIST; empty for a type that is not a DDIC type
    CLASS-METHODS get_ddic_fields
      IMPORTING
        io_struct     TYPE REF TO cl_abap_structdescr
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_ddic_field.

    "! the fixed values of the domain of a data element - GET_DDIC_FIXED_VALUES;
    "! an interval is left out
    CLASS-METHODS read_fixed_values
      IMPORTING
        io_elem       TYPE REF TO cl_abap_elemdescr
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_name_value.

    "! the DDL source of an entity (DDDDLSRC, through DDLDEPENDENCY when the
    "! source has another name) - empty when there is none
    CLASS-METHODS read_ddl_source
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! abap_true for an active transparent table (DD02L)
    CLASS-METHODS is_transparent_table
      IMPORTING
        tabname       TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! may the user change the table - S_TABU_NAM, what SM30 and SE16 ask
    CLASS-METHODS check_table_authority
      IMPORTING
        tabname       TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! lock one row of a table - ENQUEUE_E_TABLE
    CLASS-METHODS enqueue_table
      IMPORTING
        tabname       TYPE clike
        varkey        TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_enqueue.

    "! release the lock of enqueue_table - DEQUEUE_E_TABLE
    CLASS-METHODS dequeue_table
      IMPORTING
        tabname TYPE clike
        varkey  TYPE clike.

  PRIVATE SECTION.

    "! the service is called dynamically with the parameter types read from
    "! RTTI - its signature has not been checked in a system, and a dynamic
    "! call only loses the annotations where a static one would keep the
    "! class from activating
    CONSTANTS cv_service TYPE string VALUE `CL_DD_DDL_ANNOTATION_SERVICE`.

    "! one parameter of a method of the annotation service, typed as RTTI
    "! describes it
    CLASS-METHODS create_service_param
      IMPORTING
        io_class      TYPE REF TO cl_abap_objectdescr
        method        TYPE string
        param         TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_root.

    "! the rows of a table of the annotation service (ANNONAME, VALUE)
    CLASS-METHODS annos_from_service
      IMPORTING
        it_annos      TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_annotation.

ENDCLASS.


CLASS z2ui5_cl_rap_platform IMPLEMENTATION.


  METHOD get_environment.
    result = z2ui5_cl_rap_util=>cs_environment-on_premise.
  ENDMETHOD.


  METHOD read_annos_effective.

    "GET_ANNOS( entityname, metadata_extension, IMPORTING entity_annos,
    "element_annos )
    DATA lr_entity TYPE REF TO data.
    DATA lr_element TYPE REF TO data.
    DATA lv_mde TYPE abap_bool VALUE abap_true.
    FIELD-SYMBOLS <lt_annos> TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_any> TYPE any.
    FIELD-SYMBOLS <lv_entity> TYPE any.

    CONSTANTS lc_method TYPE string VALUE `GET_ANNOS`.

    DATA(lo_class) = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_name( cv_service ) ).
    DATA(lr_entity_name) = create_service_param( io_class = lo_class
                                                 method   = lc_method
                                                 param    = `ENTITYNAME` ).
    ASSIGN lr_entity_name->* TO <lv_entity>.
    <lv_entity> = entity_name.

    lr_entity = create_service_param( io_class = lo_class
                                      method   = lc_method
                                      param    = `ENTITY_ANNOS` ).
    lr_element = create_service_param( io_class = lo_class
                                       method   = lc_method
                                       param    = `ELEMENT_ANNOS` ).

    DATA(lt_param) = VALUE abap_parmbind_tab(
      ( name  = `ENTITYNAME`
        kind  = cl_abap_objectdescr=>exporting
        value = lr_entity_name )
      ( name  = `METADATA_EXTENSION`
        kind  = cl_abap_objectdescr=>exporting
        value = REF #( lv_mde ) )
      ( name  = `ENTITY_ANNOS`
        kind  = cl_abap_objectdescr=>importing
        value = lr_entity )
      ( name  = `ELEMENT_ANNOS`
        kind  = cl_abap_objectdescr=>importing
        value = lr_element ) ).

    CALL METHOD (cv_service)=>(lc_method)
      PARAMETER-TABLE lt_param.

    ASSIGN lr_entity->* TO <lt_annos>.
    result-entity = annos_from_service( <lt_annos> ).

    ASSIGN lr_element->* TO <lt_annos>.
    LOOP AT <lt_annos> ASSIGNING FIELD-SYMBOL(<ls_anno>).
      DATA(ls_el_anno) = VALUE z2ui5_cl_rap_util=>ty_s_element_annotation( ).
      ASSIGN COMPONENT `ELEMENTNAME` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_el_anno-element = <lv_any>.
      ASSIGN COMPONENT `ANNONAME` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_el_anno-key = <lv_any>.
      ASSIGN COMPONENT `VALUE` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc = 0.
        ls_el_anno-value = <lv_any>.
      ENDIF.
      APPEND ls_el_anno TO result-elements.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_annos_direct.

    FIELD-SYMBOLS <lv_entity> TYPE any.
    FIELD-SYMBOLS <lv_element> TYPE any.
    FIELD-SYMBOLS <lt_annos> TYPE ANY TABLE.

    DATA lo_class TYPE REF TO cl_abap_objectdescr.
    TRY.
        lo_class = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_name( cv_service ) ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    TRY.
        DATA(lr_entity) = create_service_param( io_class = lo_class
                                                method   = `GET_DIRECT_ANNOS_4_ENTITY`
                                                param    = `ENTITYNAME` ).
        ASSIGN lr_entity->* TO <lv_entity>.
        <lv_entity> = entity_name.
        DATA(lr_annos) = create_service_param( io_class = lo_class
                                               method   = `GET_DIRECT_ANNOS_4_ENTITY`
                                               param    = `ANNOS` ).
        ASSIGN lr_annos->* TO <lt_annos>.
        DATA(lt_param) = VALUE abap_parmbind_tab(
          ( name = `ENTITYNAME` kind = cl_abap_objectdescr=>exporting value = lr_entity )
          ( name = `ANNOS`      kind = cl_abap_objectdescr=>importing value = lr_annos ) ).
        CALL METHOD (cv_service)=>(`GET_DIRECT_ANNOS_4_ENTITY`)
          PARAMETER-TABLE lt_param.
        result-entity = annos_from_service( <lt_annos> ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        lr_entity = create_service_param( io_class = lo_class
                                          method   = `GET_DIRECT_ANNOS_4_ELEMENT`
                                          param    = `ENTITYNAME` ).
        ASSIGN lr_entity->* TO <lv_entity>.
        <lv_entity> = entity_name.
        DATA(lr_element) = create_service_param( io_class = lo_class
                                                 method   = `GET_DIRECT_ANNOS_4_ELEMENT`
                                                 param    = `ELEMENTNAME` ).
        ASSIGN lr_element->* TO <lv_element>.
        lr_annos = create_service_param( io_class = lo_class
                                         method   = `GET_DIRECT_ANNOS_4_ELEMENT`
                                         param    = `ANNOS` ).
        ASSIGN lr_annos->* TO <lt_annos>.
        lt_param = VALUE abap_parmbind_tab(
          ( name = `ENTITYNAME`  kind = cl_abap_objectdescr=>exporting value = lr_entity )
          ( name = `ELEMENTNAME` kind = cl_abap_objectdescr=>exporting value = lr_element )
          ( name = `ANNOS`       kind = cl_abap_objectdescr=>importing value = lr_annos ) ).
        LOOP AT lo_descr->get_components( ) INTO DATA(ls_comp).
          <lv_element> = ls_comp-name.
          CLEAR <lt_annos>.
          CALL METHOD (cv_service)=>(`GET_DIRECT_ANNOS_4_ELEMENT`)
            PARAMETER-TABLE lt_param.
          LOOP AT annos_from_service( <lt_annos> ) INTO DATA(ls_anno).
            APPEND VALUE z2ui5_cl_rap_util=>ty_s_element_annotation( element = ls_comp-name
                                                                     key     = ls_anno-key
                                                                     value   = ls_anno-value ) TO result-elements.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD create_service_param.

    DATA lo_type TYPE REF TO cl_abap_datadescr.
    io_class->get_method_parameter_type(
      EXPORTING
        p_method_name       = method
        p_parameter_name    = param
      RECEIVING
        p_descr_ref         = lo_type
      EXCEPTIONS
        parameter_not_found = 1
        method_not_found    = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW cx_sy_dyn_call_param_not_found( ).
    ENDIF.
    CREATE DATA result TYPE HANDLE lo_type.

  ENDMETHOD.


  METHOD annos_from_service.

    FIELD-SYMBOLS <lv_any> TYPE any.
    LOOP AT it_annos ASSIGNING FIELD-SYMBOL(<ls_anno>).
      DATA(ls_annotation) = VALUE z2ui5_cl_rap_util=>ty_s_annotation( ).
      ASSIGN COMPONENT `ANNONAME` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_annotation-key = <lv_any>.
      ASSIGN COMPONENT `VALUE` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc = 0.
        ls_annotation-value = <lv_any>.
      ENDIF.
      APPEND ls_annotation TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_ddic_fields.

    DATA lt_list TYPE ddfields.
    TRY.
        IF io_struct->is_ddic_type( ) = abap_false.
          RETURN.
        ENDIF.
        io_struct->get_ddic_field_list(
          RECEIVING
            p_field_list = lt_list
          EXCEPTIONS
            not_found    = 1
            no_ddic_type = 2
            OTHERS       = 3 ).
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_list INTO DATA(ls_dfies).
      APPEND VALUE #( fieldname = ls_dfies-fieldname
                      keyflag   = ls_dfies-keyflag
                      datatype  = ls_dfies-datatype
                      inttype   = ls_dfies-inttype
                      leng      = ls_dfies-leng
                      scrtext_m = ls_dfies-scrtext_m
                      fieldtext = ls_dfies-fieldtext ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_fixed_values.

    DATA lt_values TYPE ddfixvalues.
    TRY.
        io_elem->get_ddic_fixed_values(
          EXPORTING
            p_langu        = sy-langu
          RECEIVING
            p_fixed_values = lt_values
          EXCEPTIONS
            not_found      = 1
            no_ddic_type   = 2
            OTHERS         = 3 ).
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    "an interval of the domain is no entry of a list
    LOOP AT lt_values INTO DATA(ls_value) WHERE high IS INITIAL.
      APPEND VALUE #( name  = condense( |{ ls_value-low }| )
                      value = condense( |{ ls_value-ddtext }| ) ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_ddl_source.

    DATA lv_ddlname TYPE string.

    SELECT SINGLE source FROM ddddlsrc
      WHERE ddlname = @entity_name
        AND as4local = 'A'
      INTO @result.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    "an entity whose DDL source has another name
    SELECT SINGLE ddlname FROM ddldependency
      WHERE objectname = @entity_name
        AND state = 'A'
      INTO @lv_ddlname.
    IF sy-subrc <> 0 OR lv_ddlname = entity_name.
      RETURN.
    ENDIF.
    SELECT SINGLE source FROM ddddlsrc
      WHERE ddlname = @lv_ddlname
        AND as4local = 'A'
      INTO @result.

  ENDMETHOD.


  METHOD is_transparent_table.

    DATA lv_tabname TYPE c LENGTH 30.
    DATA lv_tabclass TYPE c LENGTH 8.
    lv_tabname = to_upper( tabname ).
    SELECT SINGLE tabclass FROM dd02l
      WHERE tabname = @lv_tabname
        AND as4local = 'A'
      INTO @lv_tabclass.
    result = xsdbool( sy-subrc = 0 AND lv_tabclass = `TRANSP` ).

  ENDMETHOD.


  METHOD check_table_authority.

    DATA lv_tabname TYPE c LENGTH 30.
    lv_tabname = to_upper( tabname ).
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD lv_tabname.
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD enqueue_table.

    DATA lv_tabname TYPE c LENGTH 30.
    DATA lv_varkey TYPE c LENGTH 120.
    lv_tabname = to_upper( tabname ).
    lv_varkey = varkey.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = lv_tabname
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    result-subrc = sy-subrc.
    IF sy-subrc = 1.
      result-user = sy-msgv1.
    ENDIF.

  ENDMETHOD.


  METHOD dequeue_table.

    DATA lv_tabname TYPE c LENGTH 30.
    DATA lv_varkey TYPE c LENGTH 120.
    lv_tabname = to_upper( tabname ).
    lv_varkey = varkey.
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = lv_tabname
        varkey       = lv_varkey.

  ENDMETHOD.

ENDCLASS.
