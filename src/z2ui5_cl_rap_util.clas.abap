"! Reads the metadata of a CDS entity - its fields with their ABAP types,
"! keys and the UI annotations - into one structure the floorplans render
"! from.
"!
"! Annotations are read with metadata extensions: CL_DD_DDL_ANNOTATION_SERVICE
"! =>GET_ANNOS returns them merged by layer, together with the direct and the
"! derived annotations (all methods of the service except the GET_DIRECT_ANNOS_*
"! ones do). RAP business objects keep their @UI annotations in metadata
"! extensions almost always, so reading only the direct ones - which this class
"! did up to 2026-09 - rendered every such object from the fallbacks. GET_ANNOS
"! is called dynamically and its parameter types are taken from RTTI, so a
"! release whose signature differs falls back to the direct reading instead of
"! failing to compile.
"!
"! The parsing itself (apply_annotations) works on plain key/value tables and
"! needs no system - that is what the unit tests drive.
CLASS z2ui5_cl_rap_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "======= FIELD-LEVEL TYPES =======

    TYPES:
      BEGIN OF ty_s_additional_binding,
        element       TYPE string,
        local_element TYPE string,
        usage         TYPE string,
      END OF ty_s_additional_binding.

    TYPES ty_t_additional_binding TYPE STANDARD TABLE OF ty_s_additional_binding WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_value_help,
        entity_name        TYPE string,
        element            TYPE string,
        is_dropdown        TYPE abap_bool,
        additional_binding TYPE ty_t_additional_binding,
      END OF ty_s_value_help.

    TYPES:
      BEGIN OF ty_s_field_group,
        qualifier TYPE string,
        position  TYPE i,
        "the field's label within the group (@UI.fieldGroup.label)
        label     TYPE string,
        "the group's title (@UI.fieldGroup.groupLabel) - added 2026-10
        group_label TYPE string,
      END OF ty_s_field_group.

    TYPES ty_t_field_group TYPE STANDARD TABLE OF ty_s_field_group WITH DEFAULT KEY.

    " @UI.dataPoint.criticalityCalculation - the thresholds that turn a
    " value into a criticality (criticality_by_calculation)
    TYPES:
      BEGIN OF ty_s_crit_calc,
        "MAXIMIZE, MINIMIZE or TARGET
        improvement_direction TYPE string,
        deviation_low         TYPE string,
        tolerance_low         TYPE string,
        tolerance_high        TYPE string,
        deviation_high        TYPE string,
      END OF ty_s_crit_calc.

    TYPES:
      BEGIN OF ty_s_field_info,
        "identification
        name               TYPE string,
        label              TYPE string,
        tooltip            TYPE string,
        is_key             TYPE abap_bool,

        "ABAP type info
        type_kind          TYPE string,
        abap_type          TYPE string,
        data_element       TYPE string,
        length             TYPE i,
        decimals           TYPE i,
        is_boolean         TYPE abap_bool,

        "UI annotations
        is_hidden          TYPE abap_bool,
        is_mandatory       TYPE abap_bool,
        is_multiline       TYPE abap_bool,
        is_visible         TYPE abap_bool,
        is_searchable      TYPE abap_bool,
        is_high_importance TYPE abap_bool,
        default_value      TYPE string,
        text_element       TYPE string,

        "fieldGroup - field_group/field_group_pos is the first entry,
        "field_groups every entry (a field can sit in several groups)
        field_group        TYPE string,
        field_group_pos    TYPE i,

        "lineItem (the unqualified, non-action entry)
        line_item_pos        TYPE i,
        line_item_importance TYPE string,
        line_item_crit_field TYPE string,
        line_item_label      TYPE string,

        "selectionField
        selection_field_pos TYPE i,
        is_selection_field  TYPE abap_bool,

        "identification
        identification_pos TYPE i,
        is_identification  TYPE abap_bool,

        "dataPoint
        datapoint_qualifier  TYPE string,
        datapoint_crit_field TYPE string,

        "semantics
        semantics_currency_code   TYPE string,
        semantics_unit_of_measure TYPE string,
        is_currency_field         TYPE abap_bool,
        is_unit_field             TYPE abap_bool,
        is_amount_field           TYPE abap_bool,
        is_quantity_field         TYPE abap_bool,

        "value help
        value_help                TYPE ty_s_value_help,

        "added 2026-09 - appended so the existing layout stays as it was
        field_groups              TYPE ty_t_field_group,
        is_readonly               TYPE abap_bool,
        filter_default            TYPE string,
        "@UI.textArrangement: TEXT_FIRST, TEXT_LAST, TEXT_ONLY, TEXT_SEPARATE
        text_arrangement          TYPE string,
        crit_calc                 TYPE ty_s_crit_calc,
        "added 2026-10
        "the administrative field this is (@Semantics.user / .systemDateTime):
        "CREATED_BY, CREATED_AT, LAST_CHANGED_BY, LAST_CHANGED_AT,
        "LOCAL_LAST_CHANGED_AT
        admin_field               TYPE string,
        "@Consumption.filter: SINGLE, INTERVAL, RANGE (selectionType),
        "single = one value only (multipleSelections: false or #SINGLE),
        "mandatory and hidden
        filter_selection_type     TYPE string,
        filter_single             TYPE abap_bool,
        filter_mandatory          TYPE abap_bool,
        filter_hidden             TYPE abap_bool,
        "the column's @UI.lineItem type: STANDARD, WITH_URL (line_item_url
        "is the field with the URL), WITH_NAVIGATION_PATH (line_item_target
        "is the association), WITH_INTENT_BASED_NAVIGATION (the semantic
        "object and action)
        line_item_type            TYPE string,
        line_item_url             TYPE string,
        line_item_target          TYPE string,
        line_item_sem_object      TYPE string,
        line_item_sem_action      TYPE string,
      END OF ty_s_field_info.

    TYPES ty_t_field_info TYPE STANDARD TABLE OF ty_s_field_info WITH DEFAULT KEY.

    "======= ENTITY-LEVEL TYPES =======

    TYPES:
      BEGIN OF ty_s_facet,
        id               TYPE string,
        parent_id        TYPE string,
        type             TYPE string,
        label            TYPE string,
        target_qualifier TYPE string,
        position         TYPE i,
        purpose          TYPE string,
        "association of a #LINEITEM_REFERENCE facet (added 2026-09)
        target_element   TYPE string,
      END OF ty_s_facet.

    TYPES ty_t_facet TYPE STANDARD TABLE OF ty_s_facet WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_header_info,
        type_name        TYPE string,
        type_name_plural TYPE string,
        title_field      TYPE string,
        description_field TYPE string,
        image_field      TYPE string,
      END OF ty_s_header_info.

    TYPES:
      BEGIN OF ty_s_annotation,
        key   TYPE string,
        value TYPE string,
      END OF ty_s_annotation.

    TYPES ty_t_annotation TYPE STANDARD TABLE OF ty_s_annotation WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_element_annotation,
        element TYPE string,
        key     TYPE string,
        value   TYPE string,
      END OF ty_s_element_annotation.

    TYPES ty_t_element_annotation TYPE STANDARD TABLE OF ty_s_element_annotation WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_raw_annotations,
        entity   TYPE ty_t_annotation,
        elements TYPE ty_t_element_annotation,
        "abap_true when GET_ANNOS answered (metadata extensions included),
        "abap_false when only the direct annotations could be read
        with_metadata_extensions TYPE abap_bool,
      END OF ty_s_raw_annotations.

    " An action a @UI.lineItem or @UI.identification entry of type
    " #FOR_ACTION offers - name is the action of the behavior definition
    TYPES:
      BEGIN OF ty_s_action,
        name     TYPE string,
        label    TYPE string,
        position TYPE i,
        "LINEITEM (list: toolbar or inline) or IDENTIFICATION (object page)
        source   TYPE string,
        inline   TYPE abap_bool,
        "added 2026-10: an entry of type #FOR_INTENT_BASED_NAVIGATION - a
        "button that navigates in the launchpad instead of an action
        semantic_object TYPE string,
        semantic_action TYPE string,
      END OF ty_s_action.

    TYPES ty_t_action TYPE STANDARD TABLE OF ty_s_action WITH DEFAULT KEY.

    " One @UI.chart entry
    TYPES:
      BEGIN OF ty_s_chart,
        qualifier  TYPE string,
        title      TYPE string,
        chart_type TYPE string,
        dimensions TYPE string_table,
        measures   TYPE string_table,
      END OF ty_s_chart.

    TYPES ty_t_chart TYPE STANDARD TABLE OF ty_s_chart WITH DEFAULT KEY.

    " one sort criterion of @UI.presentationVariant
    TYPES:
      BEGIN OF ty_s_sort,
        field      TYPE string,
        descending TYPE abap_bool,
      END OF ty_s_sort.

    TYPES ty_t_sort TYPE STANDARD TABLE OF ty_s_sort WITH DEFAULT KEY.

    " one @UI.presentationVariant: how many rows, in which order, shown as
    " the line item or a chart (its first visualization)
    TYPES:
      BEGIN OF ty_s_presentation_variant,
        qualifier               TYPE string,
        max_items               TYPE i,
        sort_order              TYPE ty_t_sort,
        "LINEITEM or CHART
        visualization_type      TYPE string,
        visualization_qualifier TYPE string,
      END OF ty_s_presentation_variant.

    TYPES ty_t_presentation_variant TYPE STANDARD TABLE OF ty_s_presentation_variant WITH EMPTY KEY.

    " one @UI.selectionVariant - filter is its filter string
    " ('Status EQ O AND Priority GT 2'), see selection_filter_to_where
    TYPES:
      BEGIN OF ty_s_selection_variant,
        qualifier TYPE string,
        text      TYPE string,
        filter    TYPE string,
      END OF ty_s_selection_variant.

    TYPES ty_t_selection_variant TYPE STANDARD TABLE OF ty_s_selection_variant WITH DEFAULT KEY.

    " one comparison of an association's ON condition: a field of the
    " entity that has the association equals a field of its target
    TYPES:
      BEGIN OF ty_s_assoc_condition,
        local  TYPE string,
        target TYPE string,
      END OF ty_s_assoc_condition.

    TYPES ty_t_assoc_condition TYPE STANDARD TABLE OF ty_s_assoc_condition WITH EMPTY KEY.

    " an association or composition of a CDS entity, read from its DDL
    " source (read_associations) - name is the alias (_BOOKING), target the
    " entity it leads to, both upper case
    TYPES:
      BEGIN OF ty_s_association,
        name           TYPE string,
        target         TYPE string,
        is_composition TYPE abap_bool,
        is_to_parent   TYPE abap_bool,
        "the field pairs of the ON condition that compare two fields; a
        "composition has none in its own source - they come from the
        "child's association to parent
        conditions     TYPE ty_t_assoc_condition,
      END OF ty_s_association.

    TYPES ty_t_association TYPE STANDARD TABLE OF ty_s_association WITH EMPTY KEY.

    " what parse_ddl_associations finds in one DDL source
    TYPES:
      BEGIN OF ty_s_ddl_associations,
        "the entity a projection is defined on (as projection on X)
        base         TYPE string,
        associations TYPE ty_t_association,
      END OF ty_s_ddl_associations.

    TYPES:
      BEGIN OF ty_s_entity_info,
        "identification
        name            TYPE string,
        description     TYPE string,
        entity_type     TYPE string,

        "key metadata
        is_dropdown     TYPE abap_bool,
        is_searchable   TYPE abap_bool,
        semantic_key    TYPE string_table,

        "structure
        fields          TYPE ty_t_field_info,
        facets          TYPE ty_t_facet,
        header_info     TYPE ty_s_header_info,

        "raw annotations (entity-level)
        entity_annotations TYPE ty_t_annotation,

        "added 2026-09 - appended so the existing layout stays as it was
        "the key fields of the entity: DDIC keys, else @ObjectModel.semanticKey
        keys            TYPE string_table,
        actions         TYPE ty_t_action,
        charts          TYPE ty_t_chart,
        "added 2026-10
        "the sort order of the default @UI.presentationVariant
        sort_order         TYPE ty_t_sort,
        selection_variants TYPE ty_t_selection_variant,
        "the associations and compositions, from the DDL source
        associations       TYPE ty_t_association,
        "every @UI.presentationVariant
        presentation_variants TYPE ty_t_presentation_variant,
      END OF ty_s_entity_info.

    "======= PUBLIC METHODS =======

    "! Read full metadata for a CDS entity (abstract entity, view entity, etc.)
    CLASS-METHODS read_entity
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_entity_info.

    "! Read entity-level annotations only (no field details)
    CLASS-METHODS read_entity_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_entity_info.

    "! Read annotations for a single field
    CLASS-METHODS read_field_annotations
      IMPORTING
        entity_name   TYPE clike
        field_name    TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_annotation.

    "! Check if a CDS entity has sizeCategory #XS
    CLASS-METHODS is_size_category_xs
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Get list of key fields for an entity - the DDIC keys, else the
    "! elements of @ObjectModel.semanticKey
    CLASS-METHODS get_key_fields
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE string_table.

    "! Get all annotations for an entity (raw key-value pairs)
    CLASS-METHODS get_all_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_annotation.

    "! Every annotation of an entity and its elements, metadata extensions
    "! included where the release supports it
    CLASS-METHODS read_raw_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_raw_annotations.

    "! Interpret raw annotations into cs_entity. cs_entity-fields must already
    "! hold one row per element (read_entity fills them from RTTI); elements
    "! without a row are ignored, except for @UI.facet, which is collected
    "! from every element. Needs no system - the unit tests drive it.
    CLASS-METHODS apply_annotations
      IMPORTING
        it_entity   TYPE ty_t_annotation
        it_elements TYPE ty_t_element_annotation
      CHANGING
        cs_entity   TYPE ty_s_entity_info.

    "! The WHERE condition (ABAP SQL) for the user's filter text on one field:
    "!   abc     contains (text fields) / equals (other types)
    "!   a*c     pattern             =abc   equals
    "!   !abc    not                 a..z   between
    "!   &gt;x &gt;=x &lt;x &lt;=x       compare
    "!   several of them separated by ; are ORed
    "! Values become literals of the field's type with their quotes doubled,
    "! and a LIKE escapes the user's own % and _ - the field name comes from
    "! the metadata, never from the user.
    CLASS-METHODS build_filter_condition
      IMPORTING
        is_field      TYPE ty_s_field_info
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The WHERE condition of a free-text search over the text fields of
    "! it_fields - the @Search.defaultSearchElement ones when there are any,
    "! else every visible one - case-insensitive, * as wildcard
    CLASS-METHODS build_search_condition
      IMPORTING
        it_fields     TYPE ty_t_field_info
        search        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The WHERE condition (ABAP SQL) of a @UI.selectionVariant filter
    "! string: conditions "Field OP Value" joined with AND, OP one of EQ NE
    "! GT GE LT LE, the value optionally in quotes. Empty when the string
    "! names a field that it_fields does not have or an operator it does
    "! not know - a variant that cannot be read restricts nothing wrongly
    CLASS-METHODS selection_filter_to_where
      IMPORTING
        filter        TYPE string
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! The criticality (1 negative, 2 critical, 3 positive, 0 neutral) of a
    "! value by @UI.dataPoint.criticalityCalculation
    CLASS-METHODS criticality_by_calculation
      IMPORTING
        value         TYPE decfloat34
        is_calc       TYPE ty_s_crit_calc
      RETURNING
        VALUE(result) TYPE i.

    "! The associations of a CDS entity with their targets and ON
    "! conditions - read from its DDL source (DDDDLSRC), completed from the
    "! entity a projection is defined on and, for a composition, from the
    "! child's association to parent. Empty when the source cannot be read;
    "! z2ui5_if_rap_ext~resolve_association still decides first
    CLASS-METHODS read_associations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_association.

    "! The associations a DDL source declares: association [..] to X as _A
    "! on ..., association to parent X as _A on ..., composition [..] of X
    "! as _A, the 7.58 forms with of many to one, and in a projection
    "! _A : redirected to [composition child | parent] X. Comments are
    "! skipped. Needs no system - the unit tests drive it
    CLASS-METHODS parse_ddl_associations
      IMPORTING
        source        TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_ddl_associations.

    "! A projection inherits the associations of its base: one it does not
    "! redirect keeps the base's target, one it redirects keeps its own
    "! target and takes what it lacks (the ON condition, the kind) from the
    "! base
    CLASS-METHODS merge_base_associations
      IMPORTING
        it_base  TYPE ty_t_association
      CHANGING
        ct_assoc TYPE ty_t_association.

    "! The ON condition of a composition, seen from the parent: the child's
    "! association to parent (target = parent) turned around
    CLASS-METHODS get_parent_conditions
      IMPORTING
        it_child_assoc TYPE ty_t_association
        parent         TYPE clike
      RETURNING
        VALUE(result)  TYPE ty_t_assoc_condition.

    "! align ABAP and JSON model representations of a key value: dates
    "! (2024-01-15), times (12:30:00), padding
    CLASS-METHODS normalize_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! val as the content of a JSON string - quotes, backslashes and control
    "! characters escaped
    CLASS-METHODS json_escape
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! Remove one pair of enclosing single quotes and surrounding blanks
    CLASS-METHODS strip_quotes
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_cache,
        name TYPE string,
        raw  TYPE ty_s_raw_annotations,
      END OF ty_s_cache.

    "! Raw annotations per entity for the rest of the ABAP session - a list
    "! report reads the annotations of every value help entity it meets, and
    "! the same few entities come up again and again
    CLASS-DATA gt_cache TYPE STANDARD TABLE OF ty_s_cache WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_assoc_cache,
        name         TYPE string,
        associations TYPE ty_t_association,
      END OF ty_s_assoc_cache.

    "! the associations per entity for the rest of the ABAP session
    CLASS-DATA gt_assoc_cache TYPE STANDARD TABLE OF ty_s_assoc_cache WITH EMPTY KEY.

    CLASS-METHODS read_associations_level
      IMPORTING
        entity_name   TYPE string
        level         TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_association.

    "! the DDL source of an entity - empty when there is none to read
    CLASS-METHODS read_ddl_source
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the words and signs of a DDL source, comments left out - a quoted
    "! literal stays one token, a bracket, brace, parenthesis, comma, colon,
    "! semicolon and equals sign are tokens of their own
    CLASS-METHODS tokenize_ddl
      IMPORTING
        source        TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the field pairs of an ON condition (its tokens) - alias is the
    "! association's own name, which marks the target's side
    CLASS-METHODS parse_on_condition
      IMPORTING
        it_tokens     TYPE string_table
        alias         TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_assoc_condition.

    TYPES:
      BEGIN OF ty_s_entry,
        idx   TYPE i,
        prop  TYPE string,
        value TYPE string,
      END OF ty_s_entry.

    TYPES ty_t_entry TYPE STANDARD TABLE OF ty_s_entry WITH DEFAULT KEY.

    CLASS-METHODS detect_boolean
      IMPORTING
        io_elem       TYPE REF TO cl_abap_elemdescr
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS parse_field_annotations
      IMPORTING
        it_annos TYPE ty_t_annotation
      CHANGING
        cs_field TYPE ty_s_field_info.

    "! The entries of an annotation that may be an array: for the prefix
    "! UI.LINEITEM, UI.LINEITEM$2$.LABEL gives idx 2 / prop LABEL and the
    "! non-array form UI.LINEITEM.LABEL gives idx 1 / prop LABEL
    CLASS-METHODS get_entries
      IMPORTING
        it_annos      TYPE ty_t_annotation
        prefix        TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_entry.

    CLASS-METHODS get_entry_value
      IMPORTING
        it_entries    TYPE ty_t_entry
        idx           TYPE i
        prop          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS split_index
      IMPORTING
        val  TYPE string
      EXPORTING
        idx  TYPE i
        rest TYPE string.

    CLASS-METHODS to_int
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS is_true
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS parse_facets
      IMPORTING
        it_annos TYPE ty_t_annotation
      CHANGING
        ct_facet TYPE ty_t_facet.

    CLASS-METHODS parse_actions
      IMPORTING
        it_annos  TYPE ty_t_annotation
        prefix    TYPE string
        source    TYPE string
      CHANGING
        ct_action TYPE ty_t_action.

    CLASS-METHODS parse_variants
      IMPORTING
        it_annos  TYPE ty_t_annotation
      CHANGING
        cs_entity TYPE ty_s_entity_info.

    CLASS-METHODS parse_charts
      IMPORTING
        it_annos TYPE ty_t_annotation
      CHANGING
        ct_chart TYPE ty_t_chart.

    CLASS-METHODS read_annos_effective
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_raw_annotations
      RAISING
        cx_root.

    CLASS-METHODS literal
      IMPORTING
        is_field      TYPE ty_s_field_info
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS read_annos_direct
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_raw_annotations.

    CLASS-METHODS get_ddic_fields
      IMPORTING
        io_struct     TYPE REF TO cl_abap_structdescr
      RETURNING
        VALUE(result) TYPE ddfields.

