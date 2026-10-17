"! GET PERMISSIONS in its dynamic form - this one statement and nothing
"! else. abaplint parses only the static forms, so this file is in
"! global.noIssues of abaplint.jsonc and no gate reads it; its syntax is
"! written from the ABAP keyword documentation and NOT verified in a system
"! (docs/system-test.md, 1). z2ui5_cl_rap_eml calls it dynamically
"! (cs_dynamic-permissions) inside a TRY: where it does not activate, the
"! floorplans only lose feature control.
CLASS z2ui5_cl_rap_eml_perm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! the permissions of every line of operations: ENTITY_NAME, INSTANCES
    "! (TABLE FOR PERMISSIONS KEY), REQUEST (STRUCTURE FOR PERMISSIONS
    "! REQUEST), RESULTS (STRUCTURE FOR PERMISSIONS RESULT) - global,
    "! instance and static
    CLASS-METHODS get
      CHANGING
        operations TYPE abp_behv_permissions_tab
        failed     TYPE abp_behv_response_tab
        reported   TYPE abp_behv_response_tab.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_rap_eml_perm IMPLEMENTATION.

  METHOD get.
    GET PERMISSIONS OPERATIONS operations
      FAILED failed
      REPORTED reported.
  ENDMETHOD.

ENDCLASS.
