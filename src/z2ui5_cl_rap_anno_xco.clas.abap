"! The metadata of a CDS entity through the released XCO API - the reader
"! for ABAP Cloud, where CL_DD_DDL_ANNOTATION_SERVICE, DDDDLSRC and the
"! DDIC field list are not released (added 2026-10, third round).
"!
"! read_annotations returns what z2ui5_cl_rap_util=>read_raw_annotations
"! returns from GET_ANNOS: one flat key per annotation value in the same
"! form (UI.LINEITEM$1$.POSITION / 10, a string in quotes, an enum with #),
"! for the entity and each of its fields. The sources are XCO's annotation
"! classes (XCO_CP_CDS=&gt;ANNOTATIONS): DIRECT, METADATA_EXTENSION (every
"! metadata extension of the entity, its layers already merged by the
"! system - the 2305 API set has no content of a single extension) and
"! INHERITED (what an element takes over from its data source), put
"! together by z2ui5_cl_rap_util=&gt;merge_annotation_layers: the
"! extensions over the entity's own over the inherited ones. Where
"! INHERITED answers nothing, a projection view takes the direct element
"! annotations of the entity it projects, by the original names of its
"! fields - unless the entity says
"! Metadata.ignorePropagatedAnnotations: true.
"!
"! The walk of an annotation value (IF_XCO_CDS_ANN_VT_VISITOR, implemented
"! by an instance of this class) is recorded as events, which
"! z2ui5_cl_rap_util=&gt;flatten_annotation turns into the keys - that part
"! is unit-tested there; this class only asks XCO. read_ddl_source writes
"! the associations, compositions, the projection's base and its
"! redirections as DDL, for z2ui5_cl_rap_util's association parser;
"! read_fixed_values reads a domain's fixed values.
"!
"! z2ui5_cl_rap_util names this class by a literal and calls it
"! dynamically, so a system without the XCO API only loses this reader.
"! Not verified in a system by an automated gate - see docs/system-test.md.
CLASS z2ui5_cl_rap_anno_xco DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES if_xco_cds_ann_vt_visitor.

    "! the annotations of an entity and its fields, merged - empty when
    "! XCO does not know the entity
    CLASS-METHODS read_annotations
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_raw_annotations.

    "! the declarations of a view entity or a projection view that
    "! z2ui5_cl_rap_util=&gt;parse_ddl_associations reads, written as DDL:
    "! as projection on BASE, association [m..n] to [parent] T as _A on
    "! COND, composition [m..n] of T as _C and the select list with its
    "! redirections - empty for any other entity
    CLASS-METHODS read_ddl_source
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! the fixed values of the domain of a data element - name the value,
    "! value its description; an interval is left out
    CLASS-METHODS read_fixed_values
      IMPORTING
        data_element  TYPE clike
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_name_value.

  PROTECTED SECTION.

  PRIVATE SECTION.

    "! the walk of one annotation value
    DATA mt_events TYPE z2ui5_cl_rap_util=>ty_t_anno_event.

    "! the flat keys of a list of annotations
    CLASS-METHODS flatten
      IMPORTING
        it_annotations TYPE sxco_t_cds_annotations
      RETURNING
        VALUE(result)  TYPE z2ui5_cl_rap_util=>ty_t_annotation.

    "! the annotations one annotation class of XCO has for the entity and
    "! each of its fields
    CLASS-METHODS read_layer
      IMPORTING
        io_class      TYPE REF TO cl_xco_cds_ann_class
        io_entity     TYPE REF TO if_xco_cds_entity
        it_fields     TYPE sxco_t_cds_fields
        layer         TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_anno_layer.

    "! the direct element annotations of the entity a projection view
    "! projects, under the names of the projection's fields - empty for
    "! any other entity
    CLASS-METHODS read_base_elements
      IMPORTING
        entity_name   TYPE sxco_cds_object_name
        it_fields     TYPE sxco_t_cds_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_element_annotation.

    "! key flag and data element label of each field
    CLASS-METHODS read_ddic_fields
      IMPORTING
        it_fields     TYPE sxco_t_cds_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_ddic_field.

    "! projection view or view entity - else empty
    CLASS-METHODS get_entity_kind
      IMPORTING
        io_entity     TYPE REF TO if_xco_cds_entity
      RETURNING
        VALUE(result) TYPE string.

    "! [min..max] - * for an open upper bound
    CLASS-METHODS cardinality_text
      IMPORTING
        min           TYPE i
        max           TYPE i
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.



