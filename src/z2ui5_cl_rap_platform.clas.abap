"! Everything rap-ext reads or calls that ABAP Cloud does not release, in
"! one class - this is the CLOUD version. It stands in for
"! src/z2ui5_cl_rap_platform.clas.abap (the on-premise version, on main)
"! on the branch cloud, which scripts/cloud.mjs builds from main: the same
"! public section, and nothing on-premise behind it. What rap-ext does in
"! ABAP Cloud instead - the XCO reader z2ui5_cl_rap_anno_xco for the
"! annotations, associations, labels, key flags and fixed values, a
"! database table read-only - is decided in z2ui5_cl_rap_util and the
"! floorplans by get_environment( ) (README "ABAP Cloud").
"!
"! The ABAP Cloud syntax check reports an unreleased object even where it
"! is only named by a literal in a dynamic statement: name none here.
"! A change to the public section is made in both files.
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

ENDCLASS.


CLASS z2ui5_cl_rap_platform IMPLEMENTATION.


  METHOD get_environment.
    result = z2ui5_cl_rap_util=>cs_environment-cloud.
  ENDMETHOD.


  METHOD read_annos_effective.
    "no annotation service - the XCO reader reads them
    RAISE EXCEPTION NEW cx_sy_dyn_call_illegal_method( ).
  ENDMETHOD.


  METHOD read_annos_direct.
    CLEAR result.
  ENDMETHOD.


  METHOD get_ddic_fields.
    "no DDIC field list - the XCO reader delivers key flags and labels
    CLEAR result.
  ENDMETHOD.


  METHOD read_fixed_values.
    "the XCO reader reads them (z2ui5_cl_rap_util=>read_fixed_values)
    CLEAR result.
  ENDMETHOD.


  METHOD read_ddl_source.
    "the XCO reader writes the declarations as DDL
    CLEAR result.
  ENDMETHOD.


  METHOD is_transparent_table.
    "a database table is read-only in ABAP Cloud
    result = abap_false.
  ENDMETHOD.


  METHOD check_table_authority.
    result = abap_false.
  ENDMETHOD.


  METHOD enqueue_table.
    result-subrc = 3.
  ENDMETHOD.


  METHOD dequeue_table ##NEEDED.
  ENDMETHOD.

ENDCLASS.