ENDCLASS.



CLASS z2ui5_cl_rap_util IMPLEMENTATION.

  METHOD read_entity.

    DATA(lv_name) = to_upper( entity_name ).
    result-name = lv_name.

    DATA(ls_raw) = read_raw_annotations( lv_name ).

    "======= FIELDS FROM RTTI =======
    DATA lo_descr TYPE REF TO cl_abap_structdescr.
    TRY.
        lo_descr = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( lv_name ) ).
      CATCH cx_root.
        "no structured type of that name - annotations only
        apply_annotations( EXPORTING it_entity   = ls_raw-entity
                                     it_elements = ls_raw-elements
                           CHANGING  cs_entity   = result ).
        RETURN.
    ENDTRY.

    IF lo_descr->absolute_name CS `\TYPE=`.
      result-entity_type = `STRUCTURE`.
    ELSE.
      result-entity_type = `VIEW`.
    ENDIF.

    "DDIC view of the components: key flags and the data element texts
    DATA(lt_ddic) = get_ddic_fields( lo_descr ).

    LOOP AT lo_descr->get_components( ) INTO DATA(ls_comp).
      DATA(ls_field) = VALUE ty_s_field_info(
        name       = ls_comp-name
        is_visible = abap_true ).

      IF ls_comp-type->kind = cl_abap_typedescr=>kind_elem.
        DATA(lo_elem) = CAST cl_abap_elemdescr( ls_comp-type ).
        CASE lo_elem->type_kind.
          WHEN cl_abap_typedescr=>typekind_date.
            ls_field-type_kind = `DATS`.
          WHEN cl_abap_typedescr=>typekind_time.
            ls_field-type_kind = `TIMS`.
          WHEN cl_abap_typedescr=>typekind_int
            OR cl_abap_typedescr=>typekind_int1
            OR cl_abap_typedescr=>typekind_int2
            OR cl_abap_typedescr=>typekind_int8.
            ls_field-type_kind = `INT`.
          WHEN cl_abap_typedescr=>typekind_packed
            OR cl_abap_typedescr=>typekind_decfloat16
            OR cl_abap_typedescr=>typekind_decfloat34.
            ls_field-type_kind = `DEC`.
          WHEN cl_abap_typedescr=>typekind_string.
            ls_field-type_kind = `STRING`.
          "no LIKE and no UPPER on these - they are not text
          WHEN cl_abap_typedescr=>typekind_hex
            OR cl_abap_typedescr=>typekind_xstring.
            ls_field-type_kind = `RAW`.
          WHEN cl_abap_typedescr=>typekind_float.
            ls_field-type_kind = `FLTP`.
          WHEN OTHERS.
            ls_field-type_kind = `CHAR`.
        ENDCASE.
        ls_field-length = lo_elem->output_length.
        ls_field-decimals = lo_elem->decimals.
        ls_field-is_boolean = detect_boolean( lo_elem ).

        DATA(lv_abs) = lo_elem->absolute_name.
        IF lv_abs CS `\TYPE=`.
          ls_field-data_element = lv_abs+6.
        ENDIF.
        ls_field-abap_type = lo_elem->get_relative_name( ).
      ENDIF.

      READ TABLE lt_ddic INTO DATA(ls_dfies) WITH KEY fieldname = ls_comp-name.
      IF sy-subrc = 0.
        IF ls_dfies-keyflag = abap_true.
          ls_field-is_key = abap_true.
          APPEND ls_comp-name TO result-keys.
        ENDIF.
        "the data element text - @EndUserText.label overrides it below
        ls_field-label = COND #( WHEN ls_dfies-scrtext_m IS NOT INITIAL THEN ls_dfies-scrtext_m
                                 ELSE ls_dfies-fieldtext ).
      ENDIF.

      APPEND ls_field TO result-fields.
    ENDLOOP.

    apply_annotations( EXPORTING it_entity   = ls_raw-entity
                                 it_elements = ls_raw-elements
                       CHANGING  cs_entity   = result ).

    "no DDIC keys (abstract entities, custom entities): the semantic key
    IF result-keys IS INITIAL.
      LOOP AT result-semantic_key INTO DATA(lv_key).
        IF line_exists( result-fields[ name = lv_key ] ).
          APPEND lv_key TO result-keys.
        ENDIF.
      ENDLOOP.
    ENDIF.
    LOOP AT result-fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      IF line_exists( result-keys[ table_line = <ls_field>-name ] ).
        <ls_field>-is_key = abap_true.
      ENDIF.
      "the value help entity's own annotation decides the dropdown
      IF <ls_field>-value_help-entity_name IS NOT INITIAL.
        <ls_field>-value_help-is_dropdown = is_size_category_xs( <ls_field>-value_help-entity_name ).
      ENDIF.
    ENDLOOP.

    result-associations = read_associations( lv_name ).

  ENDMETHOD.


  METHOD apply_annotations.

    DATA lt_field_annos TYPE ty_t_annotation.

    "======= ENTITY LEVEL =======
    LOOP AT it_entity INTO DATA(ls_ea).
      DATA(lv_key) = to_upper( ls_ea-key ).
      DATA(lv_val) = ls_ea-value.

      APPEND VALUE ty_s_annotation( key = lv_key value = lv_val ) TO cs_entity-entity_annotations.

      IF lv_key CS `OBJECTMODEL.RESULTSET.SIZECATEGORY` AND lv_val CS `XS`.
        cs_entity-is_dropdown = abap_true.
      ENDIF.
      IF lv_key = `SEARCH.SEARCHABLE` AND is_true( lv_val ).
        cs_entity-is_searchable = abap_true.
      ENDIF.
      IF lv_key = `ENDUSERTEXT.LABEL`.
        cs_entity-description = strip_quotes( lv_val ).
      ENDIF.
      CASE lv_key.
        WHEN `UI.HEADERINFO.TYPENAME`.
          cs_entity-header_info-type_name = strip_quotes( lv_val ).
        WHEN `UI.HEADERINFO.TYPENAMEPLURAL`.
          cs_entity-header_info-type_name_plural = strip_quotes( lv_val ).
        WHEN `UI.HEADERINFO.TITLE.VALUE`.
          cs_entity-header_info-title_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `UI.HEADERINFO.DESCRIPTION.VALUE`.
          cs_entity-header_info-description_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `UI.HEADERINFO.IMAGEURL`.
          cs_entity-header_info-image_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `UI.HEADERINFO.IMAGEURL.VALUE`.
          cs_entity-header_info-image_field = to_upper( strip_quotes( lv_val ) ).
      ENDCASE.
      IF lv_key CP `OBJECTMODEL.SEMANTICKEY*`.
        APPEND to_upper( strip_quotes( lv_val ) ) TO cs_entity-semantic_key.
      ENDIF.
    ENDLOOP.

    "facets and charts are allowed on the entity as well as on an element -
    "RAP metadata extensions put @UI.facet on the first element
    parse_facets( EXPORTING it_annos = cs_entity-entity_annotations
                  CHANGING  ct_facet = cs_entity-facets ).
    parse_charts( EXPORTING it_annos = cs_entity-entity_annotations
                  CHANGING  ct_chart = cs_entity-charts ).
    parse_variants( EXPORTING it_annos  = cs_entity-entity_annotations
                    CHANGING  cs_entity = cs_entity ).

    "======= ELEMENT LEVEL =======
    DATA(lt_elements) = it_elements.
    LOOP AT lt_elements ASSIGNING FIELD-SYMBOL(<ls_el>).
      <ls_el>-element = to_upper( <ls_el>-element ).
      <ls_el>-key = to_upper( <ls_el>-key ).
    ENDLOOP.
    SORT lt_elements BY element.

    DATA lv_element TYPE string.
    LOOP AT lt_elements INTO DATA(ls_el).
      IF ls_el-element <> lv_element.
        lv_element = ls_el-element.
        CLEAR lt_field_annos.
        LOOP AT lt_elements INTO DATA(ls_same) WHERE element = lv_element.
          APPEND VALUE #( key = ls_same-key value = ls_same-value ) TO lt_field_annos.
        ENDLOOP.

        parse_facets( EXPORTING it_annos = lt_field_annos
                      CHANGING  ct_facet = cs_entity-facets ).
        parse_charts( EXPORTING it_annos = lt_field_annos
                      CHANGING  ct_chart = cs_entity-charts ).
        parse_actions( EXPORTING it_annos  = lt_field_annos
                                 prefix    = `UI.LINEITEM`
                                 source    = `LINEITEM`
                       CHANGING  ct_action = cs_entity-actions ).
        parse_actions( EXPORTING it_annos  = lt_field_annos
                                 prefix    = `UI.IDENTIFICATION`
                                 source    = `IDENTIFICATION`
                       CHANGING  ct_action = cs_entity-actions ).

        READ TABLE cs_entity-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
          WITH KEY name = lv_element.
        IF sy-subrc = 0.
          parse_field_annotations( EXPORTING it_annos = lt_field_annos
                                   CHANGING  cs_field = <ls_field> ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    SORT cs_entity-facets BY position.
    SORT cs_entity-actions BY source position.

    LOOP AT cs_entity-fields ASSIGNING <ls_field>.
      IF <ls_field>-label IS INITIAL.
        <ls_field>-label = <ls_field>-name.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_field_annotations.

    LOOP AT it_annos INTO DATA(ls_anno).
      DATA(lv_key) = to_upper( ls_anno-key ).
      DATA(lv_val) = ls_anno-value.

      CASE lv_key.
        WHEN `ENDUSERTEXT.LABEL`.
          cs_field-label = strip_quotes( lv_val ).
        WHEN `ENDUSERTEXT.QUICKINFO`.
          cs_field-tooltip = strip_quotes( lv_val ).
        WHEN `UI.HIDDEN`.
          cs_field-is_hidden = is_true( lv_val ).
        WHEN `UI.MULTILINETEXT`.
          cs_field-is_multiline = is_true( lv_val ).
        WHEN `UI.DEFAULTVALUE`.
          cs_field-default_value = strip_quotes( lv_val ).
        WHEN `OBJECTMODEL.MANDATORY`.
          cs_field-is_mandatory = is_true( lv_val ).
        WHEN `OBJECTMODEL.READONLY`.
          cs_field-is_readonly = is_true( lv_val ).
        WHEN `CONSUMPTION.VALUEHELPDEFAULT.DISPLAY`.
          cs_field-is_visible = is_true( lv_val ).
        WHEN `SEARCH.DEFAULTSEARCHELEMENT`.
          cs_field-is_searchable = is_true( lv_val ).
        WHEN `SEMANTICS.AMOUNT.CURRENCYCODE`.
          cs_field-semantics_currency_code = to_upper( strip_quotes( lv_val ) ).
          cs_field-is_amount_field = abap_true.
        WHEN `SEMANTICS.QUANTITY.UNITOFMEASURE`.
          cs_field-semantics_unit_of_measure = to_upper( strip_quotes( lv_val ) ).
          cs_field-is_quantity_field = abap_true.
        WHEN `SEMANTICS.CURRENCYCODE`.
          cs_field-is_currency_field = is_true( lv_val ).
        WHEN `SEMANTICS.UNITOFMEASURE`.
          cs_field-is_unit_field = is_true( lv_val ).
        WHEN `SEMANTICS.BOOLEANINDICATOR`.
          IF is_true( lv_val ).
            cs_field-is_boolean = abap_true.
          ENDIF.
        WHEN `UI.TEXTARRANGEMENT`.
          cs_field-text_arrangement = replace( val = strip_quotes( lv_val ) sub = `#` with = `` ).
        WHEN `UI.DATAPOINT.CRITICALITYCALCULATION.IMPROVEMENTDIRECTION`.
          cs_field-crit_calc-improvement_direction = replace( val = strip_quotes( lv_val ) sub = `#` with = `` ).
        WHEN `UI.DATAPOINT.CRITICALITYCALCULATION.DEVIATIONRANGELOWVALUE`.
          cs_field-crit_calc-deviation_low = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.CRITICALITYCALCULATION.TOLERANCERANGELOWVALUE`.
          cs_field-crit_calc-tolerance_low = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.CRITICALITYCALCULATION.TOLERANCERANGEHIGHVALUE`.
          cs_field-crit_calc-tolerance_high = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.CRITICALITYCALCULATION.DEVIATIONRANGEHIGHVALUE`.
          cs_field-crit_calc-deviation_high = strip_quotes( lv_val ).
        WHEN `CONSUMPTION.FILTER.DEFAULTVALUE`.
          cs_field-filter_default = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.QUALIFIER`.
          cs_field-datapoint_qualifier = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.CRITICALITY`.
          cs_field-datapoint_crit_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `SEMANTICS.USER.CREATEDBY`.
          IF is_true( lv_val ).
            cs_field-admin_field = `CREATED_BY`.
          ENDIF.
        WHEN `SEMANTICS.SYSTEMDATETIME.CREATEDAT` OR `SEMANTICS.SYSTEMDATE.CREATEDAT`.
          IF is_true( lv_val ).
            cs_field-admin_field = `CREATED_AT`.
          ENDIF.
        WHEN `SEMANTICS.USER.LASTCHANGEDBY`.
          IF is_true( lv_val ).
            cs_field-admin_field = `LAST_CHANGED_BY`.
          ENDIF.
        WHEN `SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT` OR `SEMANTICS.SYSTEMDATE.LASTCHANGEDAT`.
          IF is_true( lv_val ).
            cs_field-admin_field = `LAST_CHANGED_AT`.
          ENDIF.
        WHEN `SEMANTICS.SYSTEMDATETIME.LOCALINSTANCELASTCHANGEDAT`.
          IF is_true( lv_val ).
            cs_field-admin_field = `LOCAL_LAST_CHANGED_AT`.
          ENDIF.
        WHEN `CONSUMPTION.FILTER.SELECTIONTYPE`.
          cs_field-filter_selection_type = replace( val = strip_quotes( lv_val ) sub = `#` with = `` ).
          IF cs_field-filter_selection_type = `SINGLE`.
            cs_field-filter_single = abap_true.
          ENDIF.
        WHEN `CONSUMPTION.FILTER.MULTIPLESELECTIONS`.
          IF to_lower( strip_quotes( lv_val ) ) = `false`.
            cs_field-filter_single = abap_true.
          ENDIF.
        WHEN `CONSUMPTION.FILTER.MANDATORY`.
          cs_field-filter_mandatory = is_true( lv_val ).
        WHEN `CONSUMPTION.FILTER.HIDDEN`.
          cs_field-filter_hidden = is_true( lv_val ).
      ENDCASE.

      "@ObjectModel.text.element: ['Name'] - an array of one
      IF lv_key CP `OBJECTMODEL.TEXT.ELEMENT*`.
        cs_field-text_element = to_upper( strip_quotes( lv_val ) ).
      ENDIF.

      "a @UI.dataPoint without its own qualifier is still a data point
      IF lv_key CP `UI.DATAPOINT.*` AND cs_field-datapoint_qualifier IS INITIAL.
        cs_field-datapoint_qualifier = cs_field-name.
      ENDIF.
    ENDLOOP.

    "======= @UI.lineItem - the unqualified entry that is not an action =======
    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = `UI.LINEITEM` ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(lv_type) = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      IF lv_type CS `FOR_ACTION` OR lv_type CS `FOR_INTENT`
        OR get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      cs_field-line_item_pos = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) ).
      IF cs_field-line_item_pos = 0.
        "an entry without a position still makes a column - behind the others
        cs_field-line_item_pos = 9999.
      ENDIF.
      cs_field-line_item_importance = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `IMPORTANCE` ) ).
      cs_field-is_high_importance = xsdbool( cs_field-line_item_importance CS `HIGH` ).
      cs_field-line_item_label = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) ).
      cs_field-line_item_crit_field = to_upper( strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `CRITICALITY` ) ) ).
      cs_field-line_item_type = replace( val = strip_quotes( lv_type ) sub = `#` with = `` ).
      cs_field-line_item_url = to_upper( strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `URL` ) ) ).
      cs_field-line_item_target = to_upper( strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TARGETELEMENT` ) ) ).
      cs_field-line_item_sem_object = strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECT` ) ).
      cs_field-line_item_sem_action = strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECTACTION` ) ).
      EXIT.
    ENDLOOP.

    "======= @UI.selectionField =======
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.SELECTIONFIELD` ).
    IF lt_entries IS NOT INITIAL.
      cs_field-is_selection_field = abap_true.
      cs_field-selection_field_pos = to_int( get_entry_value( it_entries = lt_entries idx = lt_entries[ 1 ]-idx prop = `POSITION` ) ).
      IF cs_field-selection_field_pos = 0.
        cs_field-selection_field_pos = 9999.
      ENDIF.
    ENDIF.

    "======= @UI.identification - the first entry that is not an action =======
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.IDENTIFICATION` ).
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      lv_type = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      IF lv_type CS `FOR_ACTION` OR lv_type CS `FOR_INTENT`.
        CONTINUE.
      ENDIF.
      cs_field-is_identification = abap_true.
      cs_field-identification_pos = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) ).
      EXIT.
    ENDLOOP.

    "======= @UI.fieldGroup - every entry, one per qualifier =======
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.FIELDGROUP` ).
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_group) = VALUE ty_s_field_group(
        qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        position  = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        group_label = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `GROUPLABEL` ) ) ).
      IF ls_group-qualifier IS INITIAL OR line_exists( cs_field-field_groups[ qualifier = ls_group-qualifier ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_group TO cs_field-field_groups.
    ENDLOOP.
    IF cs_field-field_groups IS NOT INITIAL.
      cs_field-field_group = cs_field-field_groups[ 1 ]-qualifier.
      cs_field-field_group_pos = cs_field-field_groups[ 1 ]-position.
    ENDIF.

    "======= @UI.dataPoint (array form) =======
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.DATAPOINT` ).
    IF lt_entries IS NOT INITIAL AND lt_entries[ 1 ]-idx > 0.
      DATA(lv_dp_qual) = strip_quotes( get_entry_value( it_entries = lt_entries idx = lt_entries[ 1 ]-idx prop = `QUALIFIER` ) ).
      IF lv_dp_qual IS NOT INITIAL.
        cs_field-datapoint_qualifier = lv_dp_qual.
      ENDIF.
      DATA(lv_dp_crit) = strip_quotes( get_entry_value( it_entries = lt_entries idx = lt_entries[ 1 ]-idx prop = `CRITICALITY` ) ).
      IF lv_dp_crit IS NOT INITIAL.
        cs_field-datapoint_crit_field = to_upper( lv_dp_crit ).
      ENDIF.
    ENDIF.

    "======= @Consumption.valueHelpDefinition - the first definition =======
    lt_entries = get_entries( it_annos = it_annos prefix = `CONSUMPTION.VALUEHELPDEFINITION` ).
    IF lt_entries IS NOT INITIAL.
      lv_idx = lt_entries[ 1 ]-idx.
      cs_field-value_help-entity_name = to_upper( strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ENTITY.NAME` ) ) ).
      cs_field-value_help-element = to_upper( strip_quotes(
          get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ENTITY.ELEMENT` ) ) ).

      "ADDITIONALBINDING$n$.ELEMENT / .LOCALELEMENT / .USAGE
      DATA lt_binding_annos TYPE ty_t_annotation.
      CLEAR lt_binding_annos.
      LOOP AT lt_entries INTO ls_entry WHERE idx = lv_idx AND prop CP `ADDITIONALBINDING*`.
        APPEND VALUE #( key = ls_entry-prop value = ls_entry-value ) TO lt_binding_annos.
      ENDLOOP.
      DATA(lt_bindings) = get_entries( it_annos = lt_binding_annos prefix = `ADDITIONALBINDING` ).
      DATA lv_bidx TYPE i.
      CLEAR lv_bidx.
      LOOP AT lt_bindings INTO DATA(ls_binding).
        IF ls_binding-idx = lv_bidx.
          CONTINUE.
        ENDIF.
        lv_bidx = ls_binding-idx.
        APPEND VALUE ty_s_additional_binding(
          element       = to_upper( strip_quotes( get_entry_value( it_entries = lt_bindings idx = lv_bidx prop = `ELEMENT` ) ) )
          local_element = to_upper( strip_quotes( get_entry_value( it_entries = lt_bindings idx = lv_bidx prop = `LOCALELEMENT` ) ) )
          usage         = strip_quotes( get_entry_value( it_entries = lt_bindings idx = lv_bidx prop = `USAGE` ) ) )
          TO cs_field-value_help-additional_binding.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD parse_facets.

    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = `UI.FACET` ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_facet) = VALUE ty_s_facet(
        id               = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ID` ) )
        parent_id        = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `PARENTID` ) )
        type             = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ) )
        label            = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        target_qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TARGETQUALIFIER` ) )
        position         = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        purpose          = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `PURPOSE` ) )
        target_element   = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TARGETELEMENT` ) ) ) ).
      IF ls_facet-id IS INITIAL.
        ls_facet-id = |FACET_{ lines( ct_facet ) + 1 }|.
      ENDIF.
      IF line_exists( ct_facet[ id = ls_facet-id ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_facet TO ct_facet.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_actions.

    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = prefix ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(lv_type) = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      IF lv_type NS `FOR_ACTION` AND lv_type NS `FOR_INTENT_BASED_NAVIGATION`.
        CONTINUE.
      ENDIF.
      DATA(ls_action) = VALUE ty_s_action(
        name     = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `DATAACTION` ) ) )
        label    = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        position = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        source   = source
        inline   = is_true( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `INLINE` ) ) ).
      "a navigation: named after its target, never the name of an action
      IF lv_type CS `FOR_INTENT_BASED_NAVIGATION`.
        ls_action-semantic_object = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECT` ) ).
        ls_action-semantic_action = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECTACTION` ) ).
        IF ls_action-semantic_object IS INITIAL OR ls_action-semantic_action IS INITIAL.
          CONTINUE.
        ENDIF.
        ls_action-name = to_upper( |INTENT~{ ls_action-semantic_object }~{ ls_action-semantic_action }| ).
      ENDIF.
      IF ls_action-name IS INITIAL
        OR line_exists( ct_action[ name = ls_action-name source = source ] ).
        CONTINUE.
      ENDIF.
      IF ls_action-label IS INITIAL.
        ls_action-label = ls_action-name.
      ENDIF.
      APPEND ls_action TO ct_action.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_variants.

    "declared here, not in the branches - the transpiled run scopes a
    "declaration to its block
    DATA lt_sort_annos TYPE ty_t_annotation.
    DATA lt_sort TYPE ty_t_entry.
    DATA lv_sidx TYPE i.
    DATA lv_by TYPE string.
    DATA ls_sort TYPE ty_s_entry.

    "@UI.presentationVariant - the unqualified one, else the first
    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = `UI.PRESENTATIONVARIANT` ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF get_entry_value( it_entries = lt_entries idx = ls_entry-idx prop = `QUALIFIER` ) IS INITIAL.
        lv_idx = ls_entry-idx.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lv_idx = 0 AND lt_entries IS NOT INITIAL.
      lv_idx = lt_entries[ 1 ]-idx.
    ENDIF.
    IF lv_idx > 0 AND cs_entity-sort_order IS INITIAL.
      "SORTORDER$n$.BY / .DIRECTION
      LOOP AT lt_entries INTO ls_entry WHERE idx = lv_idx AND prop CP `SORTORDER*`.
        APPEND VALUE #( key = ls_entry-prop value = ls_entry-value ) TO lt_sort_annos.
      ENDLOOP.
      lt_sort = get_entries( it_annos = lt_sort_annos prefix = `SORTORDER` ).
      LOOP AT lt_sort INTO ls_sort.
        IF ls_sort-idx = lv_sidx.
          CONTINUE.
        ENDIF.
        lv_sidx = ls_sort-idx.
        lv_by = to_upper( strip_quotes( get_entry_value( it_entries = lt_sort idx = lv_sidx prop = `BY` ) ) ).
        IF lv_by IS INITIAL.
          CONTINUE.
        ENDIF.
        APPEND VALUE ty_s_sort(
          field      = lv_by
          descending = xsdbool( get_entry_value( it_entries = lt_sort idx = lv_sidx prop = `DIRECTION` ) CS `DESC` ) )
          TO cs_entity-sort_order.
      ENDLOOP.
    ENDIF.

    "every @UI.presentationVariant - what a card of the overview page shows
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_variant_pv) = VALUE ty_s_presentation_variant(
        qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        max_items = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `MAXITEMS` ) ) ).
      IF line_exists( cs_entity-presentation_variants[ qualifier = ls_variant_pv-qualifier ] ).
        CONTINUE.
      ENDIF.
      CLEAR lt_sort_annos.
      DATA lt_viz_annos TYPE ty_t_annotation.
      CLEAR lt_viz_annos.
      LOOP AT lt_entries INTO DATA(ls_part) WHERE idx = lv_idx.
        IF ls_part-prop CP `SORTORDER*`.
          APPEND VALUE #( key = ls_part-prop value = ls_part-value ) TO lt_sort_annos.
        ELSEIF ls_part-prop CP `VISUALIZATIONS*`.
          APPEND VALUE #( key = ls_part-prop value = ls_part-value ) TO lt_viz_annos.
        ENDIF.
      ENDLOOP.
      lt_sort = get_entries( it_annos = lt_sort_annos prefix = `SORTORDER` ).
      CLEAR lv_sidx.
      LOOP AT lt_sort INTO ls_sort.
        IF ls_sort-idx = lv_sidx.
          CONTINUE.
        ENDIF.
        lv_sidx = ls_sort-idx.
        lv_by = to_upper( strip_quotes( get_entry_value( it_entries = lt_sort idx = lv_sidx prop = `BY` ) ) ).
        IF lv_by IS NOT INITIAL.
          APPEND VALUE ty_s_sort(
            field      = lv_by
            descending = xsdbool( get_entry_value( it_entries = lt_sort idx = lv_sidx prop = `DIRECTION` ) CS `DESC` ) )
            TO ls_variant_pv-sort_order.
        ENDIF.
      ENDLOOP.
      DATA(lt_viz) = get_entries( it_annos = lt_viz_annos prefix = `VISUALIZATIONS` ).
      IF lt_viz IS NOT INITIAL.
        DATA(lv_viz_type) = get_entry_value( it_entries = lt_viz idx = lt_viz[ 1 ]-idx prop = `TYPE` ).
        ls_variant_pv-visualization_type = COND #( WHEN lv_viz_type CS `CHART` THEN `CHART` ELSE `LINEITEM` ).
        ls_variant_pv-visualization_qualifier = strip_quotes(
          get_entry_value( it_entries = lt_viz idx = lt_viz[ 1 ]-idx prop = `QUALIFIER` ) ).
      ELSE.
        ls_variant_pv-visualization_type = `LINEITEM`.
      ENDIF.
      APPEND ls_variant_pv TO cs_entity-presentation_variants.
    ENDLOOP.

    "@UI.selectionVariant - every entry with a filter
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.SELECTIONVARIANT` ).
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_variant) = VALUE ty_s_selection_variant(
        qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        text      = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TEXT` ) )
        filter    = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `FILTER` ) ) ).
      IF ls_variant-filter IS INITIAL
        OR line_exists( cs_entity-selection_variants[ qualifier = ls_variant-qualifier ] ).
        CONTINUE.
      ENDIF.
      IF ls_variant-text IS INITIAL.
        ls_variant-text = COND #( WHEN ls_variant-qualifier IS NOT INITIAL THEN ls_variant-qualifier
                                  ELSE ls_variant-filter ).
      ENDIF.
      APPEND ls_variant TO cs_entity-selection_variants.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_charts.

    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = `UI.CHART` ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_chart) = VALUE ty_s_chart(
        qualifier  = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        title      = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TITLE` ) )
        chart_type = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `CHARTTYPE` ) ) ).
      "DIMENSIONS$1$ / MEASURES$1$ - or the non-array DIMENSIONS / MEASURES
      LOOP AT lt_entries INTO DATA(ls_part) WHERE idx = lv_idx.
        IF ls_part-prop CP `DIMENSIONS*`.
          APPEND to_upper( strip_quotes( ls_part-value ) ) TO ls_chart-dimensions.
        ELSEIF ls_part-prop CP `MEASURES*`.
          APPEND to_upper( strip_quotes( ls_part-value ) ) TO ls_chart-measures.
        ENDIF.
      ENDLOOP.
      IF ls_chart-measures IS INITIAL
        OR line_exists( ct_chart[ qualifier = ls_chart-qualifier ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_chart TO ct_chart.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_entries.

    DATA(lv_len) = strlen( prefix ).
    LOOP AT it_annos INTO DATA(ls_anno).
      DATA(lv_key) = to_upper( ls_anno-key ).
      IF strlen( lv_key ) <= lv_len OR lv_key(lv_len) <> prefix.
        CONTINUE.
      ENDIF.
      DATA(lv_rest) = substring( val = lv_key off = lv_len ).
      DATA(ls_entry) = VALUE ty_s_entry( value = ls_anno-value ).
      IF lv_rest(1) = `$`.
        "a copy - val is passed by reference and rest is cleared first
        DATA(lv_indexed) = lv_rest.
        split_index( EXPORTING val  = lv_indexed
                     IMPORTING idx  = ls_entry-idx
                               rest = lv_rest ).
        IF ls_entry-idx = 0.
          CONTINUE.
        ENDIF.
      ELSEIF lv_rest(1) = `.`.
        ls_entry-idx = 1.
      ELSE.
        "UI.LINEITEMS... - another annotation that only shares the prefix
        CONTINUE.
      ENDIF.
      IF lv_rest IS NOT INITIAL AND lv_rest(1) = `.`.
        lv_rest = substring( val = lv_rest off = 1 ).
      ENDIF.
      ls_entry-prop = lv_rest.
      APPEND ls_entry TO result.
    ENDLOOP.
    SORT result BY idx.

  ENDMETHOD.


  METHOD split_index.

    "$12$.LABEL -> 12 / .LABEL
    CLEAR: idx, rest.
    DATA(lv_end) = find( val = val sub = `$` off = 1 ).
    IF lv_end < 2.
      RETURN.
    ENDIF.
    idx = to_int( substring( val = val off = 1 len = lv_end - 1 ) ).
    rest = substring( val = val off = lv_end + 1 ).

  ENDMETHOD.


  METHOD get_entry_value.

    READ TABLE it_entries INTO DATA(ls_entry) WITH KEY idx = idx prop = prop.
    IF sy-subrc = 0.
      result = ls_entry-value.
    ENDIF.

  ENDMETHOD.


  METHOD to_int.

    DATA(lv_val) = strip_quotes( val ).
    IF lv_val IS INITIAL OR lv_val CN `0123456789-`.
      RETURN.
    ENDIF.
    TRY.
        result = lv_val.
      CATCH cx_root.
        result = 0.
    ENDTRY.

  ENDMETHOD.


  METHOD is_true.
    result = xsdbool( to_lower( strip_quotes( val ) ) = `true` ).
  ENDMETHOD.


  METHOD read_raw_annotations.

    DATA(lv_name) = to_upper( entity_name ).
    READ TABLE gt_cache INTO DATA(ls_cache) WITH KEY name = lv_name.
    IF sy-subrc = 0.
      result = ls_cache-raw.
      RETURN.
    ENDIF.

    TRY.
        result = read_annos_effective( lv_name ).
        result-with_metadata_extensions = abap_true.
      CATCH cx_root.
        result = read_annos_direct( lv_name ).
    ENDTRY.
    APPEND VALUE #( name = lv_name raw = result ) TO gt_cache.

  ENDMETHOD.


  METHOD read_annos_effective.

    "GET_ANNOS( entityname, metadata_extension, IMPORTING entity_annos,
    "element_annos ) - called dynamically with the parameter types read from
    "RTTI, so nothing here depends on the type names of the service
    DATA lo_type TYPE REF TO cl_abap_datadescr.
    DATA lr_entity TYPE REF TO data.
    DATA lr_element TYPE REF TO data.
    DATA lv_entity TYPE ddstrucobjname.
    DATA lv_mde TYPE abap_bool VALUE abap_true.
    FIELD-SYMBOLS <lt_annos> TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_any> TYPE any.

    CONSTANTS lc_service TYPE string VALUE `CL_DD_DDL_ANNOTATION_SERVICE`.
    CONSTANTS lc_method  TYPE string VALUE `GET_ANNOS`.

    lv_entity = entity_name.
    DATA(lo_class) = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_name( lc_service ) ).

    lo_class->get_method_parameter_type(
      EXPORTING
        p_method_name       = lc_method
        p_parameter_name    = `ENTITY_ANNOS`
      RECEIVING
        p_descr_ref         = lo_type
      EXCEPTIONS
        parameter_not_found = 1
        method_not_found    = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_param_not_found.
    ENDIF.
    CREATE DATA lr_entity TYPE HANDLE lo_type.

    lo_class->get_method_parameter_type(
      EXPORTING
        p_method_name       = lc_method
        p_parameter_name    = `ELEMENT_ANNOS`
      RECEIVING
        p_descr_ref         = lo_type
      EXCEPTIONS
        parameter_not_found = 1
        method_not_found    = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_dyn_call_param_not_found.
    ENDIF.
    CREATE DATA lr_element TYPE HANDLE lo_type.

    DATA(lt_param) = VALUE abap_parmbind_tab(
      ( name  = `ENTITYNAME`
        kind  = cl_abap_objectdescr=>exporting
        value = REF #( lv_entity ) )
      ( name  = `METADATA_EXTENSION`
        kind  = cl_abap_objectdescr=>exporting
        value = REF #( lv_mde ) )
      ( name  = `ENTITY_ANNOS`
        kind  = cl_abap_objectdescr=>importing
        value = lr_entity )
      ( name  = `ELEMENT_ANNOS`
        kind  = cl_abap_objectdescr=>importing
        value = lr_element ) ).

    CALL METHOD (lc_service)=>(lc_method)
      PARAMETER-TABLE lt_param.

    ASSIGN lr_entity->* TO <lt_annos>.
    LOOP AT <lt_annos> ASSIGNING FIELD-SYMBOL(<ls_anno>).
      DATA(ls_annotation) = VALUE ty_s_annotation( ).
      ASSIGN COMPONENT `ANNONAME` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_annotation-key = <lv_any>.
      ASSIGN COMPONENT `VALUE` OF STRUCTURE <ls_anno> TO <lv_any>.
      IF sy-subrc = 0.
        ls_annotation-value = <lv_any>.
      ENDIF.
      APPEND ls_annotation TO result-entity.
    ENDLOOP.

    ASSIGN lr_element->* TO <lt_annos>.
    LOOP AT <lt_annos> ASSIGNING <ls_anno>.
      DATA(ls_el_anno) = VALUE ty_s_element_annotation( ).
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

    DATA(lv_entity) = CONV ddstrucobjname( entity_name ).

    TRY.
        cl_dd_ddl_annotation_service=>get_direct_annos_4_entity(
          EXPORTING entityname = lv_entity
          IMPORTING annos      = DATA(lt_entity_annos) ).
        LOOP AT lt_entity_annos INTO DATA(ls_ea).
          APPEND VALUE ty_s_annotation( key   = CONV string( ls_ea-annoname )
                                        value = CONV string( ls_ea-value ) ) TO result-entity.
        ENDLOOP.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    TRY.
        DATA(lo_descr) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        LOOP AT lo_descr->get_components( ) INTO DATA(ls_comp).
          cl_dd_ddl_annotation_service=>get_direct_annos_4_element(
            EXPORTING
              entityname  = lv_entity
              elementname = CONV ddfieldname_l( ls_comp-name )
            IMPORTING
              annos       = DATA(lt_annos) ).
          LOOP AT lt_annos INTO DATA(ls_anno).
            APPEND VALUE ty_s_element_annotation( element = ls_comp-name
                                                  key     = CONV string( ls_anno-annoname )
                                                  value   = CONV string( ls_anno-value ) ) TO result-elements.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD get_ddic_fields.

    "the DDIC field list carries the key flags and the data element texts;
    "a type that is not a DDIC type (abstract entities in some releases,
    "local types) has none, and then keys come from the semantic key
    TRY.
        IF io_struct->is_ddic_type( ) = abap_true.
          io_struct->get_ddic_field_list(
            RECEIVING
              p_field_list = result
            EXCEPTIONS
              not_found    = 1
              no_ddic_type = 2
              OTHERS       = 3 ).
          IF sy-subrc <> 0.
            CLEAR result.
          ENDIF.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD read_entity_annotations.

    DATA(ls_raw) = read_raw_annotations( entity_name ).
    result-name = to_upper( entity_name ).
    apply_annotations( EXPORTING it_entity   = ls_raw-entity
                                 it_elements = VALUE #( )
                       CHANGING  cs_entity   = result ).

  ENDMETHOD.


  METHOD read_field_annotations.

    DATA(lv_field) = to_upper( field_name ).
    DATA(ls_raw) = read_raw_annotations( entity_name ).
    LOOP AT ls_raw-elements INTO DATA(ls_el).
      IF to_upper( ls_el-element ) = lv_field.
        APPEND VALUE ty_s_annotation( key = ls_el-key value = ls_el-value ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_key_fields.
    result = read_entity( entity_name )-keys.
  ENDMETHOD.


  METHOD get_all_annotations.

    DATA(ls_raw) = read_raw_annotations( entity_name ).
    LOOP AT ls_raw-entity INTO DATA(ls_ea).
      APPEND VALUE ty_s_annotation( key   = |ENTITY.{ ls_ea-key }|
                                    value = ls_ea-value ) TO result.
    ENDLOOP.
    LOOP AT ls_raw-elements INTO DATA(ls_el).
      APPEND VALUE ty_s_annotation( key   = |{ to_upper( ls_el-element ) }.{ ls_el-key }|
                                    value = ls_el-value ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD is_size_category_xs.

    DATA(ls_raw) = read_raw_annotations( entity_name ).
    LOOP AT ls_raw-entity INTO DATA(ls_anno).
      IF to_upper( ls_anno-key ) CS `OBJECTMODEL.RESULTSET.SIZECATEGORY` AND ls_anno-value CS `XS`.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD literal.

    "the value as an ABAP SQL literal of the field's type: quotes doubled,
    "dates and times in their internal form, a decimal comma as a point
    result = value.
    CASE is_field-type_kind.
      WHEN `DATS` OR `TIMS`.
        result = normalize_value( result ).
      WHEN `DEC` OR `INT` OR `FLTP`.
        REPLACE ALL OCCURRENCES OF `,` IN result WITH `.`.
        CONDENSE result NO-GAPS.
    ENDCASE.
    result = replace( val = result sub = `'` with = `''` occ = 0 ).
    result = |'{ result }'|.

  ENDMETHOD.


  METHOD build_filter_condition.

    DATA lt_or TYPE string_table.
    DATA(lv_name) = is_field-name.
    DATA(lv_text_field) = xsdbool( is_field-type_kind = `CHAR` ).

    SPLIT value AT `;` INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts INTO DATA(lv_part).
      CONDENSE lv_part.
      IF lv_part IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_cond) = ``.
      DATA(lv_not) = abap_false.
      IF lv_part(1) = `!`.
        lv_not = abap_true.
        lv_part = substring( val = lv_part off = 1 ).
        IF lv_part IS INITIAL.
          CONTINUE.
        ENDIF.
      ENDIF.

      IF lv_part CS `..`.
        SPLIT lv_part AT `..` INTO DATA(lv_low) DATA(lv_high).
        lv_cond = |{ lv_name } BETWEEN { literal( is_field = is_field value = lv_low ) }| &&
                  | AND { literal( is_field = is_field value = lv_high ) }|.
      ELSEIF strlen( lv_part ) > 2 AND ( lv_part(2) = `>=` OR lv_part(2) = `<=` ).
        lv_cond = |{ lv_name } { lv_part(2) } { literal( is_field = is_field value = substring( val = lv_part off = 2 ) ) }|.
      ELSEIF strlen( lv_part ) > 1 AND ( lv_part(1) = `>` OR lv_part(1) = `<` ).
        lv_cond = |{ lv_name } { lv_part(1) } { literal( is_field = is_field value = substring( val = lv_part off = 1 ) ) }|.
      ELSEIF strlen( lv_part ) > 1 AND lv_part(1) = `=`.
        lv_cond = |{ lv_name } = { literal( is_field = is_field value = substring( val = lv_part off = 1 ) ) }|.
      ELSEIF lv_text_field = abap_true.
        "LIKE: the user's * is the wildcard, their own % and _ are escaped
        DATA(lv_like) = lv_part.
        lv_like = replace( val = lv_like sub = `#` with = `##` occ = 0 ).
        lv_like = replace( val = lv_like sub = `%` with = `#%` occ = 0 ).
        lv_like = replace( val = lv_like sub = `_` with = `#_` occ = 0 ).
        lv_like = replace( val = lv_like sub = `'` with = `''` occ = 0 ).
        IF lv_like CS `*`.
          lv_like = replace( val = lv_like sub = `*` with = `%` occ = 0 ).
        ELSE.
          lv_like = |%{ lv_like }%|.
        ENDIF.
        lv_cond = |{ lv_name } LIKE '{ lv_like }' ESCAPE '#'|.
      ELSE.
        lv_cond = |{ lv_name } = { literal( is_field = is_field value = lv_part ) }|.
      ENDIF.

      IF lv_not = abap_true.
        lv_cond = |NOT ( { lv_cond } )|.
      ENDIF.
      APPEND lv_cond TO lt_or.
    ENDLOOP.

    IF lt_or IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( lt_or ) = 1.
      result = lt_or[ 1 ].
      RETURN.
    ENDIF.
    result = |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )|.

  ENDMETHOD.


  METHOD build_search_condition.

    DATA lt_or TYPE string_table.
    DATA(lv_search) = to_upper( condense( search ) ).
    IF lv_search IS INITIAL.
      RETURN.
    ENDIF.
    lv_search = replace( val = lv_search sub = `#` with = `##` occ = 0 ).
    lv_search = replace( val = lv_search sub = `%` with = `#%` occ = 0 ).
    lv_search = replace( val = lv_search sub = `_` with = `#_` occ = 0 ).
    lv_search = replace( val = lv_search sub = `'` with = `''` occ = 0 ).
    lv_search = replace( val = lv_search sub = `*` with = `%` occ = 0 ).

    DATA(lv_only_searchable) = xsdbool( line_exists( it_fields[ is_searchable = abap_true ] ) ).
    LOOP AT it_fields INTO DATA(ls_field)
      WHERE type_kind = `CHAR` AND is_hidden = abap_false.
      IF lv_only_searchable = abap_true AND ls_field-is_searchable = abap_false.
        CONTINUE.
      ENDIF.
      APPEND |UPPER( { ls_field-name } ) LIKE '%{ lv_search }%' ESCAPE '#'| TO lt_or.
    ENDLOOP.

    IF lt_or IS NOT INITIAL.
      result = |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )|.
    ENDIF.

  ENDMETHOD.


  METHOD selection_filter_to_where.

    DATA lt_and TYPE string_table.

    "split at AND as a word, outside of quotes - the values are simple
    "tokens in practice, a quoted AND is not supported
    DATA(lv_filter) = condense( filter ).
    REPLACE ALL OCCURRENCES OF ` and ` IN lv_filter WITH ` AND ` IGNORING CASE.
    SPLIT lv_filter AT ` AND ` INTO TABLE DATA(lt_parts).

    LOOP AT lt_parts INTO DATA(lv_part).
      CONDENSE lv_part.
      SPLIT lv_part AT ` ` INTO DATA(lv_field) DATA(lv_op) DATA(lv_value).
      lv_field = to_upper( lv_field ).
      lv_op = to_upper( lv_op ).
      READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = lv_field.
      IF sy-subrc <> 0 OR lv_value IS INITIAL.
        CLEAR result.
        RETURN.
      ENDIF.
      DATA(lv_sql_op) = SWITCH string( lv_op
        WHEN `EQ` THEN `=`
        WHEN `NE` THEN `<>`
        WHEN `GT` THEN `>`
        WHEN `GE` THEN `>=`
        WHEN `LT` THEN `<`
        WHEN `LE` THEN `<=` ).
      IF lv_sql_op IS INITIAL.
        CLEAR result.
        RETURN.
      ENDIF.
      APPEND |{ ls_field-name } { lv_sql_op } { literal( is_field = ls_field value = strip_quotes( condense( lv_value ) ) ) }|
        TO lt_and.
    ENDLOOP.

    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD criticality_by_calculation.

    DATA lv_dev_low TYPE decfloat34.
    DATA lv_tol_low TYPE decfloat34.
    DATA lv_tol_high TYPE decfloat34.
    DATA lv_dev_high TYPE decfloat34.

    "a threshold given as a path to another field is not supported - and a
    "failed conversion is not something to rely on (the JS runtime answers
    "one without raising), so the text is checked first
    LOOP AT VALUE string_table( ( is_calc-deviation_low ) ( is_calc-tolerance_low )
                                ( is_calc-tolerance_high ) ( is_calc-deviation_high ) ) INTO DATA(lv_threshold).
      IF condense( lv_threshold ) CN `0123456789.-+eE`.
        RETURN.
      ENDIF.
    ENDLOOP.

    TRY.
        IF is_calc-deviation_low IS NOT INITIAL.
          lv_dev_low = is_calc-deviation_low.
        ENDIF.
        IF is_calc-tolerance_low IS NOT INITIAL.
          lv_tol_low = is_calc-tolerance_low.
        ENDIF.
        IF is_calc-tolerance_high IS NOT INITIAL.
          lv_tol_high = is_calc-tolerance_high.
        ENDIF.
        IF is_calc-deviation_high IS NOT INITIAL.
          lv_dev_high = is_calc-deviation_high.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    CASE to_upper( is_calc-improvement_direction ).
      WHEN `MAXIMIZE`.
        IF is_calc-tolerance_low IS INITIAL.
          RETURN.
        ENDIF.
        result = COND #( WHEN value >= lv_tol_low THEN 3
                         WHEN is_calc-deviation_low IS NOT INITIAL AND value >= lv_dev_low THEN 2
                         WHEN is_calc-deviation_low IS INITIAL THEN 2
                         ELSE 1 ).
      WHEN `MINIMIZE`.
        IF is_calc-tolerance_high IS INITIAL.
          RETURN.
        ENDIF.
        result = COND #( WHEN value <= lv_tol_high THEN 3
                         WHEN is_calc-deviation_high IS NOT INITIAL AND value <= lv_dev_high THEN 2
                         WHEN is_calc-deviation_high IS INITIAL THEN 2
                         ELSE 1 ).
      WHEN `TARGET`.
        IF is_calc-tolerance_low IS INITIAL OR is_calc-tolerance_high IS INITIAL.
          RETURN.
        ENDIF.
        IF value >= lv_tol_low AND value <= lv_tol_high.
          result = 3.
        ELSEIF is_calc-deviation_low IS NOT INITIAL AND is_calc-deviation_high IS NOT INITIAL
          AND ( value < lv_dev_low OR value > lv_dev_high ).
          result = 1.
        ELSE.
          result = 2.
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  METHOD normalize_value.
    result = val.
    REPLACE ALL OCCURRENCES OF `-` IN result WITH ``.
    REPLACE ALL OCCURRENCES OF `:` IN result WITH ``.
    CONDENSE result.
  ENDMETHOD.


  METHOD strip_quotes.
    result = val.
    CONDENSE result.
    IF result IS NOT INITIAL.
      IF result(1) = `'`.
        result = result+1.
      ENDIF.
      DATA(lv_len) = strlen( result ) - 1.
      IF lv_len >= 0 AND result+lv_len(1) = `'`.
        result = result(lv_len).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD detect_boolean.
    DATA(lv_rel_name) = io_elem->get_relative_name( ).
    result = xsdbool( lv_rel_name = `ABAP_BOOLEAN` OR lv_rel_name = `XSDBOOLEAN`
                   OR lv_rel_name = `BOOLE_D`      OR lv_rel_name = `XFELD`
                   OR lv_rel_name = `ABAP_BOOL`    OR lv_rel_name = `FLAG`
                   OR lv_rel_name = `BOOLEAN`      OR lv_rel_name = `XFLAG` ).
  ENDMETHOD.


  METHOD read_associations.
    result = read_associations_level( entity_name = to_upper( entity_name )
                                      level       = 1 ).
  ENDMETHOD.


  METHOD read_associations_level.

    READ TABLE gt_assoc_cache INTO DATA(ls_cache) WITH KEY name = entity_name.
    IF sy-subrc = 0.
      result = ls_cache-associations.
      RETURN.
    ENDIF.

    DATA(ls_parsed) = parse_ddl_associations( read_ddl_source( entity_name ) ).
    result = ls_parsed-associations.

    "a projection: what it does not redirect it exposes as the base has it
    IF ls_parsed-base IS NOT INITIAL AND level < 4.
      merge_base_associations( EXPORTING it_base  = read_associations_level( entity_name = ls_parsed-base
                                                                             level       = level + 1 )
                               CHANGING  ct_assoc = result ).
    ENDIF.

    "a composition names no ON condition - the child's association to
    "parent does. Only one level down, so two entities that point at each
    "other end here
    IF level < 3.
      LOOP AT result ASSIGNING FIELD-SYMBOL(<ls_assoc>)
        WHERE is_composition = abap_true AND conditions IS INITIAL.
        <ls_assoc>-conditions = get_parent_conditions(
          it_child_assoc = read_associations_level( entity_name = <ls_assoc>-target
                                                    level       = level + 1 )
          parent         = entity_name ).
      ENDLOOP.
    ENDIF.

    IF level = 1.
      APPEND VALUE #( name = entity_name associations = result ) TO gt_assoc_cache.
    ENDIF.

  ENDMETHOD.


  METHOD read_ddl_source.

    "dynamic on purpose: the tables are not in every release, and a static
    "SELECT on one that is missing would keep the class from activating
    DATA lv_ddlname TYPE string.
    DATA(lv_table) = `DDDDLSRC`.
    DATA(lv_where) = |DDLNAME = @ENTITY_NAME AND AS4LOCAL = 'A'|.
    TRY.
        SELECT SINGLE ('SOURCE') FROM (lv_table)
          WHERE (lv_where)
          INTO @result.
        IF sy-subrc = 0.
          RETURN.
        ENDIF.
        "an entity whose DDL source has another name
        lv_table = `DDLDEPENDENCY`.
        lv_where = |OBJECTNAME = @ENTITY_NAME AND STATE = 'A'|.
        SELECT SINGLE ('DDLNAME') FROM (lv_table)
          WHERE (lv_where)
          INTO @lv_ddlname.
        IF sy-subrc <> 0 OR lv_ddlname = entity_name.
          RETURN.
        ENDIF.
        lv_table = `DDDDLSRC`.
        lv_where = |DDLNAME = @LV_DDLNAME AND AS4LOCAL = 'A'|.
        SELECT SINGLE ('SOURCE') FROM (lv_table)
          WHERE (lv_where)
          INTO @result.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD tokenize_ddl.

    DATA lv_token TYPE string.
    DATA(lv_length) = strlen( source ).
    DATA(lv_pos) = 0.

    WHILE lv_pos < lv_length.
      DATA(lv_char) = substring( val = source off = lv_pos len = 1 ).
      DATA(lv_next) = ``.
      IF lv_pos + 1 < lv_length.
        lv_next = substring( val = source off = lv_pos + 1 len = 1 ).
      ENDIF.

      "a comment: // to the end of the line, /* to */
      IF lv_char = `/` AND ( lv_next = `/` OR lv_next = `*` ).
        IF lv_token IS NOT INITIAL.
          APPEND lv_token TO result.
          CLEAR lv_token.
        ENDIF.
        IF lv_next = `/`.
          DATA(lv_end) = find( val = source sub = cl_abap_char_utilities=>newline off = lv_pos ).
          lv_pos = COND #( WHEN lv_end < 0 THEN lv_length ELSE lv_end + 1 ).
        ELSE.
          lv_end = find( val = source sub = `*/` off = lv_pos + 2 ).
          lv_pos = COND #( WHEN lv_end < 0 THEN lv_length ELSE lv_end + 2 ).
        ENDIF.
        CONTINUE.
      ENDIF.

      "a literal is one token, whatever it contains
      IF lv_char = `'`.
        IF lv_token IS NOT INITIAL.
          APPEND lv_token TO result.
          CLEAR lv_token.
        ENDIF.
        lv_end = find( val = source sub = `'` off = lv_pos + 1 ).
        IF lv_end < 0.
          lv_end = lv_length - 1.
        ENDIF.
        APPEND substring( val = source off = lv_pos len = lv_end - lv_pos + 1 ) TO result.
        lv_pos = lv_end + 1.
        CONTINUE.
      ENDIF.

      IF lv_char = ` ` OR lv_char = cl_abap_char_utilities=>newline
        OR lv_char = cl_abap_char_utilities=>cr_lf(1)
        OR lv_char = cl_abap_char_utilities=>horizontal_tab.
        IF lv_token IS NOT INITIAL.
          APPEND lv_token TO result.
          CLEAR lv_token.
        ENDIF.
      ELSEIF lv_char CA `[]{}(),;:=`.
        IF lv_token IS NOT INITIAL.
          APPEND lv_token TO result.
          CLEAR lv_token.
        ENDIF.
        APPEND lv_char TO result.
      ELSE.
        lv_token = lv_token && lv_char.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_token IS NOT INITIAL.
      APPEND lv_token TO result.
    ENDIF.

  ENDMETHOD.


  METHOD parse_ddl_associations.

    DATA(lt_tokens) = tokenize_ddl( source ).
    DATA(lv_count) = lines( lt_tokens ).
    "upper case once - the names are compared and returned upper case
    LOOP AT lt_tokens ASSIGNING FIELD-SYMBOL(<lv_token>).
      <lv_token> = to_upper( <lv_token> ).
    ENDLOOP.

    DATA(lv_idx) = 1.
    WHILE lv_idx <= lv_count.
      DATA(lv_token) = lt_tokens[ lv_idx ].

      "as projection on BASE
      IF lv_token = `PROJECTION` AND lv_idx + 2 <= lv_count AND lt_tokens[ lv_idx + 1 ] = `ON`.
        result-base = lt_tokens[ lv_idx + 2 ].
        lv_idx = lv_idx + 3.
        CONTINUE.
      ENDIF.

      "_Alias : redirected to [composition child | parent] TARGET
      IF lv_idx + 3 <= lv_count AND lt_tokens[ lv_idx + 1 ] = `:`
        AND lt_tokens[ lv_idx + 2 ] = `REDIRECTED` AND lt_tokens[ lv_idx + 3 ] = `TO`.
        DATA(ls_redirect) = VALUE ty_s_association( name = lv_token ).
        lv_idx = lv_idx + 4.
        IF lv_idx + 1 <= lv_count AND lt_tokens[ lv_idx ] = `COMPOSITION` AND lt_tokens[ lv_idx + 1 ] = `CHILD`.
          ls_redirect-is_composition = abap_true.
          lv_idx = lv_idx + 2.
        ELSEIF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `PARENT`.
          ls_redirect-is_to_parent = abap_true.
          lv_idx = lv_idx + 1.
        ENDIF.
        IF lv_idx <= lv_count.
          ls_redirect-target = lt_tokens[ lv_idx ].
          DELETE result-associations WHERE name = ls_redirect-name.
          APPEND ls_redirect TO result-associations.
        ENDIF.
        lv_idx = lv_idx + 1.
        CONTINUE.
      ENDIF.

      IF lv_token <> `ASSOCIATION` AND lv_token <> `COMPOSITION`.
        lv_idx = lv_idx + 1.
        CONTINUE.
      ENDIF.

      DATA(ls_assoc) = VALUE ty_s_association( is_composition = xsdbool( lv_token = `COMPOSITION` ) ).
      lv_idx = lv_idx + 1.

      "[0..*] - the cardinality in brackets
      IF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `[`.
        WHILE lv_idx <= lv_count AND lt_tokens[ lv_idx ] <> `]`.
          lv_idx = lv_idx + 1.
        ENDWHILE.
        lv_idx = lv_idx + 1.
      ENDIF.
      "of many to one, of exact one to many - the cardinality in words
      IF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `OF`.
        lv_idx = lv_idx + 1.
        WHILE lv_idx <= lv_count
          AND ( lt_tokens[ lv_idx ] = `EXACT` OR lt_tokens[ lv_idx ] = `ONE`
             OR lt_tokens[ lv_idx ] = `MANY` OR lt_tokens[ lv_idx ] = `TO` ).
          lv_idx = lv_idx + 1.
        ENDWHILE.
      ENDIF.
      IF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `TO`.
        lv_idx = lv_idx + 1.
      ENDIF.
      IF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `PARENT`.
        ls_assoc-is_to_parent = abap_true.
        lv_idx = lv_idx + 1.
      ENDIF.
      IF lv_idx + 2 > lv_count OR lt_tokens[ lv_idx + 1 ] <> `AS`.
        "not a declaration this parser knows - e.g. the word in a comment
        "that survived, or an annotation value
        CONTINUE.
      ENDIF.
      ls_assoc-target = lt_tokens[ lv_idx ].
      ls_assoc-name = lt_tokens[ lv_idx + 2 ].
      lv_idx = lv_idx + 3.

      IF lv_idx <= lv_count AND lt_tokens[ lv_idx ] = `ON`.
        lv_idx = lv_idx + 1.
        DATA lt_condition TYPE string_table.
        CLEAR lt_condition.
        WHILE lv_idx <= lv_count.
          lv_token = lt_tokens[ lv_idx ].
          IF lv_token = `ASSOCIATION` OR lv_token = `COMPOSITION` OR lv_token = `{`
            OR lv_token = `}` OR lv_token = `WHERE` OR lv_token = `GROUP` OR lv_token = `UNION`
            OR lv_token = `WITH` OR lv_token = `,` OR lv_token = `;`.
            EXIT.
          ENDIF.
          APPEND lv_token TO lt_condition.
          lv_idx = lv_idx + 1.
        ENDWHILE.
        ls_assoc-conditions = parse_on_condition( it_tokens = lt_condition
                                                  alias     = ls_assoc-name ).
      ENDIF.

      DELETE result-associations WHERE name = ls_assoc-name.
      APPEND ls_assoc TO result-associations.
    ENDWHILE.

  ENDMETHOD.


  METHOD parse_on_condition.

    "a = b AND c = d - every comparison of two fields; one with a literal,
    "a session variable or another operator is no field pair and left out
    DATA(lv_prefix) = |{ alias }.|.
    DATA(lv_prefix_length) = strlen( lv_prefix ).
    DATA(lv_count) = lines( it_tokens ).
    DATA(lv_idx) = 1.

    WHILE lv_idx + 2 <= lv_count.
      IF it_tokens[ lv_idx + 1 ] <> `=`.
        lv_idx = lv_idx + 1.
        CONTINUE.
      ENDIF.
      DATA(lv_left) = it_tokens[ lv_idx ].
      DATA(lv_right) = it_tokens[ lv_idx + 2 ].
      lv_idx = lv_idx + 3.

      "the target's side is the one that starts with the alias
      DATA(lv_target) = ``.
      DATA(lv_local) = ``.
      IF strlen( lv_left ) > lv_prefix_length AND substring( val = lv_left len = lv_prefix_length ) = lv_prefix.
        lv_target = substring( val = lv_left off = lv_prefix_length ).
        lv_local = lv_right.
      ELSEIF strlen( lv_right ) > lv_prefix_length AND substring( val = lv_right len = lv_prefix_length ) = lv_prefix.
        lv_target = substring( val = lv_right off = lv_prefix_length ).
        lv_local = lv_left.
      ELSE.
        CONTINUE.
      ENDIF.

      "$projection.Field, Source.Field or Field - the field is the last part
      IF lv_local(1) = `'` OR lv_local(1) = `#` OR lv_local CS `$SESSION` OR lv_local CS `$PARAMETERS`
        OR lv_local CO `0123456789.-`.
        CONTINUE.
      ENDIF.
      DATA(lv_dot) = find( val = lv_local sub = `.` occ = -1 ).
      IF lv_dot >= 0.
        lv_local = substring( val = lv_local off = lv_dot + 1 ).
      ENDIF.
      IF lv_local IS INITIAL OR lv_target IS INITIAL OR lv_target CS `.`.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( local = lv_local target = lv_target ) TO result.
    ENDWHILE.

  ENDMETHOD.


  METHOD merge_base_associations.

    LOOP AT it_base INTO DATA(ls_base).
      READ TABLE ct_assoc ASSIGNING FIELD-SYMBOL(<ls_own>) WITH KEY name = ls_base-name.
      IF sy-subrc <> 0.
        APPEND ls_base TO ct_assoc.
        CONTINUE.
      ENDIF.
      IF <ls_own>-conditions IS INITIAL.
        <ls_own>-conditions = ls_base-conditions.
      ENDIF.
      IF <ls_own>-is_composition = abap_false AND <ls_own>-is_to_parent = abap_false.
        <ls_own>-is_composition = ls_base-is_composition.
        <ls_own>-is_to_parent = ls_base-is_to_parent.
      ENDIF.
      IF <ls_own>-target IS INITIAL.
        <ls_own>-target = ls_base-target.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_parent_conditions.

    DATA(lv_parent) = to_upper( parent ).
    LOOP AT it_child_assoc INTO DATA(ls_assoc) WHERE is_to_parent = abap_true AND target = lv_parent.
      LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
        APPEND VALUE #( local = ls_condition-target target = ls_condition-local ) TO result.
      ENDLOOP.
      RETURN.
    ENDLOOP.

  ENDMETHOD.

  METHOD json_escape.
    result = val.
    result = replace( val = result sub = `\` with = `\\` occ = 0 ).
    result = replace( val = result sub = `"` with = `\"` occ = 0 ).
    result = replace( val = result sub = cl_abap_char_utilities=>cr_lf(1) with = `\r` occ = 0 ).
    result = replace( val = result sub = cl_abap_char_utilities=>newline with = `\n` occ = 0 ).
    result = replace( val = result sub = cl_abap_char_utilities=>horizontal_tab with = `\t` occ = 0 ).
  ENDMETHOD.

ENDCLASS.