CLASS z2ui5_cl_rap_anno_xco IMPLEMENTATION.

  METHOD read_annotations.

    DATA lt_layers TYPE z2ui5_cl_rap_util=>ty_t_anno_layer.
    DATA lt_fields TYPE sxco_t_cds_fields.

    DATA(lv_name) = CONV sxco_cds_object_name( to_upper( entity_name ) ).
    DATA(lo_entity) = xco_cp_cds=>entity( lv_name ).
    IF lo_entity->if_xco_ar_object~exists( ) = abap_false.
      RETURN.
    ENDIF.
    TRY.
        lt_fields = lo_entity->fields->all->get( ).
      CATCH cx_root.
        CLEAR lt_fields.
    ENDTRY.

    DATA(ls_direct) = read_layer( io_class  = xco_cp_cds=>annotations->direct
                                  io_entity = lo_entity
                                  it_fields = lt_fields
                                  layer     = z2ui5_cl_rap_util=>cs_anno_layer-direct ).
    APPEND ls_direct TO lt_layers.

    TRY.
        APPEND read_layer( io_class  = xco_cp_cds=>annotations->metadata_extension
                           io_entity = lo_entity
                           it_fields = lt_fields
                           layer     = z2ui5_cl_rap_util=>cs_anno_layer-metadata_extension ) TO lt_layers.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    "propagation: element annotations only, and not where the entity
    "switches it off
    IF NOT line_exists( ls_direct-entity[ key = `METADATA.IGNOREPROPAGATEDANNOTATIONS` value = `true` ] ).
      DATA(ls_propagated) = VALUE z2ui5_cl_rap_util=>ty_s_anno_layer(
        layer = z2ui5_cl_rap_util=>cs_anno_layer-propagated ).
      TRY.
          ls_propagated-elements = read_layer( io_class  = xco_cp_cds=>annotations->inherited
                                               io_entity = lo_entity
                                               it_fields = lt_fields
                                               layer     = ls_propagated-layer )-elements.
        CATCH cx_root.
          CLEAR ls_propagated-elements.
      ENDTRY.
      IF ls_propagated-elements IS INITIAL.
        ls_propagated-elements = read_base_elements( entity_name = lv_name
                                                     it_fields   = lt_fields ).
      ENDIF.
      APPEND ls_propagated TO lt_layers.
    ENDIF.

    result = z2ui5_cl_rap_util=>merge_annotation_layers( lt_layers ).
    result-ddic_fields = read_ddic_fields( lt_fields ).
    result-reader = z2ui5_cl_rap_util=>cs_anno_reader-xco.

  ENDMETHOD.


  METHOD read_layer.

    result-layer = layer.
    result-entity = flatten( io_class->of( io_entity )->get( ) ).
    LOOP AT it_fields INTO DATA(lo_field).
      DATA(lv_element) = to_upper( lo_field->name ).
      DATA(lt_annos) = flatten( io_class->of( lo_field )->get( ) ).
      LOOP AT lt_annos INTO DATA(ls_anno).
        APPEND VALUE #( element = lv_element
                        key     = ls_anno-key
                        value   = ls_anno-value ) TO result-elements.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD flatten.

    LOOP AT it_annotations INTO DATA(lo_annotation).
      DATA(lo_visitor) = NEW z2ui5_cl_rap_anno_xco( ).
      lo_annotation->get_value( )->traverse( lo_visitor ).
      DATA(lt_flat) = z2ui5_cl_rap_util=>flatten_annotation( property  = lo_annotation->get_property( )
                                                             it_events = lo_visitor->mt_events ).
      APPEND LINES OF lt_flat TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_base_elements.

    DATA lv_base TYPE sxco_cds_object_name.
    DATA lv_original TYPE sxco_cds_field_name.

    TRY.
        DATA(lo_entity) = xco_cp_cds=>entity( entity_name ).
        IF get_entity_kind( lo_entity ) <> `PROJECTION`.
          RETURN.
        ENDIF.
        lv_base = xco_cp_cds=>projection_view( entity_name )->content( )->get_data_source( )-view_entity.
        IF lv_base IS INITIAL.
          RETURN.
        ENDIF.
        DATA(lo_base) = xco_cp_cds=>entity( lv_base ).
        LOOP AT it_fields INTO DATA(lo_field).
          lv_original = lo_field->content( )->get_original_name( ).
          IF lv_original IS INITIAL.
            lv_original = lo_field->name.
          ENDIF.
          DATA(lt_annos) = flatten( xco_cp_cds=>annotations->direct->of( lo_base->field( lv_original ) )->get( ) ).
          LOOP AT lt_annos INTO DATA(ls_anno).
            APPEND VALUE #( element = to_upper( lo_field->name )
                            key     = ls_anno-key
                            value   = ls_anno-value ) TO result.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD read_ddic_fields.

    LOOP AT it_fields INTO DATA(lo_field).
      DATA(ls_field) = VALUE z2ui5_cl_rap_util=>ty_s_ddic_field( fieldname = to_upper( lo_field->name ) ).
      TRY.
          DATA(lo_content) = lo_field->content( ).
          ls_field-keyflag = lo_content->get_key_indicator( ).
          DATA(lo_type) = lo_content->get_type( ).
          IF lo_type IS BOUND AND lo_type->is_data_element( ) = abap_true.
            DATA(lo_dtel) = lo_type->get_data_element( )->content( ).
            ls_field-scrtext_m = condense( lo_dtel->get_medium_field_label( )-text ).
            ls_field-fieldtext = condense( lo_dtel->get_short_description( ) ).
          ENDIF.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
      APPEND ls_field TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_entity_kind.

    TRY.
        DATA(lo_type) = io_entity->get_data_definition( )->get_type( ).
        IF lo_type->value = xco_cp_data_definition=>type->projection_view->value.
          result = `PROJECTION`.
        ELSEIF lo_type->value = xco_cp_data_definition=>type->view_entity->value.
          result = `VIEW_ENTITY`.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD read_ddl_source.

    DATA lt_lines TYPE string_table.
    DATA lv_condition TYPE string.
    DATA lv_alias TYPE string.
    DATA lv_line TYPE string.

    TRY.
        DATA(lv_name) = CONV sxco_cds_object_name( to_upper( entity_name ) ).
        DATA(lo_entity) = xco_cp_cds=>entity( lv_name ).
        IF lo_entity->if_xco_ar_object~exists( ) = abap_false.
          RETURN.
        ENDIF.
        DATA(lv_kind) = get_entity_kind( lo_entity ).

        CASE lv_kind.
          WHEN `PROJECTION`.
            DATA(lv_base) = xco_cp_cds=>projection_view( lv_name )->content( )->get_data_source( )-view_entity.
            APPEND |define view entity { lv_name } as projection on { lv_base }| TO lt_lines.

          WHEN `VIEW_ENTITY`.
            APPEND |define view entity { lv_name } as select from { lv_name }| TO lt_lines.
            DATA(lo_view) = xco_cp_cds=>view_entity( lv_name ).
            LOOP AT lo_view->associations->all->get( ) INTO DATA(lo_assoc).
              DATA(ls_assoc) = lo_assoc->content( )->get( ).
              lv_alias = COND #( WHEN lo_assoc->name IS NOT INITIAL THEN lo_assoc->name ELSE ls_assoc-alias ).
              CLEAR lv_condition.
              IF ls_assoc-condition IS BOUND.
                lv_condition = concat_lines_of( table = ls_assoc-condition->if_xco_text~get_lines( )->value
                                                sep   = ` ` ).
              ENDIF.
              IF ls_assoc-to_parent_indicator = abap_true.
                lv_line = |association to parent |.
              ELSE.
                lv_line = cardinality_text( min = ls_assoc-cardinality-min
                                            max = ls_assoc-cardinality-max ).
                lv_line = |association { lv_line } to |.
              ENDIF.
              lv_line = |{ lv_line }{ ls_assoc-target } as { lv_alias }|.
              IF lv_condition IS NOT INITIAL.
                lv_line = |{ lv_line } on { lv_condition }|.
              ENDIF.
              APPEND lv_line TO lt_lines.
            ENDLOOP.
            LOOP AT lo_view->compositions->all->get( ) INTO DATA(lo_composition).
              DATA(ls_composition) = lo_composition->content( )->get( ).
              lv_line = cardinality_text( min = ls_composition-cardinality-min
                                          max = ls_composition-cardinality-max ).
              APPEND |composition { lv_line } of { lo_composition->target } as { ls_composition-alias }| TO lt_lines.
            ENDLOOP.

          WHEN OTHERS.
            RETURN.
        ENDCASE.

        "the select list - what a projection exposes, and its redirections
        APPEND `{` TO lt_lines.
        LOOP AT lo_entity->fields->all->get( ) INTO DATA(lo_field).
          DATA(ls_content) = VALUE if_xco_cds_field_content=>ts_content( ).
          TRY.
              ls_content = lo_field->content( )->get( ).
            CATCH cx_root.
              CLEAR ls_content.
          ENDTRY.
          IF ls_content-redirected_to_compos_child IS NOT INITIAL.
            lv_line = |{ lo_field->name } : redirected to composition child { ls_content-redirected_to_compos_child },|.
          ELSEIF ls_content-redirected_to_parent IS NOT INITIAL.
            lv_line = |{ lo_field->name } : redirected to parent { ls_content-redirected_to_parent },|.
          ELSEIF ls_content-redirected_to IS NOT INITIAL.
            lv_line = |{ lo_field->name } : redirected to { ls_content-redirected_to },|.
          ELSE.
            lv_line = |{ lo_field->name },|.
          ENDIF.
          APPEND lv_line TO lt_lines.
        ENDLOOP.
        APPEND `}` TO lt_lines.
        result = concat_lines_of( table = lt_lines
                                  sep   = |\n| ).
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD cardinality_text.

    result = |[{ min }..{ COND string( WHEN max <= 0 THEN `*` ELSE |{ max }| ) }]|.

  ENDMETHOD.


  METHOD read_fixed_values.

    TRY.
        DATA(lo_dtel) = xco_cp_abap_dictionary=>data_element( CONV #( to_upper( data_element ) ) ).
        IF lo_dtel->exists( ) = abap_false.
          RETURN.
        ENDIF.
        DATA(lo_type) = lo_dtel->content( )->get_data_type( ).
        IF lo_type->is_domain( ) = abap_false.
          RETURN.
        ENDIF.
        DATA(lo_state) = xco_cp_abap_dictionary=>object_read_state->active_version.
        LOOP AT lo_type->get_domain( )->fixed_values->all->get( lo_state ) INTO DATA(lo_value).
          DATA(ls_value) = lo_value->content( lo_state )->get( ).
          "an interval of the domain is no entry of a list
          IF ls_value-upper_limit IS NOT INITIAL.
            CONTINUE.
          ENDIF.
          APPEND VALUE #( name  = condense( lo_value->lower_limit )
                          value = condense( ls_value-description ) ) TO result.
        ENDLOOP.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~enter_record.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-record ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~leave_record.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-record_end ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~enter_array.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-array ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~leave_array.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-array_end ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_name.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-name
                    text = iv_name ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_string.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-string
                    text = io_string->value ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_enum.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-enum
                    text = io_enum->value ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_number.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-number
                    text = io_number->get_source( ) ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_boolean.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-boolean
                    text = COND #( WHEN io_boolean->value = abap_true THEN `true` ELSE `false` ) ) TO mt_events.
  ENDMETHOD.


  METHOD if_xco_cds_ann_vt_visitor~visit_null.
    APPEND VALUE #( kind = z2ui5_cl_rap_util=>cs_anno_event-null ) TO mt_events.
  ENDMETHOD.

ENDCLASS.
