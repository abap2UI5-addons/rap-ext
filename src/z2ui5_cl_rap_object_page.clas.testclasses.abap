" The steps of the object page that decide its sections and how a child of
" the record is read and written - on metadata and a record set by hand. No
" row is read: these run transpiled in CI (npm run unit) as well as in a
" system.
CLASS ltcl_object_page DEFINITION DEFERRED.
CLASS z2ui5_cl_rap_object_page DEFINITION LOCAL FRIENDS ltcl_object_page.

CLASS ltcl_object_page DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_travel,
        travelid   TYPE c LENGTH 8,
        traveluuid TYPE c LENGTH 32,
        status     TYPE c LENGTH 1,
      END OF ty_s_travel.

    DATA mo_cut TYPE REF TO z2ui5_cl_rap_object_page.

    METHODS setup.

    "a #LINEITEM_REFERENCE section of the association _BOOKING
    METHODS booking_child
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_object_page=>ty_s_child.

    METHODS sections_from_facets       FOR TESTING RAISING cx_static_check.
    METHODS child_filter_by_condition  FOR TESTING RAISING cx_static_check.
    METHODS child_filter_by_keys       FOR TESTING RAISING cx_static_check.
    METHODS child_context_composition  FOR TESTING RAISING cx_static_check.
    METHODS child_context_association  FOR TESTING RAISING cx_static_check.
    METHODS child_context_of_a_child   FOR TESTING RAISING cx_static_check.
    METHODS own_keys                   FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_object_page IMPLEMENTATION.

  METHOD setup.

    mo_cut = NEW #( val = VALUE ty_s_travel( travelid   = '00000042'
                                             traveluuid = 'ABC123'
                                             status     = 'O' ) ).
    mo_cut->mv_entity_name = `Z_TRAVEL`.
    mo_cut->ms_caps-is_rap_bo = abap_true.
    mo_cut->ms_entity = VALUE #(
      name   = `Z_TRAVEL`
      keys   = VALUE #( ( `TRAVELID` ) )
      fields = VALUE #( ( name = `TRAVELID`   label = `Travel` is_key = abap_true )
                        ( name = `TRAVELUUID` label = `UUID`   is_hidden = abap_true )
                        ( name = `STATUS`     label = `Status`
                          field_groups = VALUE #( ( qualifier = `Basic` position = 10 ) ) ) )
      facets = VALUE #( ( id = `C1` type = `#COLLECTION` label = `General` position = 10 )
                        ( id = `F1` parent_id = `C1` type = `#FIELDGROUP_REFERENCE` target_qualifier = `Basic`
                          label = `Basic data` position = 20 )
                        ( id = `B1` type = `#LINEITEM_REFERENCE` target_element = `_BOOKING`
                          label = `Bookings` position = 30 )
                        "a table without an association has nothing to show
                        ( id = `X1` type = `#LINEITEM_REFERENCE` label = `Nothing` position = 40 ) )
      associations = VALUE #( ( name = `_BOOKING` target = `Z_BOOKING` is_composition = abap_true
                                conditions = VALUE #( ( local = `TRAVELUUID` target = `PARENTUUID` ) ) )
                              ( name = `_AGENCY` target = `Z_AGENCY`
                                conditions = VALUE #( ( local = `STATUS` target = `AGENCYSTATUS` ) ) ) ) ).

  ENDMETHOD.


  METHOD booking_child.
    result = VALUE #( section_id  = `B1`
                      component   = `SECTION_1`
                      association = `_BOOKING`
                      entity      = VALUE #( name   = `Z_BOOKING`
                                             keys   = VALUE #( ( `BOOKINGID` ) )
                                             fields = VALUE #( ( name = `BOOKINGID` )
                                                               ( name = `PARENTUUID` )
                                                               ( name = `TRAVELID` ) ) ) ).
  ENDMETHOD.


  METHOD sections_from_facets.

    DATA(lt_sections) = mo_cut->get_sections( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_sections )
                                        exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_sections[ 1 ]-type
                                        exp = `COLLECTION` ).
    "the field group sits in the collection
    cl_abap_unit_assert=>assert_equals( act = lt_sections[ 2 ]-type
                                        exp = `FIELDGROUP` ).
    cl_abap_unit_assert=>assert_equals( act = lt_sections[ 2 ]-parent_id
                                        exp = `C1` ).
    cl_abap_unit_assert=>assert_equals( act = lt_sections[ 3 ]-association
                                        exp = `_BOOKING` ).

  ENDMETHOD.


  METHOD child_filter_by_condition.

    "the ON condition: the child's PARENTUUID is this record's TRAVELUUID
    mo_cut->get_child_filter( EXPORTING is_child  = booking_child( )
                              IMPORTING et_values = DATA(lt_values) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_values
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `PARENTUUID` value = `ABC123` ) ) ).

  ENDMETHOD.


  METHOD child_filter_by_keys.

    "no condition known: the keys of this record under the same names
    CLEAR mo_cut->ms_entity-associations.
    mo_cut->get_child_filter( EXPORTING is_child  = booking_child( )
                              IMPORTING et_values = DATA(lt_values) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_values
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `TRAVELID` value = `00000042` ) ) ).

  ENDMETHOD.


  METHOD child_context_composition.

    "a child of the root: written through the root's BDEF, created under it
    DATA(ls_context) = mo_cut->get_child_context( `_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = ls_context-bdef
                                        exp = `Z_TRAVEL` ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_context-root_keys
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `TRAVELID` value = `00000042` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_context-parent
                                        exp = `Z_TRAVEL` ).
    cl_abap_unit_assert=>assert_equals( act = ls_context-association
                                        exp = `_BOOKING` ).
    "the composition fills the field that points at the parent
    cl_abap_unit_assert=>assert_equals( act = ls_context-parent_fields
                                        exp = VALUE string_table( ( `PARENTUUID` ) ) ).

  ENDMETHOD.


  METHOD child_context_association.

    "an association that is no composition leads to an entity of its own
    cl_abap_unit_assert=>assert_initial( mo_cut->get_child_context( `_AGENCY` ) ).

  ENDMETHOD.


  METHOD child_context_of_a_child.

    "a record that is a child itself passes its root on, not itself
    mo_cut->ms_context = VALUE #( bdef      = `Z_ROOT`
                                  root_keys = VALUE #( ( name = `ROOTID` value = `7` ) ) ).
    DATA(ls_context) = mo_cut->get_child_context( `_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = ls_context-bdef
                                        exp = `Z_ROOT` ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_context-root_keys
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `ROOTID` value = `7` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_context-parent
                                        exp = `Z_TRAVEL` ).

  ENDMETHOD.


  METHOD own_keys.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->get_own_keys( )
      exp = VALUE z2ui5_cl_rap_floorplan=>ty_t_name_value( ( name = `TRAVELID` value = `00000042` ) ) ).
  ENDMETHOD.

ENDCLASS.
