"! READ ENTITIES in its dynamic form - this one statement and nothing else.
"! abaplint parses only the static forms, so this file is in
"! global.noIssues of abaplint.jsonc and no gate reads it; its syntax is
"! written from the ABAP keyword documentation and NOT verified in a system
"! (docs/system-test.md, 1). z2ui5_cl_rap_eml calls it dynamically
"! (cs_dynamic-read) inside a TRY: where it does not activate, the
"! floorplans only lose reading a draft back.
CLASS z2ui5_cl_rap_eml_read DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! read every line of operations: OP (IF_ABAP_BEHV=>OP-R-READ),
    "! ENTITY_NAME, INSTANCES (TABLE FOR READ IMPORT), RESULTS (TABLE FOR
    "! READ RESULT)
    CLASS-METHODS read
      CHANGING
        operations TYPE abp_behv_retrievals_tab
        failed     TYPE abp_behv_response_tab
        reported   TYPE abp_behv_response_tab.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_rap_eml_read IMPLEMENTATION.

  METHOD read.
    READ ENTITIES OPERATIONS operations
      FAILED failed
      REPORTED reported.
  ENDMETHOD.

ENDCLASS.
