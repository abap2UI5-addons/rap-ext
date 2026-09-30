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
        label     TYPE string,
      END OF ty_s_field_group.

    TYPES ty_t_field_group TYPE STANDARD TABLE OF ty_s_field_group WITH DEFAULT KEY.

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

    "! align ABAP and JSON model representations of a key value: dates
    "! (2024-01-15), times (12:30:00), padding
    CLASS-METHODS normalize_value
      IMPORTING
        val           TYPE string
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
        WHEN `CONSUMPTION.FILTER.DEFAULTVALUE`.
          cs_field-filter_default = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.QUALIFIER`.
          cs_field-datapoint_qualifier = strip_quotes( lv_val ).
        WHEN `UI.DATAPOINT.CRITICALITY`.
          cs_field-datapoint_crit_field = to_upper( strip_quotes( lv_val ) ).
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
        label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) ) ).
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
      IF get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ) NS `FOR_ACTION`.
        CONTINUE.
      ENDIF.
      DATA(ls_action) = VALUE ty_s_action(
        name     = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `DATAACTION` ) ) )
        label    = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        position = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        source   = source
        inline   = is_true( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `INLINE` ) ) ).
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
      WHEN `DEC` OR `INT`.
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

ENDCLASS.
