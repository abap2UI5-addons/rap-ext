" The inbound parameters of z2ui5_cl_rap_start as the extension maps them
" (z2ui5_if_rap_ext~map_inbound_parameter) - no app is opened, no system
" is needed (added 2026-10, third round)
CLASS lcl_ext DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_rap_ext.
ENDCLASS.


CLASS lcl_ext IMPLEMENTATION.

  METHOD z2ui5_if_rap_ext~map_inbound_parameter.
    CASE to_upper( name ).
      WHEN `AGENCY`.
        name = `AGENCYID`.
      WHEN `SAP-IGNORED` OR `IGNORE`.
        CLEAR name.
      WHEN `STATUS`.
        value = to_upper( value ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.


CLASS lcl_start DEFINITION FINAL INHERITING FROM z2ui5_cl_rap_start.
  PUBLIC SECTION.
    DATA mo_ext TYPE REF TO z2ui5_if_rap_ext.

    METHODS map
      IMPORTING
        params        TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.

  PROTECTED SECTION.
    METHODS get_extension REDEFINITION.
ENDCLASS.


CLASS lcl_start IMPLEMENTATION.

  METHOD map.
    result = map_parameters( floorplan   = z2ui5_cl_rap_floorplan=>cs_floorplan-list_report
                             entity_name = `Z_TRAVEL`
                             params      = params ).
  ENDMETHOD.

  METHOD get_extension.
    result = mo_ext.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_start DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS without_extension FOR TESTING RAISING cx_static_check.
    METHODS mapped            FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_start IMPLEMENTATION.

  METHOD without_extension.
    DATA(lo_start) = NEW lcl_start( ).
    DATA(lt_params) = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `Agency` value = `1` ) ).
    cl_abap_unit_assert=>assert_equals( exp = lt_params
                                        act = lo_start->map( lt_params ) ).
  ENDMETHOD.

  METHOD mapped.
    DATA(lo_start) = NEW lcl_start( ).
    lo_start->mo_ext = NEW lcl_ext( ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `AGENCYID` value = `1` )
                                                            ( name = `Status`   value = `OPEN` ) )
      act = lo_start->map( VALUE #( ( name = `Agency` value = `1` )
                                    ( name = `ignore` value = `x` )
                                    ( name = `Status` value = `open` ) ) ) ).
  ENDMETHOD.

ENDCLASS.
