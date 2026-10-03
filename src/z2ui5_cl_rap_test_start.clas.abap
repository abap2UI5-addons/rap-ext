"! The deep links of the demo: opens the demo's entities from a URL, e.g.
"!   ...?app_start=z2ui5_cl_rap_test_start&amp;floorplan=OBJECT_PAGE&amp;entity=I_COUNTRY&amp;Country=DE
"! - and nothing else, which is the point of a z2ui5_cl_rap_start subclass.
CLASS z2ui5_cl_rap_test_start DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_start
  FINAL
  CREATE PUBLIC.

  PROTECTED SECTION.
    METHODS get_allowed_entities REDEFINITION.

ENDCLASS.



CLASS z2ui5_cl_rap_test_start IMPLEMENTATION.

  METHOD get_allowed_entities.
    result = VALUE #( ( `I_COUNTRY` )
                      ( `I_CURRENCY` )
                      ( `/DMO/C_TRAVEL_PROCESSOR_M` )
                      ( `/DMO/C_TRAVEL_A_D` ) ).
  ENDMETHOD.

ENDCLASS.
