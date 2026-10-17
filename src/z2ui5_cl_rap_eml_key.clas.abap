"! CONVERT KEY - the final key of an instance created with late
"! numbering, which exists only while the save runs: COMMIT ENTITIES BEGIN,
"! CONVERT KEY, COMMIT ENTITIES END, and nothing else. abaplint parses
"! none of it, so this file is in global.noIssues of abaplint.jsonc and no
"! gate reads it; its syntax is written from the ABAP keyword documentation
"! and NOT verified in a system (docs/system-test.md, 1).
"! z2ui5_cl_rap_eml calls it dynamically (cs_dynamic-convert_key) inside a
"! TRY: where it does not activate, the commit runs without the key and a
"! created record is found by its administrative fields, as before.
CLASS z2ui5_cl_rap_eml_key DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! commit the open RAP transaction; when it succeeds (subrc 0), key
    "! (the %KEY of the entity) is the final key of the instance whose
    "! preliminary key is pid
    CLASS-METHODS commit
      IMPORTING
        entity_name TYPE abp_entity_name
        pid         TYPE abp_behv_pid
      CHANGING
        key         TYPE data
        failed      TYPE abp_behv_response_tab
        reported    TYPE abp_behv_response_tab
        subrc       TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cl_rap_eml_key IMPLEMENTATION.

  METHOD commit.
    COMMIT ENTITIES BEGIN
      RESPONSES FAILED failed REPORTED reported.
    subrc = sy-subrc.
    IF subrc = 0.
      CONVERT KEY OF (entity_name) FROM pid TO key.
    ENDIF.
    COMMIT ENTITIES END.
  ENDMETHOD.

ENDCLASS.
