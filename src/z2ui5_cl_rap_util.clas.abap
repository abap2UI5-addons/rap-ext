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

    TYPES:
      "! a name and its value - the same as z2ui5_cl_rap_floorplan's, here so
      "! that this class needs no other class of the addon
      BEGIN OF ty_s_name_value,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_name_value.

    TYPES ty_t_name_value TYPE STANDARD TABLE OF ty_s_name_value WITH DEFAULT KEY.

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
        "added 2026-10, third round (display): the text element of the
        "value help entity's element - the text of a dropdown entry - and
        "the fixed values of the field's domain, the value help of a field
        "without an annotated one (name the value, value its text)
        text_element       TYPE string,
        fixed_values       TYPE ty_t_name_value,
      END OF ty_s_value_help.

    " one @UI.lineItem entry of a field that is no action (added 2026-10,
    " third round) - the unqualified and the qualified ones; a qualified
    " @UI.lineItem is the table of a presentation variant that names it
    TYPES:
      BEGIN OF ty_s_line_item,
        qualifier           TYPE string,
        position            TYPE i,
        label               TYPE string,
        importance          TYPE string,
        criticality         TYPE string,
        crit_representation TYPE string,
        "STANDARD, AS_FIELDGROUP, WITH_URL, ...
        type                TYPE string,
        "#AS_FIELDGROUP: the field group the cell shows
        value_qualifier     TYPE string,
        "hidden: #(Field) - the field whose value hides the cell
        hidden              TYPE string,
        "cssDefault.width
        width               TYPE string,
        icon_url            TYPE string,
      END OF ty_s_line_item.

    TYPES ty_t_line_item TYPE STANDARD TABLE OF ty_s_line_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_field_group,
        qualifier TYPE string,
        position  TYPE i,
        "the field's label within the group (@UI.fieldGroup.label)
        label     TYPE string,
        "the group's title (@UI.fieldGroup.groupLabel) - added 2026-10
        group_label TYPE string,
        "added 2026-10, third round (display): the entry's criticality (a
        "field, upper case, or a number), criticalityRepresentation
        "(WITH_ICON, WITHOUT_ICON), importance (HIGH, MEDIUM, LOW) and
        "hidden (TRUE, or the field whose value hides it per record)
        criticality         TYPE string,
        crit_representation TYPE string,
        importance          TYPE string,
        hidden              TYPE string,
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
        "added 2026-10, third round: every @UI.identification entry that
        "is no action, with its qualifier (empty for the unqualified one),
        "position and label - is_identification and identification_pos
        "stay the unqualified entry's
        identifications           TYPE ty_t_field_group,
        "added 2026-10, third round (reading): a virtual element
        "(@ObjectModel.virtualElementCalculatedBy, the class without its
        "ABAP: prefix) - no database column, calculated after each read -
        "and the classes that let it be sorted or filtered
        "(@ObjectModel.sort.transformedBy, .filter.transformedBy)
        is_virtual                TYPE abap_bool,
        virtual_calc_class        TYPE string,
        sort_transform_class      TYPE string,
        filter_transform_class    TYPE string,
        "@Search.fuzzinessThreshold - read, the search stays a LIKE
        search_fuzziness          TYPE string,
        "added 2026-10, third round (files): @Semantics.largeObject - the
        "field holds a file (a RAWSTRING); the fields of its MIME type and
        "file name, the MIME types it accepts (image/png, image/*) and how
        "it is opened (contentDispositionPreference: INLINE, ATTACHMENT).
        "is_mime_type: the field is the MIME type of one (@Semantics.mimeType)
        is_large_object           TYPE abap_bool,
        lob_mime_field            TYPE string,
        lob_file_name_field       TYPE string,
        lob_mime_types            TYPE string_table,
        lob_disposition           TYPE string,
        is_mime_type              TYPE abap_bool,
        "added 2026-10, third round (filter bar, table, display): of the
        "unqualified @UI.lineItem entry - cssDefault.width, the
        "criticalityRepresentation (WITH_ICON, WITHOUT_ICON), the field
        "group of an #AS_FIELDGROUP column (valueQualifier), hidden: #(Field)
        "(the field that hides the cell per row) and iconUrl
        line_item_width           TYPE string,
        line_item_crit_repr       TYPE string,
        line_item_value_qualifier TYPE string,
        line_item_hidden          TYPE string,
        line_item_icon_url        TYPE string,
        "every @UI.lineItem entry that is no action, the qualified ones
        "included (get_line_item_columns)
        line_items                TYPE ty_t_line_item,
        "@Semantics.imageUrl: the value is the URL of an image
        is_image_url              TYPE abap_bool,
        "@ObjectModel.text.association: the association whose target holds
        "the text (@Semantics.text, in the logon language by
        "@Semantics.language)
        text_association          TYPE string,
        is_semantic_text          TYPE abap_bool,
        is_language               TYPE abap_bool,
        "@Consumption.hidden: not offered anywhere - no column, no filter
        is_consumption_hidden     TYPE abap_bool,
        "@Consumption.semanticObject: the value navigates to that semantic
        "object; the bindings of @Consumption.semanticObjectMapping and of a
        "lineItem's semanticObjectBinding name the parameters (element) the
        "fields (local_element) fill
        semantic_object           TYPE string,
        sem_object_bindings       TYPE ty_t_additional_binding,
        "what the entry of a @UI.fieldGroup or @UI.identification the field
        "is shown by says (set by the object page from field_groups or
        "identifications): its criticality, its representation, its
        "importance and its hidden
        entry_criticality         TYPE string,
        entry_crit_repr           TYPE string,
        entry_importance          TYPE string,
        entry_hidden              TYPE string,
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
        "added 2026-10, third round: @UI.headerInfo.typeImageUrl - the
        "image (a URL or sap-icon://) when the record has none of its own
        type_image_url   TYPE string,
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
        "added 2026-10, third round:
        "the qualifier of the entry - a qualified @UI.identification or a
        "@UI.fieldGroup (source FIELDGROUP) puts the action at the section
        "of that qualifier instead of the header
        qualifier           TYPE string,
        "the criticality of the button: 0-3, #POSITIVE/#NEGATIVE/#CRITICAL,
        "or the field that holds it (upper case)
        criticality         TYPE string,
        "the action group (#FOR_ACTION_GROUP) the action belongs to - a menu
        group_id            TYPE string,
        "ISOLATED (one request per row) or CHANGE_SET (one for all, the
        "default)
        invocation_grouping TYPE string,
        "added 2026-10, third round (navigation): semanticObjectBinding of
        "a #FOR_INTENT_BASED_NAVIGATION entry - the parameters (element)
        "the selected rows' fields (local_element) fill
        sem_object_bindings TYPE ty_t_additional_binding,
      END OF ty_s_action.

    TYPES ty_t_action TYPE STANDARD TABLE OF ty_s_action WITH DEFAULT KEY.

    " an entry of type #FOR_ACTION_GROUP: the menu button its actions
    " (ty_s_action-group_id) are put into - added 2026-10, third round
    TYPES:
      BEGIN OF ty_s_action_group,
        id        TYPE string,
        label     TYPE string,
        position  TYPE i,
        source    TYPE string,
        qualifier TYPE string,
      END OF ty_s_action_group.

    TYPES ty_t_action_group TYPE STANDARD TABLE OF ty_s_action_group WITH EMPTY KEY.

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
        "added 2026-10, third round: groupBy - the fields the table groups
        "its rows by
        group_by                TYPE string_table,
      END OF ty_s_presentation_variant.

    TYPES ty_t_presentation_variant TYPE STANDARD TABLE OF ty_s_presentation_variant WITH EMPTY KEY.

    " one @UI.selectionVariant - filter is its filter string
    " ('Status EQ O AND Priority GT 2'), see selection_filter_to_where
    TYPES:
      BEGIN OF ty_s_selection_variant,
        qualifier TYPE string,
        text      TYPE string,
        filter    TYPE string,
        "added 2026-10, third round: the selectOptions - per field (name)
        "its ranges in the filter syntax (value, conditions_to_filter)
        select_options TYPE ty_t_name_value,
      END OF ty_s_selection_variant.

    TYPES ty_t_selection_variant TYPE STANDARD TABLE OF ty_s_selection_variant WITH DEFAULT KEY.

    " one @UI.selectionPresentationVariant (added 2026-10, third round):
    " which presentation and which selection variant a list starts with
    TYPES:
      BEGIN OF ty_s_sel_pres_variant,
        qualifier              TYPE string,
        text                   TYPE string,
        presentation_qualifier TYPE string,
        selection_qualifier    TYPE string,
      END OF ty_s_sel_pres_variant.

    TYPES ty_t_sel_pres_variant TYPE STANDARD TABLE OF ty_s_sel_pres_variant WITH EMPTY KEY.

    " one condition of the "define conditions" dialog (added 2026-10, third
    " round): an operator of cs_condition_op, its values and whether it
    " excludes - conditions_to_filter writes it in the filter syntax,
    " filter_to_conditions reads it back
    TYPES:
      BEGIN OF ty_s_condition,
        operator TYPE string,
        low      TYPE string,
        high     TYPE string,
        exclude  TYPE abap_bool,
      END OF ty_s_condition.

    TYPES ty_t_condition TYPE STANDARD TABLE OF ty_s_condition WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF cs_condition_op,
        eq          TYPE string VALUE `EQ`,
        ne          TYPE string VALUE `NE`,
        bt          TYPE string VALUE `BT`,
        gt          TYPE string VALUE `GT`,
        ge          TYPE string VALUE `GE`,
        lt          TYPE string VALUE `LT`,
        le          TYPE string VALUE `LE`,
        contains    TYPE string VALUE `CONTAINS`,
        starts_with TYPE string VALUE `STARTS_WITH`,
        ends_with   TYPE string VALUE `ENDS_WITH`,
        empty       TYPE string VALUE `EMPTY`,
      END OF cs_condition_op.

    " the control of a field in the filter bar (get_filter_control)
    CONSTANTS:
      BEGIN OF cs_filter_control,
        input      TYPE string VALUE `INPUT`,
        "a Select of fixed entries - a boolean, fixed values, a dropdown
        list       TYPE string VALUE `LIST`,
        date       TYPE string VALUE `DATE`,
        date_range TYPE string VALUE `DATE_RANGE`,
        "a MultiInput with a token per value - a field with a value help
        multi      TYPE string VALUE `MULTI`,
      END OF cs_filter_control.

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
        "the names of the source's select list that start with _ - what a
        "projection exposes of its base
        exposed      TYPE string_table,
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
        "added 2026-10, third round
        "the #FOR_ACTION_GROUP entries - the menus of the actions
        action_groups         TYPE ty_t_action_group,
        "@UI.createHidden, .updateHidden, .deleteHidden: TRUE, empty (not
        "hidden), or the field whose value decides (upper case)
        create_hidden         TYPE string,
        update_hidden         TYPE string,
        delete_hidden         TYPE string,
        "added 2026-10, third round (reading): the query provider of a
        "custom entity (@ObjectModel.query.implementedBy, without ABAP:)
        query_class           TYPE string,
        "added 2026-10, third round (table): the criticality of a row - the
        "field of the entity-level @UI.lineItem's criticality - and the
        "groupBy of the default @UI.presentationVariant
        row_criticality       TYPE string,
        group_by              TYPE string_table,
        "every @UI.selectionPresentationVariant
        sel_pres_variants TYPE ty_t_sel_pres_variant,
      END OF ty_s_entity_info.

    "======= READING TYPES (added 2026-10, third round) =======

    " one line of a range - the shape of IF_RAP_QUERY_FILTER's ranges
    TYPES:
      BEGIN OF ty_s_range_option,
        sign   TYPE c LENGTH 1,
        option TYPE c LENGTH 2,
        low    TYPE string,
        high   TYPE string,
      END OF ty_s_range_option.

    TYPES ty_t_range_option TYPE STANDARD TABLE OF ty_s_range_option WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_name_range,
        name  TYPE string,
        range TYPE ty_t_range_option,
      END OF ty_s_name_range.

    TYPES ty_t_name_range TYPE STANDARD TABLE OF ty_s_name_range WITH EMPTY KEY.

    " what a query provider is asked for (build_query_filter): the filter
    " as ABAP SQL and as ranges, and the free-text search apart from it
    TYPES:
      BEGIN OF ty_s_query_filter,
        "the WHERE without the search, host variables as literals
        sql       TYPE string,
        ranges    TYPE ty_t_name_range,
        "the filter is no AND of one range per field - get_as_ranges raises
        no_ranges TYPE abap_bool,
        "the search term (* as wildcard), from build_search_condition's part
        search    TYPE string,
      END OF ty_s_query_filter.

    " a virtual element and the classes of its SADL exits
    TYPES:
      BEGIN OF ty_s_virtual_element,
        name         TYPE string,
        calc_class   TYPE string,
        sort_class   TYPE string,
        filter_class TYPE string,
      END OF ty_s_virtual_element.

    TYPES ty_t_virtual_element TYPE STANDARD TABLE OF ty_s_virtual_element WITH EMPTY KEY.

    " how the rows of an entity are read (get_read_info): through a query
    " provider (a custom entity), or by ABAP SQL with the virtual elements
    " calculated afterwards
    TYPES:
      BEGIN OF ty_s_read_info,
        query_class      TYPE string,
        virtual_elements TYPE ty_t_virtual_element,
      END OF ty_s_read_info.

    " one group of aggregate_rows
    TYPES:
      BEGIN OF ty_s_aggregate,
        group_key TYPE string,
        value     TYPE decfloat34,
        row_count TYPE int8,
      END OF ty_s_aggregate.

    TYPES ty_t_aggregate TYPE STANDARD TABLE OF ty_s_aggregate WITH EMPTY KEY.

    "======= RAP BEHAVIOUR TYPES (added 2026-10, third round) =======

    " the control of one field as GET PERMISSIONS answers it - static
    " (field ( readonly ), readonly : update, mandatory : create) and
    " instance feature control alike
    TYPES:
      BEGIN OF ty_s_perm_field,
        name             TYPE string,
        read_only        TYPE abap_bool,
        read_only_update TYPE abap_bool,
        mandatory        TYPE abap_bool,
        mandatory_create TYPE abap_bool,
      END OF ty_s_perm_field.

    TYPES ty_t_perm_field TYPE STANDARD TABLE OF ty_s_perm_field WITH EMPTY KEY.

    " one action or association (create by association) - enabled is
    " abap_false when it is disabled or unauthorized
    TYPES:
      BEGIN OF ty_s_perm_op,
        name    TYPE string,
        enabled TYPE abap_bool,
      END OF ty_s_perm_op.

    TYPES ty_t_perm_op TYPE STANDARD TABLE OF ty_s_perm_op WITH EMPTY KEY.

    " the permissions of the entity (global) or of one instance (its keys)
    TYPES:
      BEGIN OF ty_s_perm_set,
        keys         TYPE ty_t_name_value,
        can_create   TYPE abap_bool,
        can_update   TYPE abap_bool,
        can_delete   TYPE abap_bool,
        actions      TYPE ty_t_perm_op,
        associations TYPE ty_t_perm_op,
        fields       TYPE ty_t_perm_field,
      END OF ty_s_perm_set.

    TYPES ty_t_perm_set TYPE STANDARD TABLE OF ty_s_perm_set WITH EMPTY KEY.

    " what GET PERMISSIONS answered - answered is abap_false when it could
    " not be asked (no RAP, the statement's class did not activate), and
    " then everything the derived types offer is allowed
    TYPES:
      BEGIN OF ty_s_permissions,
        answered  TYPE abap_bool,
        global    TYPE ty_s_perm_set,
        instances TYPE ty_t_perm_set,
      END OF ty_s_permissions.

    " how a field is shown in edit mode (get_field_control)
    TYPES:
      BEGIN OF ty_s_field_control,
        read_only TYPE abap_bool,
        mandatory TYPE abap_bool,
      END OF ty_s_field_control.

    " the draft of a record: state OWN (the user's), LOCKED (another
    " user's, user names who) or empty (none)
    TYPES:
      BEGIN OF ty_s_draft_status,
        state TYPE string,
        user  TYPE string,
      END OF ty_s_draft_status.

    " the values of the editing status filter of a draft business object
    CONSTANTS:
      BEGIN OF cs_editing_status,
        all       TYPE string VALUE `ALL`,
        own_draft TYPE string VALUE `OWN`,
        locked    TYPE string VALUE `LOCKED`,
        unchanged TYPE string VALUE `UNCHANGED`,
      END OF cs_editing_status.

    "======= MESSAGES, FILES, NAVIGATION (added 2026-10, third round) =======

    " one message of a write, as RAP reported it - what
    " z2ui5_cl_rap_floorplan=>ty_s_message is
    TYPES:
      BEGIN OF ty_s_message,
        text   TYPE string,
        "error, warning, success or information
        type   TYPE string,
        "the fields the message is about (%element)
        fields TYPE string_table,
        "the entity the message is about - empty for a message of %other
        target TYPE string,
      END OF ty_s_message.

    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

    " one entry of a sap.m.MessageView (get_message_items)
    TYPES:
      BEGIN OF ty_s_message_item,
        "a sap.ui.core.MessageType: Error, Warning, Success, Information
        type        TYPE string,
        title       TYPE string,
        "the labels of the fields the message is about
        subtitle    TYPE string,
        description TYPE string,
        "the entity - the view groups by it when there are several
        group_name  TYPE string,
      END OF ty_s_message_item.

    TYPES ty_t_message_item TYPE STANDARD TABLE OF ty_s_message_item WITH EMPTY KEY.

    " how messages are shown (get_message_display): nothing, a toast (only
    " success and information), a message box (one message about no field
    " and no entity) or a message view in a dialog (every other case)
    CONSTANTS:
      BEGIN OF cs_message_display,
        none  TYPE string VALUE ``,
        toast TYPE string VALUE `TOAST`,
        box   TYPE string VALUE `BOX`,
        view  TYPE string VALUE `VIEW`,
      END OF cs_message_display.

    " a file the user uploaded, or one to download (parse_data_uri)
    TYPES:
      BEGIN OF ty_s_file,
        mime_type TYPE string,
        file_name TYPE string,
        content   TYPE xstring,
      END OF ty_s_file.

    " why an uploaded file is refused (check_file) - ok is empty
    CONSTANTS:
      BEGIN OF cs_file_check,
        ok        TYPE string VALUE ``,
        empty     TYPE string VALUE `EMPTY`,
        too_large TYPE string VALUE `TOO_LARGE`,
        type      TYPE string VALUE `TYPE`,
      END OF cs_file_check.

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
    "! string: conditions "Field OP Value" joined with AND and OR, grouped
    "! with parentheses (AND binds stronger than OR), OP one of EQ NE GT GE
    "! LT LE (or = &lt;&gt; &gt; &gt;= &lt; &lt;=), the value optionally in
    "! quotes. Empty when the string names a field that it_fields does not
    "! have, an operator it does not know or its parentheses do not match -
    "! a variant that cannot be read restricts nothing wrongly
    CLASS-METHODS selection_filter_to_where
      IMPORTING
        filter        TYPE string
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! The sap.m.ButtonType of an action button by its criticality: 3 or
    "! #POSITIVE Accept, 1 or #NEGATIVE Reject, 2 or #CRITICAL Emphasized,
    "! anything else Default
    CLASS-METHODS criticality_button_type
      IMPORTING
        criticality   TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! Whether an action is static, by the components of a line of its
    "! derived type \ACTION=...\TYPE=IMPORTING: an instance action carries
    "! the instance's key (%KEY, %TKY, %PKY), a static one does not - it runs
    "! without rows, with only %CID and %PARAM
    CLASS-METHODS is_static_action_line
      IMPORTING
        components    TYPE string_table
      RETURNING
        VALUE(result) TYPE abap_bool.

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

    "! A projection inherits the associations of its base that it exposes:
    "! one it does not redirect keeps the base's target, one it redirects
    "! keeps its own target and takes what it lacks (the ON condition, the
    "! kind) from the base. it_exposed empty: every association of the base
    CLASS-METHODS merge_base_associations
      IMPORTING
        it_base    TYPE ty_t_association
        it_exposed TYPE string_table OPTIONAL
      CHANGING
        ct_assoc   TYPE ty_t_association.

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

    "! The rows of data (a table) as CSV: a header line with the labels of
    "! it_fields, then one line per row with the values of those fields -
    "! separated by ;, every value in double quotes (doubled inside), dates
    "! as 2024-01-15, lines ended by CR LF. What spreadsheets open as a table
    CLASS-METHODS to_csv
      IMPORTING
        data          TYPE REF TO data
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! val as UTF-8 bytes, with the byte order mark when bom is set - so a
    "! spreadsheet reads umlauts right
    CLASS-METHODS to_utf8
      IMPORTING
        val           TYPE string
        bom           TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE xstring.

    "! val in Base64 (RFC 4648, with padding)
    CLASS-METHODS base64_encode
      IMPORTING
        val           TYPE xstring
      RETURNING
        VALUE(result) TYPE string.

    "! val percent-encoded for a URL query (UTF-8; letters, digits and
    "! - _ . ~ stay as they are)
    CLASS-METHODS url_encode
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! a percent-encoded URL component as text (UTF-8; + is a blank)
    CLASS-METHODS url_decode
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! the parameters of a URL query (?a=1&b=2), names and values decoded
    CLASS-METHODS parse_url_query
      IMPORTING
        query         TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! val as the content of a JSON string - quotes, backslashes and control
    "! characters escaped
    CLASS-METHODS json_escape
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! How the rows of an entity are read: the query provider of a custom
    "! entity and the virtual elements with their SADL exit classes - from
    "! the annotations, which are cached for the session
    CLASS-METHODS get_read_info
      IMPORTING
        entity_name   TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_read_info.

    "! get_read_info on raw annotations - needs no system
    CLASS-METHODS parse_read_info
      IMPORTING
        it_entity     TYPE ty_t_annotation
        it_elements   TYPE ty_t_element_annotation
      RETURNING
        VALUE(result) TYPE ty_s_read_info.

    "! A WHERE condition (ABAP SQL, as the floorplans build it) as a query
    "! provider is asked for it: the free-text search part
    "! (build_search_condition) apart, the rest as one ABAP SQL string with
    "! the host variables (@&lt;LS_HOST&gt;-name, see host_values) as
    "! literals, and - where the rest is an AND of conditions on one field
    "! each - as ranges (EQ NE LT LE GT GE BT, CP for a LIKE, E for a NOT).
    "! A condition no range can hold (an OR over two fields, a function, a
    "! field twice) sets no_ranges
    CLASS-METHODS build_query_filter
      IMPORTING
        where         TYPE string
        host_values   TYPE ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_query_filter.

    "! an ABAP SQL ORDER BY list (`A DESCENDING, B`) as sort criteria
    CLASS-METHODS parse_order_by
      IMPORTING
        order_by      TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_sort.

    "! sort criteria as an ABAP SQL ORDER BY list
    CLASS-METHODS order_by_to_string
      IMPORTING
        it_sort       TYPE ty_t_sort
      RETURNING
        VALUE(result) TYPE string.

    "! where without its AND-ed conditions that name one of fields - what
    "! ABAP SQL cannot evaluate for a virtual element
    CLASS-METHODS remove_where_fields
      IMPORTING
        where         TYPE string
        fields        TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! a field the user may sort by: no STRING or RAW, and a virtual
    "! element only with @ObjectModel.sort.transformedBy
    CLASS-METHODS is_sortable
      IMPORTING
        is_field      TYPE ty_s_field_info
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! a field the user may filter by: no virtual element - a filter
    "! transformation (@ObjectModel.filter.transformedBy) is not called
    CLASS-METHODS is_filterable
      IMPORTING
        is_field      TYPE ty_s_field_info
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! The rows of data (a table) grouped by the component group_by (none:
    "! one group), with method (SUM AVG MIN MAX COUNT) over the component
    "! measure - sorted by the group's key. What a custom entity's
    "! aggregates are computed with, as ABAP SQL cannot read it
    CLASS-METHODS aggregate_rows
      IMPORTING
        data          TYPE REF TO data
        group_by      TYPE string OPTIONAL
        measure       TYPE string OPTIONAL
        method        TYPE string DEFAULT `SUM`
      RETURNING
        VALUE(result) TYPE ty_t_aggregate.

    "! One field permission of GET PERMISSIONS (IF_ABAP_BEHV=>PERM-F,
    "! as an integer): mandatory 1, read-only 2, mandatory on create 16,
    "! read-only on update 32 - the flags combine (added 2026-10, third
    "! round)
    CLASS-METHODS decode_field_permission
      IMPORTING
        name          TYPE string
        value         TYPE i
      RETURNING
        VALUE(result) TYPE ty_s_perm_field.

    "! an operation permission (IF_ABAP_BEHV=>PERM-O, as an integer):
    "! enabled is 0, disabled 1, unauthorized 2
    CLASS-METHODS is_operation_enabled
      IMPORTING
        value         TYPE i
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the absolute names a BDEF derived type of GET PERMISSIONS may have
    "! - kind KEY (TABLE FOR PERMISSIONS KEY), REQUEST or RESULT (the
    "! STRUCTURE FOR PERMISSIONS ones), in the order they are tried. The
    "! names are not documented for these types; the forms follow those
    "! of READ (READ_I, READ_R) - see docs/system-test.md
    CLASS-METHODS get_permission_type_names
      IMPORTING
        bdef          TYPE string
        entity_name   TYPE string
        kind          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the permissions of the instance of keys: the global ones combined
    "! with the instance's - an operation is allowed when both allow it,
    "! a field read-only or mandatory when either says so. Not answered:
    "! everything is allowed
    CLASS-METHODS get_instance_permissions
      IMPORTING
        is_permissions TYPE ty_s_permissions
        keys           TYPE ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result)  TYPE ty_s_perm_set.

    "! the operation name of ops is enabled - one that is not listed is
    CLASS-METHODS is_permitted
      IMPORTING
        ops           TYPE ty_t_perm_op
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! how is_field is edited: read-only by @ObjectModel.readOnly, by the
    "! field control of it_perm_fields (static and instance) and as a key
    "! outside a create - on create a key that the business object numbers
    "! (read-only by its field control, or a UUID) is read-only too;
    "! mandatory by the annotation and the field control, never when
    "! read-only
    CLASS-METHODS get_field_control
      IMPORTING
        is_field       TYPE ty_s_field_info
        it_perm_fields TYPE ty_t_perm_field OPTIONAL
        is_create      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)  TYPE ty_s_field_control.

    "! the draft status of a record: none without a draft, the user's own
    "! when owner (who changed the draft last) is user or unknown, else
    "! locked by owner
    CLASS-METHODS get_draft_status
      IMPORTING
        has_draft     TYPE abap_bool
        owner         TYPE string OPTIONAL
        user          TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_draft_status.

    "! a record of draft status state is shown by the editing status filter
    "! value filter (cs_editing_status; empty is ALL)
    CLASS-METHODS matches_editing_status
      IMPORTING
        filter        TYPE string
        state         TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the field an optimistic check compares before an update: the local
    "! instance last changed time (@Semantics.systemDateTime
    "! .localInstanceLastChangedAt), else the last changed time - what a
    "! BDEF names as etag master in practice. Empty when there is neither
    CLASS-METHODS get_etag_field
      IMPORTING
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! Remove one pair of enclosing single quotes and surrounding blanks
    CLASS-METHODS strip_quotes
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The messages as they are shown: the type in lower case (error,
    "! warning, success, information - anything else is an error), no
    "! empty text, each text and type once, and no success message when
    "! there is an error - the success of a step does not count when the
    "! request failed (added 2026-10, third round)
    CLASS-METHODS prepare_messages
      IMPORTING
        messages      TYPE ty_t_message
      RETURNING
        VALUE(result) TYPE ty_t_message.

    "! how prepared messages are shown (cs_message_display): a toast when
    "! all of them are success or information, a message box for a single
    "! message about no field and no entity (a refusal of the floorplan
    "! itself), else a message view that lists each message with its type,
    "! fields and entity
    CLASS-METHODS get_message_display
      IMPORTING
        messages      TYPE ty_t_message
      RETURNING
        VALUE(result) TYPE string.

    "! the entries of a sap.m.MessageView: the text as title, the labels of
    "! its fields (it_fields, else the field names) as subtitle, the entity
    "! as group, the type as sap.ui.core.MessageType
    CLASS-METHODS get_message_items
      IMPORTING
        messages      TYPE ty_t_message
        it_fields     TYPE ty_t_field_info OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_message_item.

    "! A data URI (data:image/png;base64,....) as a file: its MIME type -
    "! taken from file_name when the URI names none or only
    "! application/octet-stream - and its content. Empty when the URI is
    "! none
    CLASS-METHODS parse_data_uri
      IMPORTING
        uri           TYPE string
        file_name     TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_file.

    "! content as a data URI of mime_type (application/octet-stream when
    "! empty) - what the browser downloads
    CLASS-METHODS to_data_uri
      IMPORTING
        content       TYPE xstring
        mime_type     TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! val decoded from Base64 (RFC 4648; blanks and line breaks skipped)
    CLASS-METHODS base64_decode
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

    "! the MIME type of a file name by its extension - empty when unknown
    CLASS-METHODS mime_from_file_name
      IMPORTING
        file_name     TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! mime_type is one of accepted (@Semantics.largeObject
    "! .acceptableMimeTypes): equal, or of the group of an entry with *
    "! (image/*, */*), case-insensitive. Nothing accepted: every type
    CLASS-METHODS is_mime_type_accepted
      IMPORTING
        mime_type     TYPE string
        accepted      TYPE string_table
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! why a file is refused (cs_file_check): it is empty, larger than
    "! max_size bytes (0: no limit), or not of an accepted type - ok when
    "! it is none of these
    CLASS-METHODS check_file
      IMPORTING
        file          TYPE ty_s_file
        accepted      TYPE string_table OPTIONAL
        max_size      TYPE i DEFAULT 0
      RETURNING
        VALUE(result) TYPE string.

    "! the file extensions of accepted (png,jpg,jpeg) - what the browser's
    "! file dialog offers. Empty, so every file is offered, when a type has
    "! a * or no known extension; the server checks the type anyway
    CLASS-METHODS get_file_extensions
      IMPORTING
        accepted      TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! The inbound parameters of a navigation that name a field of
    "! it_fields - case-insensitive, by the field's name; the name becomes
    "! the field's, a parameter that names none, a virtual element or a
    "! file is left out, and of a field named twice the first value counts.
    "! What z2ui5_cl_rap_start hands a list report as filter values
    CLASS-METHODS match_inbound_parameters
      IMPORTING
        params        TYPE ty_t_name_value
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the files (@Semantics.largeObject fields of it_fields) of every row
    "! of data (a table) cleared - a list does not send them to the browser;
    "! the object page reads its record again with them
    CLASS-METHODS clear_large_objects
      IMPORTING
        data      TYPE REF TO data
        it_fields TYPE ty_t_field_info.

    "======= FILTER BAR, TABLE, DISPLAY (added 2026-10, third round) =======

    "! the conditions of the "define conditions" dialog in the filter
    "! syntax (build_filter_condition): EQ =a, NE !=a, BT a..b, GT >a, GE
    "! >=a, LT &lt;a, LE &lt;=a, contains *a*, starts with a*, ends with *a,
    "! empty =; an excluding condition is prefixed with ! - several are
    "! separated by ;. A condition without a value is left out
    CLASS-METHODS conditions_to_filter
      IMPORTING
        conditions    TYPE ty_t_condition
      RETURNING
        VALUE(result) TYPE string.

    "! a filter value read back into conditions - the dialog shows what the
    "! filter has; a value without an operator is "contains" for a text
    "! field (is_field), "equals" for every other
    CLASS-METHODS filter_to_conditions
      IMPORTING
        value         TYPE string
        is_field      TYPE ty_s_field_info OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_condition.

    "! the parts of a filter value (separated by ;), without blanks around
    "! and without empty ones - the tokens of a MultiInput
    CLASS-METHODS split_filter_value
      IMPORTING
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the control of is_field in the filter bar (cs_filter_control): a
    "! list for a boolean, a field with fixed values or a dropdown value
    "! help; a date picker for a date of a single value, else a date range;
    "! a MultiInput with tokens for a field with a value help that takes
    "! several values; an input with the filter syntax for every other
    CLASS-METHODS get_filter_control
      IMPORTING
        is_field      TYPE ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! the entries of a list filter (get_filter_control LIST): the empty
    "! one (every row), then Yes (=X) and No (=) for a boolean or a filter
    "! value per fixed value - name the filter value, value its text
    CLASS-METHODS get_filter_list
      IMPORTING
        is_field      TYPE ty_s_field_info
        yes           TYPE string
        no            TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! a selection variant as filter values: its selectOptions, and of its
    "! filter string every comparison of an AND of single comparisons - what
    "! cannot be written as a filter value (an OR, parentheses) is where,
    "! for the list to apply as it is
    CLASS-METHODS selection_variant_filters
      IMPORTING
        is_variant TYPE ty_s_selection_variant
        it_fields  TYPE ty_t_field_info
      EXPORTING
        filters    TYPE ty_t_name_value
        where      TYPE string.

    "! the WHERE of a selection variant: its filter string and its
    "! selectOptions - a worklist tab
    CLASS-METHODS selection_variant_where
      IMPORTING
        is_variant    TYPE ty_s_selection_variant
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! the columns of the @UI.lineItem of qualifier, by position: every
    "! field with an entry of it, line_item_pos, label, importance,
    "! criticality and the rest taken from that entry. No qualifier: the
    "! unqualified columns as they are
    CLASS-METHODS get_line_item_columns
      IMPORTING
        it_fields     TYPE ty_t_field_info
        qualifier     TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_field_info.

    "! the binding that maps a criticality field (0-3, 5) to what kind
    "! needs: STATE a sap.ui.core.ValueState (5 Information), ICON the icon
    "! of the criticality, HIGHLIGHT a row's highlight (a MessageType) - a
    "! criticality given as a number is the literal itself
    CLASS-METHODS criticality_binding
      IMPORTING
        criticality   TYPE string
        kind          TYPE string DEFAULT `STATE`
      RETURNING
        VALUE(result) TYPE string.

    "! the parameters of a navigation to a semantic object from row: the
    "! value of field under its own name, else of every binding
    "! (local_element) under the binding's element - empty when row lacks
    "! the field
    CLASS-METHODS get_navigation_params
      IMPORTING
        row           TYPE data
        bindings      TYPE ty_t_additional_binding
        field         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! a column width as UI5 takes it (sap.ui.core.CSSSize): a number with
    "! px, rem, em or %, auto - a plain number is rem; anything else is
    "! empty, which UI5 would refuse and lose the whole view over
    CLASS-METHODS normalize_css_width
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

    "! the MIME types of the file extensions get_file_extensions and
    "! mime_from_file_name know - name the extension, value the type
    CLASS-METHODS get_mime_map
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

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
        ct_action TYPE ty_t_action
        ct_group  TYPE ty_t_action_group.

    "! the value of @UI.createHidden and its siblings: TRUE, empty (false),
    "! or the field that decides - #(Field), 'Field' or Field, upper case
    CLASS-METHODS hidden_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! entries as annotations again - prop the key - for a get_entries of
    "! an array inside an entry (added 2026-10, third round)
    CLASS-METHODS entries_to_annos
      IMPORTING
        it_entries    TYPE ty_t_entry
      RETURNING
        VALUE(result) TYPE ty_t_annotation.

    "! the bindings (LOCALELEMENT, ELEMENT, USAGE) of the entries of an
    "! array of bindings - additionalBinding, semanticObjectBinding
    CLASS-METHODS get_entry_bindings
      IMPORTING
        it_entries    TYPE ty_t_entry
      RETURNING
        VALUE(result) TYPE ty_t_additional_binding.

    "! the criticality, its representation, the importance and hidden of
    "! the entry idx of a @UI.fieldGroup or @UI.identification
    CLASS-METHODS set_entry_display
      IMPORTING
        it_entries TYPE ty_t_entry
        idx        TYPE i
      CHANGING
        cs_entry   TYPE ty_s_field_group.

    "! one range of a selectOptions entry as a condition
    CLASS-METHODS range_to_condition
      IMPORTING
        sign          TYPE string
        option        TYPE string
        low           TYPE string
        high          TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_condition.

    "! the fixed values of the domain of a data element - empty where the
    "! element has none or the system cannot say (RTTI, called dynamically)
    CLASS-METHODS read_fixed_values
      IMPORTING
        io_elem       TYPE REF TO cl_abap_elemdescr
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    " a token of a selection variant's filter: ( ) AND OR, or a condition
    " already turned into ABAP SQL
    TYPES:
      BEGIN OF ty_s_filter_token,
        kind TYPE string,
        sql  TYPE string,
      END OF ty_s_filter_token.

    TYPES ty_t_filter_token TYPE STANDARD TABLE OF ty_s_filter_token WITH EMPTY KEY.

    "! the tokens of a selection variant's filter - failed when a condition
    "! cannot be read
    CLASS-METHODS selection_filter_tokens
      IMPORTING
        filter    TYPE string
        it_fields TYPE ty_t_field_info
      EXPORTING
        et_tokens TYPE ty_t_filter_token
        failed    TYPE abap_bool.

    "! one condition "Field OP Value" as ABAP SQL - empty when it cannot be
    "! read
    CLASS-METHODS selection_condition_sql
      IMPORTING
        condition     TYPE string
        it_fields     TYPE ty_t_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! an OR of ANDs from the token at index on (recursive descent) - index
    "! is left behind what was read, failed set on a syntax error
    CLASS-METHODS selection_filter_or
      IMPORTING
        it_tokens     TYPE ty_t_filter_token
      CHANGING
        index         TYPE i
        failed        TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS selection_filter_and
      IMPORTING
        it_tokens     TYPE ty_t_filter_token
      CHANGING
        index         TYPE i
        failed        TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.

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

    TYPES ty_t_token_groups TYPE STANDARD TABLE OF string_table WITH EMPTY KEY.

    "! a class named by an annotation: 'ABAP:ZCL_X' as ZCL_X
    CLASS-METHODS annotation_class
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the tokens of an ABAP SQL condition: a quoted literal (its quotes
    "! kept), a host variable (@...), a parenthesis, a comma, an operator
    "! (= &lt;&gt; ...), a word
    CLASS-METHODS tokenize_where
      IMPORTING
        where         TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

    "! the tokens split at the keyword separator (AND, OR) outside of
    "! parentheses - the AND of a BETWEEN stays where it is
    CLASS-METHODS split_tokens
      IMPORTING
        it_tokens     TYPE string_table
        separator     TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_token_groups.

    "! the tokens without the parentheses that enclose all of them
    CLASS-METHODS strip_parentheses
      CHANGING
        ct_tokens TYPE string_table.

    "! the tokens as ABAP SQL again - host variables as literals of their
    "! value where host_values has it
    CLASS-METHODS tokens_to_sql
      IMPORTING
        it_tokens     TYPE string_table
        host_values   TYPE ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! the search term of a condition build_search_condition built - empty
    "! when the tokens are no such condition
    CLASS-METHODS search_term
      IMPORTING
        it_tokens     TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! one condition on one field as a range line - failed when it is none
    CLASS-METHODS condition_to_range
      IMPORTING
        it_tokens   TYPE string_table
        host_values TYPE ty_t_name_value OPTIONAL
      EXPORTING
        name        TYPE string
        range       TYPE ty_s_range_option
        failed      TYPE abap_bool.

    "! the value of a literal token ('a''b' as a'b) or a host variable
    CLASS-METHODS token_value
      IMPORTING
        token       TYPE string
        host_values TYPE ty_t_name_value OPTIONAL
      EXPORTING
        value       TYPE string
        failed      TYPE abap_bool.

    "! a LIKE pattern (% _, escaped by escape) as a CP pattern (* +, #)
    CLASS-METHODS like_to_pattern
      IMPORTING
        pattern       TYPE string
        escape        TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

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
        "the domain's fixed values - the value help of a field without an
        "annotated one (added 2026-10, third round)
        IF ls_field-data_element IS NOT INITIAL AND ls_field-is_boolean = abap_false.
          ls_field-value_help-fixed_values = read_fixed_values( lo_elem ).
        ENDIF.
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
      "the domain's fixed values only where nothing else helps - then a
      "dropdown of them, its key NAME and its text VALUE
      IF <ls_field>-value_help-entity_name IS NOT INITIAL OR <ls_field>-is_boolean = abap_true
        OR <ls_field>-is_hidden = abap_true.
        CLEAR <ls_field>-value_help-fixed_values.
      ELSEIF <ls_field>-value_help-fixed_values IS NOT INITIAL.
        <ls_field>-value_help-is_dropdown = abap_true.
        <ls_field>-value_help-element = `NAME`.
        <ls_field>-value_help-text_element = `VALUE`.
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
        WHEN `UI.HEADERINFO.TYPEIMAGEURL`.
          cs_entity-header_info-type_image_url = strip_quotes( lv_val ).
        WHEN `UI.CREATEHIDDEN`.
          cs_entity-create_hidden = hidden_value( lv_val ).
        WHEN `UI.UPDATEHIDDEN`.
          cs_entity-update_hidden = hidden_value( lv_val ).
        WHEN `UI.DELETEHIDDEN`.
          cs_entity-delete_hidden = hidden_value( lv_val ).
        WHEN `OBJECTMODEL.QUERY.IMPLEMENTEDBY`.
          cs_entity-query_class = annotation_class( lv_val ).
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

    "the entity's own @UI.lineItem: the criticality of its rows (the
    "unqualified entry that names one)
    DATA(lt_row_entries) = get_entries( it_annos = cs_entity-entity_annotations
                                        prefix   = `UI.LINEITEM` ).
    LOOP AT lt_row_entries INTO DATA(ls_row_entry) WHERE prop = `CRITICALITY`.
      IF get_entry_value( it_entries = lt_row_entries idx = ls_row_entry-idx prop = `QUALIFIER` ) IS INITIAL.
        cs_entity-row_criticality = to_upper( strip_quotes( ls_row_entry-value ) ).
        EXIT.
      ENDIF.
    ENDLOOP.

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
                       CHANGING  ct_action = cs_entity-actions
                                 ct_group  = cs_entity-action_groups ).
        parse_actions( EXPORTING it_annos  = lt_field_annos
                                 prefix    = `UI.IDENTIFICATION`
                                 source    = `IDENTIFICATION`
                       CHANGING  ct_action = cs_entity-actions
                                 ct_group  = cs_entity-action_groups ).
        "a #FOR_ACTION entry of a field group - an action at its section
        parse_actions( EXPORTING it_annos  = lt_field_annos
                                 prefix    = `UI.FIELDGROUP`
                                 source    = `FIELDGROUP`
                       CHANGING  ct_action = cs_entity-actions
                                 ct_group  = cs_entity-action_groups ).

        READ TABLE cs_entity-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
          WITH KEY name = lv_element.
        IF sy-subrc = 0.
          parse_field_annotations( EXPORTING it_annos = lt_field_annos
                                   CHANGING  cs_field = <ls_field> ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    SORT cs_entity-facets BY position.
    "by position - an action without one behind the others, in the order
    "of the annotations
    SORT cs_entity-actions STABLE BY source position.
    SORT cs_entity-action_groups STABLE BY source position.

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
        WHEN `OBJECTMODEL.VIRTUALELEMENTCALCULATEDBY`.
          cs_field-virtual_calc_class = annotation_class( lv_val ).
          cs_field-is_virtual = xsdbool( cs_field-virtual_calc_class IS NOT INITIAL ).
        WHEN `OBJECTMODEL.VIRTUALELEMENT`.
          IF is_true( lv_val ).
            cs_field-is_virtual = abap_true.
          ENDIF.
        WHEN `OBJECTMODEL.SORT.TRANSFORMEDBY`.
          cs_field-sort_transform_class = annotation_class( lv_val ).
        WHEN `OBJECTMODEL.FILTER.TRANSFORMEDBY`.
          cs_field-filter_transform_class = annotation_class( lv_val ).
        WHEN `SEARCH.FUZZINESSTHRESHOLD`.
          cs_field-search_fuzziness = strip_quotes( lv_val ).
        WHEN `SEMANTICS.LARGEOBJECT.MIMETYPE`.
          cs_field-is_large_object = abap_true.
          cs_field-lob_mime_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `SEMANTICS.LARGEOBJECT.FILENAME`.
          cs_field-is_large_object = abap_true.
          cs_field-lob_file_name_field = to_upper( strip_quotes( lv_val ) ).
        WHEN `SEMANTICS.LARGEOBJECT.CONTENTDISPOSITIONPREFERENCE`.
          cs_field-is_large_object = abap_true.
          cs_field-lob_disposition = replace( val = strip_quotes( lv_val ) sub = `#` with = `` ).
        WHEN `SEMANTICS.MIMETYPE`.
          cs_field-is_mime_type = is_true( lv_val ).
        WHEN `SEMANTICS.IMAGEURL`.
          cs_field-is_image_url = is_true( lv_val ).
        WHEN `OBJECTMODEL.TEXT.ASSOCIATION`.
          cs_field-text_association = to_upper( strip_quotes( lv_val ) ).
        WHEN `SEMANTICS.TEXT`.
          cs_field-is_semantic_text = is_true( lv_val ).
        WHEN `SEMANTICS.LANGUAGE`.
          cs_field-is_language = is_true( lv_val ).
        WHEN `CONSUMPTION.HIDDEN`.
          IF is_true( lv_val ).
            cs_field-is_consumption_hidden = abap_true.
            cs_field-is_hidden = abap_true.
          ENDIF.
        WHEN `CONSUMPTION.SEMANTICOBJECT`.
          cs_field-semantic_object = strip_quotes( lv_val ).
      ENDCASE.

      "@Semantics.largeObject.acceptableMimeTypes: ['image/png', ...] - an
      "array, or a single value
      IF lv_key CP `SEMANTICS.LARGEOBJECT.ACCEPTABLEMIMETYPES*`.
        cs_field-is_large_object = abap_true.
        DATA(lv_mime) = to_lower( strip_quotes( lv_val ) ).
        IF lv_mime IS NOT INITIAL AND NOT line_exists( cs_field-lob_mime_types[ table_line = lv_mime ] ).
          APPEND lv_mime TO cs_field-lob_mime_types.
        ENDIF.
      ENDIF.

      "@ObjectModel.text.element: ['Name'] - an array of one
      IF lv_key CP `OBJECTMODEL.TEXT.ELEMENT*`.
        cs_field-text_element = to_upper( strip_quotes( lv_val ) ).
      ENDIF.

      "a @UI.dataPoint without its own qualifier is still a data point
      IF lv_key CP `UI.DATAPOINT.*` AND cs_field-datapoint_qualifier IS INITIAL.
        cs_field-datapoint_qualifier = cs_field-name.
      ENDIF.
    ENDLOOP.

    "@Consumption.hidden wins over a later @UI.hidden: false
    IF cs_field-is_consumption_hidden = abap_true.
      cs_field-is_hidden = abap_true.
    ENDIF.

    "@Consumption.semanticObjectMapping.additionalBinding - the parameters
    "of a navigation to the semantic object
    DATA(lt_mapping) = get_entries( it_annos = it_annos
                                    prefix   = `CONSUMPTION.SEMANTICOBJECTMAPPING.ADDITIONALBINDING` ).
    APPEND LINES OF get_entry_bindings( lt_mapping ) TO cs_field-sem_object_bindings.

    "======= @UI.lineItem - every entry that is no action; the columns are =======
    "the unqualified one's (a qualified one is the table of a presentation
    "variant, get_line_item_columns), an entry hidden: true is none
    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = `UI.LINEITEM` ).
    DATA lv_idx TYPE i.
    DATA lt_entry_parts TYPE ty_t_entry.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(lv_type) = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      IF lv_type CS `FOR_ACTION` OR lv_type CS `FOR_INTENT`.
        CONTINUE.
      ENDIF.
      DATA(ls_line_item) = VALUE ty_s_line_item(
        qualifier           = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        position            = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        label               = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        importance          = to_upper( replace( val  = strip_quotes( get_entry_value( it_entries = lt_entries
                                                                                       idx        = lv_idx
                                                                                       prop       = `IMPORTANCE` ) )
                                                 sub  = `#`
                                                 with = `` ) )
        criticality         = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `CRITICALITY` ) ) )
        crit_representation = to_upper( replace( val  = strip_quotes( get_entry_value( it_entries = lt_entries
                                                                                       idx        = lv_idx
                                                                                       prop       = `CRITICALITYREPRESENTATION` ) )
                                                 sub  = `#`
                                                 with = `` ) )
        type                = to_upper( replace( val = strip_quotes( lv_type ) sub = `#` with = `` ) )
        value_qualifier     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `VALUEQUALIFIER` ) )
        hidden              = hidden_value( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `HIDDEN` ) )
        width               = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `CSSDEFAULT.WIDTH` ) )
        icon_url            = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ICONURL` ) ) ).
      IF ls_line_item-hidden = `TRUE` OR line_exists( cs_field-line_items[ qualifier = ls_line_item-qualifier ] ).
        CONTINUE.
      ENDIF.
      IF ls_line_item-position = 0.
        "an entry without a position still makes a column - behind the others
        ls_line_item-position = 9999.
      ENDIF.
      APPEND ls_line_item TO cs_field-line_items.
      IF ls_line_item-qualifier IS NOT INITIAL OR cs_field-line_item_pos > 0.
        CONTINUE.
      ENDIF.
      cs_field-line_item_width = ls_line_item-width.
      cs_field-line_item_crit_repr = ls_line_item-crit_representation.
      cs_field-line_item_value_qualifier = ls_line_item-value_qualifier.
      cs_field-line_item_hidden = ls_line_item-hidden.
      cs_field-line_item_icon_url = ls_line_item-icon_url.
      "semanticObjectBinding of a #WITH_INTENT_BASED_NAVIGATION column
      CLEAR lt_entry_parts.
      LOOP AT lt_entries INTO DATA(ls_binding_part) WHERE idx = lv_idx AND prop CP `SEMANTICOBJECTBINDING*`.
        APPEND ls_binding_part TO lt_entry_parts.
      ENDLOOP.
      APPEND LINES OF get_entry_bindings( get_entries( it_annos = entries_to_annos( lt_entry_parts )
                                                       prefix   = `SEMANTICOBJECTBINDING` ) )
        TO cs_field-sem_object_bindings.
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

    "======= @UI.identification - every entry that is not an action =======
    "is_identification is the unqualified entry - a qualified one belongs
    "to the #IDENTIFICATION_REFERENCE facet of its qualifier only
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
      DATA(ls_ident) = VALUE ty_s_field_group(
        qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        position  = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) ) ).
      set_entry_display( EXPORTING it_entries = lt_entries
                                   idx        = lv_idx
                         CHANGING  cs_entry   = ls_ident ).
      IF ls_ident-hidden = `TRUE` OR line_exists( cs_field-identifications[ qualifier = ls_ident-qualifier ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_ident TO cs_field-identifications.
      IF ls_ident-qualifier IS INITIAL.
        cs_field-is_identification = abap_true.
        cs_field-identification_pos = ls_ident-position.
      ENDIF.
    ENDLOOP.

    "======= @UI.fieldGroup - every entry, one per qualifier =======
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.FIELDGROUP` ).
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      "an action of the group is no field of it (parse_actions)
      lv_type = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      IF lv_type CS `FOR_ACTION` OR lv_type CS `FOR_INTENT`.
        CONTINUE.
      ENDIF.
      DATA(ls_group) = VALUE ty_s_field_group(
        qualifier = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        position  = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) )
        label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        group_label = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `GROUPLABEL` ) ) ).
      set_entry_display( EXPORTING it_entries = lt_entries
                                   idx        = lv_idx
                         CHANGING  cs_entry   = ls_group ).
      IF ls_group-qualifier IS INITIAL OR ls_group-hidden = `TRUE`
        OR line_exists( cs_field-field_groups[ qualifier = ls_group-qualifier ] ).
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

    DATA lt_binding_parts TYPE ty_t_entry.
    DATA(lt_entries) = get_entries( it_annos = it_annos prefix = prefix ).
    DATA lv_idx TYPE i.
    LOOP AT lt_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(lv_type) = get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TYPE` ).
      DATA(lv_qualifier) = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) ).
      DATA(lv_position) = to_int( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `POSITION` ) ).
      IF lv_position = 0.
        "an entry without a position behind the others - as a column
        lv_position = 9999.
      ENDIF.

      "a menu of actions: its id (id or actionGroupId) and label
      IF lv_type CS `FOR_ACTION_GROUP`.
        DATA(ls_group) = VALUE ty_s_action_group(
          id        = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ID` ) ) )
          label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
          position  = lv_position
          source    = source
          qualifier = lv_qualifier ).
        IF ls_group-id IS INITIAL.
          ls_group-id = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ACTIONGROUPID` ) ) ).
        ENDIF.
        IF ls_group-id IS INITIAL OR line_exists( ct_group[ id = ls_group-id source = source ] ).
          CONTINUE.
        ENDIF.
        IF ls_group-label IS INITIAL.
          ls_group-label = ls_group-id.
        ENDIF.
        APPEND ls_group TO ct_group.
        CONTINUE.
      ENDIF.

      IF lv_type NS `FOR_ACTION` AND lv_type NS `FOR_INTENT_BASED_NAVIGATION`.
        CONTINUE.
      ENDIF.
      DATA(ls_action) = VALUE ty_s_action(
        name      = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `DATAACTION` ) ) )
        label     = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `LABEL` ) )
        position  = lv_position
        source    = source
        inline    = is_true( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `INLINE` ) )
        qualifier = lv_qualifier
        group_id  = to_upper( strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `ACTIONGROUPID` ) ) ) ).
      "#ISOLATED, #CHANGE_SET - and the criticality: a number, #POSITIVE ...
      "or a field, all upper case without the #
      DATA(lv_grouping) = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `INVOCATIONGROUPING` ) ).
      ls_action-invocation_grouping = to_upper( replace( val = lv_grouping sub = `#` with = `` ) ).
      DATA(lv_crit) = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `CRITICALITY` ) ).
      ls_action-criticality = to_upper( replace( val = lv_crit sub = `#` with = `` ) ).
      "a navigation: named after its target, never the name of an action
      IF lv_type CS `FOR_INTENT_BASED_NAVIGATION`.
        ls_action-semantic_object = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECT` ) ).
        ls_action-semantic_action = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `SEMANTICOBJECTACTION` ) ).
        IF ls_action-semantic_object IS INITIAL OR ls_action-semantic_action IS INITIAL.
          CONTINUE.
        ENDIF.
        ls_action-name = to_upper( |INTENT~{ ls_action-semantic_object }~{ ls_action-semantic_action }| ).
        "semanticObjectBinding: the parameters the selected rows fill
        CLEAR lt_binding_parts.
        LOOP AT lt_entries INTO DATA(ls_binding_part) WHERE idx = lv_idx AND prop CP `SEMANTICOBJECTBINDING*`.
          APPEND ls_binding_part TO lt_binding_parts.
        ENDLOOP.
        ls_action-sem_object_bindings = get_entry_bindings( get_entries( it_annos = entries_to_annos( lt_binding_parts )
                                                                         prefix   = `SEMANTICOBJECTBINDING` ) ).
      ENDIF.
      IF ls_action-name IS INITIAL
        OR line_exists( ct_action[ name = ls_action-name source = source qualifier = lv_qualifier ] ).
        CONTINUE.
      ENDIF.
      IF ls_action-label IS INITIAL.
        ls_action-label = ls_action-name.
      ENDIF.
      APPEND ls_action TO ct_action.
    ENDLOOP.

  ENDMETHOD.


  METHOD hidden_value.

    "#(Field) - a path - or 'Field', true or false
    DATA(lv_val) = strip_quotes( val ).
    IF strlen( lv_val ) > 2 AND lv_val(2) = `#(`.
      lv_val = substring( val = lv_val off = 2 ).
      lv_val = replace( val = lv_val sub = `)` with = `` occ = 0 ).
      lv_val = strip_quotes( lv_val ).
    ENDIF.
    lv_val = to_upper( condense( lv_val ) ).
    IF lv_val = `FALSE` OR lv_val = ``.
      RETURN.
    ENDIF.
    result = lv_val.

  ENDMETHOD.


  METHOD criticality_button_type.

    DATA(lv_value) = to_upper( replace( val = strip_quotes( condense( criticality ) ) sub = `#` with = `` ) ).
    result = SWITCH #( lv_value
      WHEN `3` OR `POSITIVE` THEN `Accept`
      WHEN `1` OR `NEGATIVE` THEN `Reject`
      WHEN `2` OR `CRITICAL` THEN `Emphasized`
      ELSE `Default` ).

  ENDMETHOD.


  METHOD is_static_action_line.

    "no line read: nothing says the action is static
    result = xsdbool( components IS NOT INITIAL ).
    LOOP AT components INTO DATA(lv_component).
      DATA(lv_name) = to_upper( lv_component ).
      IF lv_name = `%KEY` OR lv_name = `%TKY` OR lv_name = `%PKY`.
        result = abap_false.
        RETURN.
      ENDIF.
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
    DATA lt_option_parts TYPE ty_t_entry.
    DATA lt_options TYPE ty_t_entry.
    DATA lt_range_parts TYPE ty_t_entry.
    DATA lt_ranges TYPE ty_t_entry.
    DATA lt_conditions TYPE ty_t_condition.
    DATA lv_oidx TYPE i.
    DATA lv_ridx TYPE i.

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
    "its groupBy - the fields the list groups its rows by
    IF lv_idx > 0 AND cs_entity-group_by IS INITIAL.
      LOOP AT lt_entries INTO ls_entry WHERE idx = lv_idx AND prop CP `GROUPBY*`.
        APPEND to_upper( strip_quotes( ls_entry-value ) ) TO cs_entity-group_by.
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
        ELSEIF ls_part-prop CP `GROUPBY*`.
          APPEND to_upper( strip_quotes( ls_part-value ) ) TO ls_variant_pv-group_by.
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
      "selectOptions: SELECTOPTIONS$n$.PROPERTYNAME and its RANGES$m$
      CLEAR lt_option_parts.
      LOOP AT lt_entries INTO DATA(ls_option_part) WHERE idx = lv_idx AND prop CP `SELECTOPTIONS*`.
        APPEND ls_option_part TO lt_option_parts.
      ENDLOOP.
      lt_options = get_entries( it_annos = entries_to_annos( lt_option_parts )
                                prefix   = `SELECTOPTIONS` ).
      CLEAR lv_oidx.
      LOOP AT lt_options INTO DATA(ls_option).
        IF ls_option-idx = lv_oidx.
          CONTINUE.
        ENDIF.
        lv_oidx = ls_option-idx.
        DATA(lv_property) = to_upper( strip_quotes( get_entry_value( it_entries = lt_options
                                                                      idx        = lv_oidx
                                                                      prop       = `PROPERTYNAME` ) ) ).
        CLEAR: lt_range_parts, lt_conditions, lv_ridx.
        LOOP AT lt_options INTO DATA(ls_range_part) WHERE idx = lv_oidx AND prop CP `RANGES*`.
          APPEND ls_range_part TO lt_range_parts.
        ENDLOOP.
        lt_ranges = get_entries( it_annos = entries_to_annos( lt_range_parts )
                                 prefix   = `RANGES` ).
        LOOP AT lt_ranges INTO DATA(ls_range).
          IF ls_range-idx = lv_ridx.
            CONTINUE.
          ENDIF.
          lv_ridx = ls_range-idx.
          APPEND range_to_condition(
            sign   = get_entry_value( it_entries = lt_ranges idx = lv_ridx prop = `SIGN` )
            option = get_entry_value( it_entries = lt_ranges idx = lv_ridx prop = `OPTION` )
            low    = strip_quotes( get_entry_value( it_entries = lt_ranges idx = lv_ridx prop = `LOW` ) )
            high   = strip_quotes( get_entry_value( it_entries = lt_ranges idx = lv_ridx prop = `HIGH` ) ) )
            TO lt_conditions.
        ENDLOOP.
        DATA(lv_option_value) = conditions_to_filter( lt_conditions ).
        IF lv_property IS NOT INITIAL AND lv_option_value IS NOT INITIAL.
          APPEND VALUE #( name = lv_property value = lv_option_value ) TO ls_variant-select_options.
        ENDIF.
      ENDLOOP.
      IF ( ls_variant-filter IS INITIAL AND ls_variant-select_options IS INITIAL )
        OR line_exists( cs_entity-selection_variants[ qualifier = ls_variant-qualifier ] ).
        CONTINUE.
      ENDIF.
      IF ls_variant-text IS INITIAL.
        ls_variant-text = COND #( WHEN ls_variant-qualifier IS NOT INITIAL THEN ls_variant-qualifier
                                  ELSE ls_variant-filter ).
      ENDIF.
      APPEND ls_variant TO cs_entity-selection_variants.
    ENDLOOP.

    "@UI.selectionPresentationVariant - which presentation and selection
    "variant belong together
    lt_entries = get_entries( it_annos = it_annos prefix = `UI.SELECTIONPRESENTATIONVARIANT` ).
    CLEAR lv_idx.
    LOOP AT lt_entries INTO ls_entry.
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_spv) = VALUE ty_s_sel_pres_variant(
        qualifier              = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `QUALIFIER` ) )
        text                   = strip_quotes( get_entry_value( it_entries = lt_entries idx = lv_idx prop = `TEXT` ) )
        presentation_qualifier = strip_quotes( get_entry_value( it_entries = lt_entries
                                                                idx        = lv_idx
                                                                prop       = `PRESENTATIONVARIANTQUALIFIER` ) )
        selection_qualifier    = strip_quotes( get_entry_value( it_entries = lt_entries
                                                                idx        = lv_idx
                                                                prop       = `SELECTIONVARIANTQUALIFIER` ) ) ).
      IF line_exists( cs_entity-sel_pres_variants[ qualifier = ls_spv-qualifier ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_spv TO cs_entity-sel_pres_variants.
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
    DATA lt_not TYPE string_table.
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

      IF lv_part = `=`.
        "= alone: the field is empty (a No of a boolean, the "empty"
        "condition) - added 2026-10, third round
        lv_cond = |{ lv_name } IS INITIAL|.
      ELSEIF lv_part CS `..`.
        SPLIT lv_part AT `..` INTO DATA(lv_low) DATA(lv_high).
        CONDENSE lv_low.
        CONDENSE lv_high.
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

      "an excluding part restricts what the others include - since
      "2026-10, third round it is ANDed, as a condition that excludes is
      "in a filter bar
      IF lv_not = abap_true.
        APPEND |NOT ( { lv_cond } )| TO lt_not.
      ELSE.
        APPEND lv_cond TO lt_or.
      ENDIF.
    ENDLOOP.

    IF lines( lt_or ) > 1.
      INSERT |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )| INTO lt_not INDEX 1.
    ELSEIF lines( lt_or ) = 1.
      INSERT lt_or[ 1 ] INTO lt_not INDEX 1.
    ENDIF.
    IF lt_not IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( lt_not ) = 1.
      result = lt_not[ 1 ].
      RETURN.
    ENDIF.
    result = |( { concat_lines_of( table = lt_not sep = ` AND ` ) } )|.

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

    "a text or string field - a virtual element is no column. A
    "@Search.defaultSearchElement is searched also when it is @UI.hidden
    "(added 2026-10, third round: STRING fields and hidden search
    "elements; @Search.fuzzinessThreshold is read, the search stays a LIKE)
    DATA(lv_only_searchable) = xsdbool( line_exists( it_fields[ is_searchable = abap_true is_virtual = abap_false ] ) ).
    LOOP AT it_fields INTO DATA(ls_field)
      WHERE ( type_kind = `CHAR` OR type_kind = `STRING` ) AND is_virtual = abap_false.
      IF lv_only_searchable = abap_true AND ls_field-is_searchable = abap_false.
        CONTINUE.
      ENDIF.
      IF lv_only_searchable = abap_false AND ls_field-is_hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND |UPPER( { ls_field-name } ) LIKE '%{ lv_search }%' ESCAPE '#'| TO lt_or.
    ENDLOOP.

    IF lt_or IS NOT INITIAL.
      result = |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )|.
    ENDIF.

  ENDMETHOD.


  METHOD selection_filter_to_where.

    DATA lt_tokens TYPE ty_t_filter_token.
    DATA lv_failed TYPE abap_bool.
    DATA lv_index TYPE i VALUE 1.

    selection_filter_tokens( EXPORTING filter    = filter
                                       it_fields = it_fields
                             IMPORTING et_tokens = lt_tokens
                                       failed    = lv_failed ).
    IF lv_failed = abap_true OR lt_tokens IS INITIAL.
      RETURN.
    ENDIF.

    result = selection_filter_or( EXPORTING it_tokens = lt_tokens
                                  CHANGING  index     = lv_index
                                            failed    = lv_failed ).
    "a closing parenthesis too many, or anything left over
    IF lv_failed = abap_true OR lv_index <= lines( lt_tokens ).
      CLEAR result.
    ENDIF.

  ENDMETHOD.


  METHOD selection_filter_tokens.

    DATA lv_condition TYPE string.
    DATA lv_word TYPE string.
    DATA lv_open TYPE abap_bool.
    DATA lv_sql TYPE string.
    DATA lv_closing TYPE i.
    DATA lv_head TYPE string.
    DATA lv_field TYPE string.
    DATA lv_op TYPE string.
    DATA lv_value TYPE string.
    DATA lt_words TYPE string_table.

    CLEAR: et_tokens, failed.

    "words separated by blanks; AND, OR and parentheses outside of a quoted
    "value separate the conditions, a condition is Field OP Value
    DATA(lv_filter) = condense( filter ).
    SPLIT lv_filter AT ` ` INTO TABLE lt_words.
    APPEND `` TO lt_words.
    LOOP AT lt_words INTO lv_word.
      "the end, AND or OR: the condition so far is complete
      DATA(lv_upper) = to_upper( lv_word ).
      IF lv_open = abap_false AND ( lv_word IS INITIAL OR lv_upper = `AND` OR lv_upper = `OR` ).
        IF lv_condition IS NOT INITIAL.
          lv_sql = selection_condition_sql( condition = lv_condition
                                            it_fields = it_fields ).
          IF lv_sql IS INITIAL.
            failed = abap_true.
            RETURN.
          ENDIF.
          APPEND VALUE #( kind = `COND` sql = lv_sql ) TO et_tokens.
          CLEAR lv_condition.
        ENDIF.
        IF lv_word IS NOT INITIAL.
          APPEND VALUE #( kind = lv_upper ) TO et_tokens.
        ENDIF.
        CONTINUE.
      ENDIF.

      "opening parentheses in front of a condition
      WHILE lv_open = abap_false AND lv_condition IS INITIAL
        AND strlen( lv_word ) > 0 AND lv_word(1) = `(`.
        APPEND VALUE #( kind = `(` ) TO et_tokens.
        lv_word = substring( val = lv_word off = 1 ).
      ENDWHILE.
      IF lv_word IS INITIAL.
        CONTINUE.
      ENDIF.

      "closing ones behind it - unless they are inside a quoted value
      CLEAR lv_closing.
      DATA(lv_value_open) = xsdbool( lv_open = abap_true OR ( strlen( lv_word ) > 0 AND lv_word(1) = `'` ) ).
      WHILE strlen( lv_word ) > 0 AND substring( val = lv_word off = strlen( lv_word ) - 1 ) = `)`.
        lv_head = substring( val = lv_word len = strlen( lv_word ) - 1 ).
        "a quoted value ends with its quote, not with the parenthesis
        IF lv_value_open = abap_true
          AND NOT ( strlen( lv_head ) > 0 AND substring( val = lv_head off = strlen( lv_head ) - 1 ) = `'` ).
          EXIT.
        ENDIF.
        lv_word = lv_head.
        lv_closing = lv_closing + 1.
      ENDWHILE.

      IF lv_word IS NOT INITIAL.
        lv_condition = COND #( WHEN lv_condition IS INITIAL THEN lv_word ELSE |{ lv_condition } { lv_word }| ).
      ENDIF.

      "a quoted value is open while it has not ended with its quote
      SPLIT lv_condition AT ` ` INTO lv_field lv_op lv_value.
      lv_open = xsdbool( strlen( lv_value ) > 0 AND lv_value(1) = `'`
                         AND ( strlen( lv_value ) = 1
                               OR substring( val = lv_value off = strlen( lv_value ) - 1 ) <> `'` ) ).

      IF lv_closing > 0.
        IF lv_condition IS NOT INITIAL.
          lv_sql = selection_condition_sql( condition = lv_condition
                                            it_fields = it_fields ).
          IF lv_sql IS INITIAL.
            failed = abap_true.
            RETURN.
          ENDIF.
          APPEND VALUE #( kind = `COND` sql = lv_sql ) TO et_tokens.
        ENDIF.
        CLEAR: lv_condition, lv_open.
        DO lv_closing TIMES.
          APPEND VALUE #( kind = `)` ) TO et_tokens.
        ENDDO.
      ENDIF.
    ENDLOOP.

    IF lv_condition IS NOT INITIAL.
      failed = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD selection_condition_sql.

    DATA lv_field TYPE string.
    DATA lv_op TYPE string.
    DATA lv_value TYPE string.
    DATA(lv_condition) = condense( condition ).
    SPLIT lv_condition AT ` ` INTO lv_field lv_op lv_value.
    lv_field = to_upper( lv_field ).
    lv_op = to_upper( lv_op ).
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = lv_field.
    IF sy-subrc <> 0 OR lv_value IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_sql_op) = SWITCH string( lv_op
      WHEN `EQ` OR `=`  THEN `=`
      WHEN `NE` OR `<>` THEN `<>`
      WHEN `GT` OR `>`  THEN `>`
      WHEN `GE` OR `>=` THEN `>=`
      WHEN `LT` OR `<`  THEN `<`
      WHEN `LE` OR `<=` THEN `<=` ).
    IF lv_sql_op IS INITIAL.
      RETURN.
    ENDIF.
    result = |{ ls_field-name } { lv_sql_op } { literal( is_field = ls_field value = strip_quotes( condense( lv_value ) ) ) }|.

  ENDMETHOD.


  METHOD selection_filter_or.

    DATA lt_or TYPE string_table.
    DATA lv_and TYPE string.
    DATA ls_next TYPE ty_s_filter_token.

    DO.
      lv_and = selection_filter_and( EXPORTING it_tokens = it_tokens
                                     CHANGING  index     = index
                                               failed    = failed ).
      IF failed = abap_true.
        RETURN.
      ENDIF.
      APPEND lv_and TO lt_or.
      ls_next = VALUE #( it_tokens[ index ] OPTIONAL ).
      IF ls_next-kind <> `OR`.
        EXIT.
      ENDIF.
      index = index + 1.
    ENDDO.

    result = COND #( WHEN lines( lt_or ) = 1 THEN lt_or[ 1 ]
                     ELSE |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )| ).

  ENDMETHOD.


  METHOD selection_filter_and.

    DATA lt_and TYPE string_table.
    DATA lv_part TYPE string.
    DATA ls_token TYPE ty_s_filter_token.
    DATA ls_next TYPE ty_s_filter_token.

    DO.
      ls_token = VALUE #( it_tokens[ index ] OPTIONAL ).
      index = index + 1.
      CASE ls_token-kind.
        WHEN `COND`.
          lv_part = ls_token-sql.
        WHEN `(`.
          lv_part = selection_filter_or( EXPORTING it_tokens = it_tokens
                                         CHANGING  index     = index
                                                   failed    = failed ).
          IF failed = abap_true.
            RETURN.
          ENDIF.
          ls_next = VALUE #( it_tokens[ index ] OPTIONAL ).
          IF ls_next-kind <> `)`.
            failed = abap_true.
            RETURN.
          ENDIF.
          index = index + 1.
        WHEN OTHERS.
          failed = abap_true.
          RETURN.
      ENDCASE.
      APPEND lv_part TO lt_and.
      ls_next = VALUE #( it_tokens[ index ] OPTIONAL ).
      IF ls_next-kind <> `AND`.
        EXIT.
      ENDIF.
      index = index + 1.
    ENDDO.

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
      merge_base_associations( EXPORTING it_base    = read_associations_level( entity_name = ls_parsed-base
                                                                               level       = level + 1 )
                                         it_exposed = ls_parsed-exposed
                               CHANGING  ct_assoc   = result ).
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

    "every _Name that stands alone - an association the select list exposes
    "or declares (a path _A.Field is one token and does not count)
    LOOP AT lt_tokens INTO DATA(lv_word) WHERE table_line CP `_*`.
      IF lv_word NA `.` AND NOT line_exists( result-exposed[ table_line = lv_word ] ).
        APPEND lv_word TO result-exposed.
      ENDIF.
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
        "only what the projection exposes
        IF it_exposed IS INITIAL OR line_exists( it_exposed[ table_line = ls_base-name ] ).
          APPEND ls_base TO ct_assoc.
        ENDIF.
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

  METHOD to_csv.

    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lt_lines TYPE string_table.
    DATA lt_cells TYPE string_table.

    DATA(lv_crlf) = cl_abap_char_utilities=>cr_lf.
    LOOP AT it_fields INTO DATA(ls_field).
      APPEND |"{ replace( val = ls_field-label sub = `"` with = `""` occ = 0 ) }"| TO lt_cells.
    ENDLOOP.
    APPEND concat_lines_of( table = lt_cells sep = `;` ) TO lt_lines.

    IF data IS BOUND.
      ASSIGN data->* TO <lt_rows>.
      LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
        CLEAR lt_cells.
        LOOP AT it_fields INTO ls_field.
          DATA(lv_text) = ``.
          UNASSIGN <lv_value>.
          ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_row> TO <lv_value>.
          IF <lv_value> IS ASSIGNED.
            IF ls_field-type_kind = `DATS` AND <lv_value> IS NOT INITIAL.
              DATA(lv_date) = CONV string( <lv_value> ).
              lv_text = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
            ELSEIF ls_field-type_kind = `TIMS`.
              DATA(lv_time) = CONV string( <lv_value> ).
              lv_text = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.
            ELSEIF ls_field-type_kind = `DATS`.
              lv_text = ``.
            ELSE.
              "a template - CONV string( ) puts the sign of -12.50 behind it
              lv_text = condense( |{ <lv_value> }| ).
            ENDIF.
          ENDIF.
          APPEND |"{ replace( val = lv_text sub = `"` with = `""` occ = 0 ) }"| TO lt_cells.
        ENDLOOP.
        APPEND concat_lines_of( table = lt_cells sep = `;` ) TO lt_lines.
      ENDLOOP.
    ENDIF.

    result = concat_lines_of( table = lt_lines sep = lv_crlf ) && lv_crlf.

  ENDMETHOD.


  METHOD to_utf8.
    result = cl_abap_conv_codepage=>create_out( )->convert( val ).
    IF bom = abap_true.
      result = `EFBBBF` && result.
    ENDIF.
  ENDMETHOD.


  METHOD base64_encode.

    CONSTANTS lc_alphabet TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`.
    DATA lv_byte TYPE x LENGTH 1.
    DATA lv_b1 TYPE i.
    DATA lv_b2 TYPE i.
    DATA lv_b3 TYPE i.

    DATA(lv_length) = xstrlen( val ).
    DATA(lv_offset) = 0.
    WHILE lv_offset < lv_length.
      DATA(lv_rest) = lv_length - lv_offset.
      lv_byte = val+lv_offset(1).
      lv_b1 = lv_byte.
      CLEAR: lv_b2, lv_b3.
      IF lv_rest > 1.
        DATA(lv_next) = lv_offset + 1.
        lv_byte = val+lv_next(1).
        lv_b2 = lv_byte.
      ENDIF.
      IF lv_rest > 2.
        lv_next = lv_offset + 2.
        lv_byte = val+lv_next(1).
        lv_b3 = lv_byte.
      ENDIF.
      DATA(lv_triple) = lv_b1 * 65536 + lv_b2 * 256 + lv_b3.
      DATA(lv_c1) = lv_triple DIV 262144.
      DATA(lv_c2) = ( lv_triple DIV 4096 ) MOD 64.
      DATA(lv_c3) = ( lv_triple DIV 64 ) MOD 64.
      DATA(lv_c4) = lv_triple MOD 64.
      result = result && lc_alphabet+lv_c1(1) && lc_alphabet+lv_c2(1).
      result = result && COND string( WHEN lv_rest > 1 THEN lc_alphabet+lv_c3(1) ELSE `=` ).
      result = result && COND string( WHEN lv_rest > 2 THEN lc_alphabet+lv_c4(1) ELSE `=` ).
      lv_offset = lv_offset + 3.
    ENDWHILE.

  ENDMETHOD.

  METHOD url_encode.

    CONSTANTS lc_unreserved TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~`.
    DATA lv_byte TYPE x LENGTH 1.
    DATA lv_char TYPE string.

    DATA(lv_bytes) = to_utf8( CONV string( val ) ).
    DATA(lv_offset) = 0.
    WHILE lv_offset < xstrlen( lv_bytes ).
      lv_byte = lv_bytes+lv_offset(1).
      "a byte below 128 is the ASCII character itself - a string, so that
      "a blank is a blank and not an empty pattern
      IF lv_byte < '80'.
        lv_char = cl_abap_conv_codepage=>create_in( )->convert( CONV xstring( lv_byte ) ).
        IF lv_char <> ` ` AND lc_unreserved CS lv_char.
          result = result && lv_char.
          lv_offset = lv_offset + 1.
          CONTINUE.
        ENDIF.
      ENDIF.
      result = |{ result }%{ lv_byte }|.
      lv_offset = lv_offset + 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD url_decode.

    DATA lv_bytes TYPE xstring.
    DATA lv_byte TYPE x LENGTH 1.

    DATA(lv_text) = CONV string( val ).
    DATA(lv_length) = strlen( lv_text ).
    DATA(lv_pos) = 0.
    WHILE lv_pos < lv_length.
      DATA(lv_char) = substring( val = lv_text off = lv_pos len = 1 ).
      IF lv_char = `%` AND lv_pos + 2 < lv_length.
        DATA(lv_hex) = to_upper( substring( val = lv_text off = lv_pos + 1 len = 2 ) ).
        IF lv_hex CO `0123456789ABCDEF`.
          lv_byte = lv_hex.
          CONCATENATE lv_bytes lv_byte INTO lv_bytes IN BYTE MODE.
          lv_pos = lv_pos + 3.
          CONTINUE.
        ENDIF.
      ENDIF.
      IF lv_char = `+`.
        lv_char = ` `.
      ENDIF.
      DATA(lv_char_bytes) = to_utf8( lv_char ).
      CONCATENATE lv_bytes lv_char_bytes INTO lv_bytes IN BYTE MODE.
      lv_pos = lv_pos + 1.
    ENDWHILE.
    result = cl_abap_conv_codepage=>create_in( )->convert( lv_bytes ).

  ENDMETHOD.


  METHOD parse_url_query.

    DATA(lv_query) = CONV string( query ).
    IF lv_query IS NOT INITIAL AND lv_query(1) = `?`.
      lv_query = substring( val = lv_query off = 1 ).
    ENDIF.
    SPLIT lv_query AT `&` INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO DATA(lv_pair) WHERE table_line IS NOT INITIAL.
      SPLIT lv_pair AT `=` INTO DATA(lv_name) DATA(lv_value).
      APPEND VALUE #( name  = url_decode( lv_name )
                      value = url_decode( lv_value ) ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_read_info.
    DATA(ls_raw) = read_raw_annotations( entity_name ).
    result = parse_read_info( it_entity   = ls_raw-entity
                              it_elements = ls_raw-elements ).
  ENDMETHOD.


  METHOD parse_read_info.

    DATA lt_names TYPE string_table.
    DATA lt_annos TYPE ty_t_annotation.
    DATA lv_name TYPE string.
    DATA ls_field TYPE ty_s_field_info.

    LOOP AT it_entity INTO DATA(ls_anno).
      IF to_upper( ls_anno-key ) = `OBJECTMODEL.QUERY.IMPLEMENTEDBY`.
        result-query_class = annotation_class( ls_anno-value ).
      ENDIF.
    ENDLOOP.

    "the elements in the order of their annotations, each read like a field
    LOOP AT it_elements INTO DATA(ls_element).
      lv_name = to_upper( ls_element-element ).
      IF NOT line_exists( lt_names[ table_line = lv_name ] ).
        APPEND lv_name TO lt_names.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_names INTO lv_name.
      CLEAR lt_annos.
      LOOP AT it_elements INTO ls_element.
        IF to_upper( ls_element-element ) = lv_name.
          APPEND VALUE #( key = ls_element-key value = ls_element-value ) TO lt_annos.
        ENDIF.
      ENDLOOP.
      ls_field = VALUE #( name = lv_name ).
      parse_field_annotations( EXPORTING it_annos = lt_annos
                               CHANGING  cs_field = ls_field ).
      IF ls_field-is_virtual = abap_true.
        APPEND VALUE #( name         = lv_name
                        calc_class   = ls_field-virtual_calc_class
                        sort_class   = ls_field-sort_transform_class
                        filter_class = ls_field-filter_transform_class ) TO result-virtual_elements.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD annotation_class.
    result = to_upper( condense( strip_quotes( val ) ) ).
    IF strlen( result ) > 5 AND substring( val = result len = 5 ) = `ABAP:`.
      result = condense( substring( val = result off = 5 ) ).
    ENDIF.
  ENDMETHOD.


  METHOD tokenize_where.

    DATA lv_token TYPE string.
    DATA lv_char TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_end TYPE i.
    DATA(lv_len) = strlen( where ).

    WHILE lv_pos < lv_len.
      lv_char = substring( val = where off = lv_pos len = 1 ).

      "a blank ends a word
      IF lv_char = ` ` OR lv_char = cl_abap_char_utilities=>horizontal_tab
        OR lv_char = cl_abap_char_utilities=>newline OR lv_char = cl_abap_char_utilities=>cr_lf(1).
        IF lv_token IS NOT INITIAL.
          APPEND lv_token TO result.
          CLEAR lv_token.
        ENDIF.
        lv_pos = lv_pos + 1.
        CONTINUE.
      ENDIF.

      "a host variable is one word, its < > and - included
      IF lv_token IS NOT INITIAL AND lv_token(1) = `@` AND lv_char <> `(` AND lv_char <> `)` AND lv_char <> `,`.
        lv_token = lv_token && lv_char.
        lv_pos = lv_pos + 1.
        CONTINUE.
      ENDIF.

      CASE lv_char.
        WHEN `'`.
          IF lv_token IS NOT INITIAL.
            APPEND lv_token TO result.
            CLEAR lv_token.
          ENDIF.
          "up to the closing quote - a doubled quote is part of the literal
          lv_end = lv_pos + 1.
          WHILE lv_end < lv_len.
            IF substring( val = where off = lv_end len = 1 ) = `'`.
              IF lv_end + 1 < lv_len AND substring( val = where off = lv_end + 1 len = 1 ) = `'`.
                lv_end = lv_end + 2.
                CONTINUE.
              ENDIF.
              EXIT.
            ENDIF.
            lv_end = lv_end + 1.
          ENDWHILE.
          IF lv_end >= lv_len.
            lv_end = lv_len - 1.
          ENDIF.
          APPEND substring( val = where off = lv_pos len = lv_end - lv_pos + 1 ) TO result.
          lv_pos = lv_end + 1.
        WHEN `(` OR `)` OR `,`.
          IF lv_token IS NOT INITIAL.
            APPEND lv_token TO result.
            CLEAR lv_token.
          ENDIF.
          APPEND lv_char TO result.
          lv_pos = lv_pos + 1.
        WHEN `<` OR `>` OR `=` OR `!`.
          IF lv_token IS NOT INITIAL.
            APPEND lv_token TO result.
            CLEAR lv_token.
          ENDIF.
          lv_end = lv_pos + 1.
          WHILE lv_end < lv_len AND substring( val = where off = lv_end len = 1 ) CA `<>=`.
            lv_end = lv_end + 1.
          ENDWHILE.
          APPEND substring( val = where off = lv_pos len = lv_end - lv_pos ) TO result.
          lv_pos = lv_end.
        WHEN OTHERS.
          lv_token = lv_token && lv_char.
          lv_pos = lv_pos + 1.
      ENDCASE.
    ENDWHILE.

    IF lv_token IS NOT INITIAL.
      APPEND lv_token TO result.
    ENDIF.

  ENDMETHOD.


  METHOD split_tokens.

    DATA lt_group TYPE string_table.
    DATA lv_depth TYPE i.
    DATA lv_between TYPE i.
    DATA lv_upper TYPE string.

    LOOP AT it_tokens INTO DATA(lv_token).
      lv_upper = to_upper( lv_token ).
      CASE lv_upper.
        WHEN `(`.
          lv_depth = lv_depth + 1.
        WHEN `)`.
          lv_depth = lv_depth - 1.
        WHEN `BETWEEN`.
          IF lv_depth = 0.
            lv_between = lv_between + 1.
          ENDIF.
      ENDCASE.
      IF lv_depth = 0 AND lv_upper = separator.
        "the AND of a BETWEEN belongs to it
        IF separator = `AND` AND lv_between > 0.
          lv_between = lv_between - 1.
        ELSE.
          APPEND lt_group TO result.
          CLEAR lt_group.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND lv_token TO lt_group.
    ENDLOOP.

    IF lt_group IS NOT INITIAL.
      APPEND lt_group TO result.
    ENDIF.

  ENDMETHOD.


  METHOD strip_parentheses.

    DATA lv_depth TYPE i.
    DATA lv_index TYPE i.
    DATA lv_lines TYPE i.

    DO.
      lv_lines = lines( ct_tokens ).
      IF lv_lines < 2.
        RETURN.
      ENDIF.
      IF ct_tokens[ 1 ] <> `(` OR ct_tokens[ lv_lines ] <> `)`.
        RETURN.
      ENDIF.
      "the first parenthesis has to close at the last token: ( a ) OR ( b )
      "is enclosed by none
      lv_depth = 0.
      LOOP AT ct_tokens INTO DATA(lv_token).
        lv_index = sy-tabix.
        IF lv_token = `(`.
          lv_depth = lv_depth + 1.
        ELSEIF lv_token = `)`.
          lv_depth = lv_depth - 1.
        ENDIF.
        IF lv_depth = 0 AND lv_index < lv_lines.
          RETURN.
        ENDIF.
      ENDLOOP.
      DELETE ct_tokens INDEX lv_lines.
      DELETE ct_tokens INDEX 1.
    ENDDO.

  ENDMETHOD.


  METHOD token_value.

    DATA lv_offset TYPE i.
    DATA lv_host TYPE string.

    CLEAR: value, failed.
    DATA(lv_len) = strlen( token ).
    IF lv_len >= 2 AND token(1) = `'` AND substring( val = token off = lv_len - 1 ) = `'`.
      value = replace( val  = substring( val = token off = 1 len = lv_len - 2 )
                       sub  = `''`
                       with = `'`
                       occ  = 0 ).
    ELSEIF lv_len > 1 AND token(1) = `@`.
      "@<LS_HOST>-NAME: the component after the last dash
      lv_offset = find( val = token sub = `-` occ = -1 ).
      IF lv_offset < 0.
        failed = abap_true.
        RETURN.
      ENDIF.
      lv_host = to_upper( substring( val = token off = lv_offset + 1 ) ).
      READ TABLE host_values INTO DATA(ls_value) WITH KEY name = lv_host.
      IF sy-subrc <> 0.
        failed = abap_true.
        RETURN.
      ENDIF.
      value = ls_value-value.
    ELSEIF lv_len > 0 AND token CO `0123456789.-+`.
      value = token.
    ELSE.
      failed = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD tokens_to_sql.

    DATA lv_prev TYPE string.
    DATA lv_out TYPE string.
    DATA lv_value TYPE string.
    DATA lv_failed TYPE abap_bool.

    LOOP AT it_tokens INTO DATA(lv_token).
      lv_out = lv_token.
      IF host_values IS NOT INITIAL AND strlen( lv_token ) > 1 AND lv_token(1) = `@`.
        token_value( EXPORTING token       = lv_token
                               host_values = host_values
                     IMPORTING value       = lv_value
                               failed      = lv_failed ).
        IF lv_failed = abap_false.
          lv_out = |'{ replace( val = lv_value sub = `'` with = `''` occ = 0 ) }'|.
        ENDIF.
      ENDIF.
      "a function's parenthesis stays at its name: UPPER( X )
      IF result IS INITIAL.
        result = lv_out.
      ELSEIF lv_token = `(` AND lv_prev CO `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_`
        AND lv_prev <> `AND` AND lv_prev <> `OR` AND lv_prev <> `NOT` AND lv_prev <> `IN`
        AND lv_prev <> `EXISTS`.
        result = result && lv_out.
      ELSE.
        result = |{ result } { lv_out }|.
      ENDIF.
      lv_prev = to_upper( lv_token ).
    ENDLOOP.

  ENDMETHOD.


  METHOD search_term.

    DATA lt_tokens TYPE string_table.
    DATA lv_literal TYPE string.
    DATA lv_char TYPE string.
    DATA lv_pos TYPE i.

    lt_tokens = it_tokens.
    strip_parentheses( CHANGING ct_tokens = lt_tokens ).
    DATA(lt_or) = split_tokens( it_tokens = lt_tokens
                                separator = `OR` ).
    "UPPER( F ) LIKE '%TERM%' ESCAPE '#', ORed - the same term each time
    LOOP AT lt_or INTO DATA(lt_part).
      IF lines( lt_part ) <> 8.
        RETURN.
      ENDIF.
      IF to_upper( lt_part[ 1 ] ) <> `UPPER` OR lt_part[ 2 ] <> `(` OR lt_part[ 4 ] <> `)`
        OR to_upper( lt_part[ 5 ] ) <> `LIKE` OR to_upper( lt_part[ 7 ] ) <> `ESCAPE` OR lt_part[ 8 ] <> `'#'`.
        RETURN.
      ENDIF.
      IF lv_literal IS INITIAL.
        lv_literal = lt_part[ 6 ].
      ELSEIF lv_literal <> lt_part[ 6 ].
        RETURN.
      ENDIF.
    ENDLOOP.

    "'%TERM%': the quotes and the % around it off, its escapes undone
    DATA(lv_len) = strlen( lv_literal ).
    IF lv_len < 4 OR substring( val = lv_literal len = 2 ) <> `'%`
      OR substring( val = lv_literal off = lv_len - 2 ) <> `%'`.
      RETURN.
    ENDIF.
    DATA(lv_pattern) = replace( val  = substring( val = lv_literal off = 2 len = lv_len - 4 )
                                sub  = `''`
                                with = `'`
                                occ  = 0 ).
    lv_len = strlen( lv_pattern ).
    WHILE lv_pos < lv_len.
      lv_char = substring( val = lv_pattern off = lv_pos len = 1 ).
      IF lv_char = `#` AND lv_pos + 1 < lv_len.
        result = result && substring( val = lv_pattern off = lv_pos + 1 len = 1 ).
        lv_pos = lv_pos + 2.
        CONTINUE.
      ENDIF.
      result = result && COND string( WHEN lv_char = `%` THEN `*` ELSE lv_char ).
      lv_pos = lv_pos + 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD like_to_pattern.

    DATA lv_char TYPE string.
    DATA lv_next TYPE string.
    DATA lv_pos TYPE i.
    DATA(lv_len) = strlen( pattern ).

    WHILE lv_pos < lv_len.
      lv_char = substring( val = pattern off = lv_pos len = 1 ).
      IF escape IS NOT INITIAL AND lv_char = escape AND lv_pos + 1 < lv_len.
        lv_next = substring( val = pattern off = lv_pos + 1 len = 1 ).
        result = result && COND string( WHEN lv_next CA `*+#` THEN `#` && lv_next ELSE lv_next ).
        lv_pos = lv_pos + 2.
        CONTINUE.
      ENDIF.
      result = result && SWITCH string( lv_char
                                        WHEN `%` THEN `*`
                                        WHEN `_` THEN `+`
                                        WHEN `*` OR `+` OR `#` THEN `#` && lv_char
                                        ELSE lv_char ).
      lv_pos = lv_pos + 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD condition_to_range.

    DATA lt_tokens TYPE string_table.
    DATA lv_value TYPE string.
    DATA lv_high TYPE string.
    DATA lv_escape TYPE string.
    DATA lv_failed TYPE abap_bool.
    DATA lv_sign TYPE c LENGTH 1.
    DATA lv_option TYPE c LENGTH 2.

    CLEAR: name, range.
    failed = abap_true.
    lv_sign = 'I'.
    lt_tokens = it_tokens.
    strip_parentheses( CHANGING ct_tokens = lt_tokens ).
    IF lines( lt_tokens ) > 1 AND to_upper( lt_tokens[ 1 ] ) = `NOT`.
      lv_sign = 'E'.
      DELETE lt_tokens INDEX 1.
      strip_parentheses( CHANGING ct_tokens = lt_tokens ).
    ENDIF.

    DATA(lv_count) = lines( lt_tokens ).
    IF lv_count < 3.
      RETURN.
    ENDIF.
    name = to_upper( lt_tokens[ 1 ] ).
    IF name CN `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/`.
      CLEAR name.
      RETURN.
    ENDIF.
    DATA(lv_op) = to_upper( lt_tokens[ 2 ] ).

    IF lv_count = 3 AND lv_op = `IS` AND to_upper( lt_tokens[ 3 ] ) = `INITIAL`.
      lv_option = 'EQ'.
    ELSEIF lv_count = 4 AND lv_op = `IS` AND to_upper( lt_tokens[ 3 ] ) = `NOT`
      AND to_upper( lt_tokens[ 4 ] ) = `INITIAL`.
      lv_option = 'NE'.
    ELSEIF lv_count = 5 AND lv_op = `BETWEEN` AND to_upper( lt_tokens[ 4 ] ) = `AND`.
      token_value( EXPORTING token       = lt_tokens[ 3 ]
                             host_values = host_values
                   IMPORTING value       = lv_value
                             failed      = lv_failed ).
      IF lv_failed = abap_true.
        RETURN.
      ENDIF.
      token_value( EXPORTING token       = lt_tokens[ 5 ]
                             host_values = host_values
                   IMPORTING value       = lv_high
                             failed      = lv_failed ).
      IF lv_failed = abap_true.
        RETURN.
      ENDIF.
      lv_option = 'BT'.
    ELSEIF lv_op = `LIKE` AND ( lv_count = 3 OR ( lv_count = 5 AND to_upper( lt_tokens[ 4 ] ) = `ESCAPE` ) ).
      IF lv_count = 5.
        token_value( EXPORTING token = lt_tokens[ 5 ]
                     IMPORTING value = lv_escape
                               failed = lv_failed ).
        IF lv_failed = abap_true.
          RETURN.
        ENDIF.
      ENDIF.
      token_value( EXPORTING token       = lt_tokens[ 3 ]
                             host_values = host_values
                   IMPORTING value       = lv_value
                             failed      = lv_failed ).
      IF lv_failed = abap_true.
        RETURN.
      ENDIF.
      lv_value = like_to_pattern( pattern = lv_value
                                  escape  = lv_escape ).
      lv_option = 'CP'.
    ELSEIF lv_count = 3.
      lv_option = SWITCH #( lv_op
        WHEN `=` OR `EQ` THEN 'EQ'
        WHEN `<>` OR `!=` OR `NE` THEN 'NE'
        WHEN `<` OR `LT` THEN 'LT'
        WHEN `<=` OR `LE` THEN 'LE'
        WHEN `>` OR `GT` THEN 'GT'
        WHEN `>=` OR `GE` THEN 'GE' ).
      IF lv_option IS INITIAL.
        RETURN.
      ENDIF.
      token_value( EXPORTING token       = lt_tokens[ 3 ]
                             host_values = host_values
                   IMPORTING value       = lv_value
                             failed      = lv_failed ).
      IF lv_failed = abap_true.
        RETURN.
      ENDIF.
    ELSE.
      RETURN.
    ENDIF.

    range-sign = lv_sign.
    range-option = lv_option.
    range-low = lv_value.
    range-high = lv_high.
    failed = abap_false.

  ENDMETHOD.


  METHOD build_query_filter.

    DATA lt_sql TYPE string_table.
    DATA lt_tokens TYPE string_table.
    DATA lt_lines TYPE ty_t_range_option.
    DATA ls_range TYPE ty_s_range_option.
    DATA lv_name TYPE string.
    DATA lv_cond_name TYPE string.
    DATA lv_failed TYPE abap_bool.
    DATA lv_search TYPE string.

    DATA(lt_and) = split_tokens( it_tokens = tokenize_where( where )
                                 separator = `AND` ).
    LOOP AT lt_and INTO DATA(lt_conjunct).
      "the free-text search - a provider is given it on its own
      IF result-search IS INITIAL.
        lv_search = search_term( lt_conjunct ).
        IF lv_search IS NOT INITIAL.
          result-search = lv_search.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND tokens_to_sql( it_tokens    = lt_conjunct
                            host_values = host_values ) TO lt_sql.
      IF result-no_ranges = abap_true.
        CONTINUE.
      ENDIF.

      "an OR of conditions on one field - the lines of its range
      CLEAR: lt_lines, lv_name.
      lt_tokens = lt_conjunct.
      strip_parentheses( CHANGING ct_tokens = lt_tokens ).
      DATA(lt_or) = split_tokens( it_tokens = lt_tokens
                                  separator = `OR` ).
      LOOP AT lt_or INTO DATA(lt_disjunct).
        condition_to_range( EXPORTING it_tokens   = lt_disjunct
                                      host_values = host_values
                            IMPORTING name        = lv_cond_name
                                      range       = ls_range
                                      failed      = lv_failed ).
        IF lv_failed = abap_true OR ( lv_name IS NOT INITIAL AND lv_cond_name <> lv_name ).
          result-no_ranges = abap_true.
          EXIT.
        ENDIF.
        lv_name = lv_cond_name.
        APPEND ls_range TO lt_lines.
      ENDLOOP.
      IF result-no_ranges = abap_true.
        CONTINUE.
      ENDIF.
      "a range includes its I lines and excludes its E lines - NOT a OR b,
      "or a field in two conditions, is no range
      IF ( line_exists( lt_lines[ sign = 'E' ] ) AND lines( lt_lines ) > 1 )
        OR line_exists( result-ranges[ name = lv_name ] ).
        result-no_ranges = abap_true.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name  = lv_name
                      range = lt_lines ) TO result-ranges.
    ENDLOOP.

    result-sql = concat_lines_of( table = lt_sql sep = ` AND ` ).
    IF result-no_ranges = abap_true.
      CLEAR result-ranges.
    ENDIF.

  ENDMETHOD.


  METHOD parse_order_by.

    DATA lv_part TYPE string.
    DATA lv_field TYPE string.
    DATA lv_direction TYPE string.

    SPLIT order_by AT `,` INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts INTO lv_part.
      lv_part = condense( lv_part ).
      SPLIT lv_part AT ` ` INTO lv_field lv_direction.
      IF lv_field IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( field      = to_upper( lv_field )
                      descending = xsdbool( to_upper( condense( lv_direction ) ) = `DESCENDING` ) ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD order_by_to_string.

    DATA lt_parts TYPE string_table.

    LOOP AT it_sort INTO DATA(ls_sort).
      APPEND |{ ls_sort-field }{ COND #( WHEN ls_sort-descending = abap_true THEN ` DESCENDING` ELSE `` ) }|
        TO lt_parts.
    ENDLOOP.
    result = concat_lines_of( table = lt_parts sep = `, ` ).

  ENDMETHOD.


  METHOD remove_where_fields.

    DATA lt_keep TYPE string_table.
    DATA lv_dropped TYPE abap_bool.
    DATA lv_hit TYPE abap_bool.
    DATA lv_upper TYPE string.

    result = where.
    IF fields IS INITIAL OR where IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_and) = split_tokens( it_tokens = tokenize_where( where )
                                 separator = `AND` ).
    LOOP AT lt_and INTO DATA(lt_conjunct).
      lv_hit = abap_false.
      LOOP AT lt_conjunct INTO DATA(lv_token).
        lv_upper = to_upper( lv_token ).
        IF line_exists( fields[ table_line = lv_upper ] ).
          lv_hit = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_hit = abap_true.
        lv_dropped = abap_true.
      ELSE.
        APPEND tokens_to_sql( lt_conjunct ) TO lt_keep.
      ENDIF.
    ENDLOOP.

    IF lv_dropped = abap_true.
      result = concat_lines_of( table = lt_keep sep = ` AND ` ).
    ENDIF.

  ENDMETHOD.


  METHOD is_sortable.
    result = xsdbool( is_field-type_kind <> `STRING` AND is_field-type_kind <> `RAW`
                      AND ( is_field-is_virtual = abap_false OR is_field-sort_transform_class IS NOT INITIAL ) ).
  ENDMETHOD.


  METHOD is_filterable.
    result = xsdbool( is_field-is_virtual = abap_false ).
  ENDMETHOD.


  METHOD aggregate_rows.

    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_group> TYPE any.
    FIELD-SYMBOLS <lv_measure> TYPE any.
    FIELD-SYMBOLS <ls_agg> TYPE ty_s_aggregate.
    DATA lv_key TYPE string.
    DATA lv_value TYPE decfloat34.
    DATA lv_rows TYPE i.

    IF data IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lv_method) = to_upper( method ).
    ASSIGN data->* TO <lt_rows>.
    IF <lt_rows> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      CLEAR: lv_key, lv_value.
      IF group_by IS NOT INITIAL.
        UNASSIGN <lv_group>.
        ASSIGN COMPONENT group_by OF STRUCTURE <ls_row> TO <lv_group>.
        IF <lv_group> IS ASSIGNED.
          lv_key = |{ <lv_group> }|.
        ENDIF.
      ENDIF.
      IF measure IS NOT INITIAL.
        UNASSIGN <lv_measure>.
        ASSIGN COMPONENT measure OF STRUCTURE <ls_row> TO <lv_measure>.
        IF <lv_measure> IS ASSIGNED.
          TRY.
              lv_value = <lv_measure>.
            CATCH cx_sy_conversion_error.
              CLEAR lv_value.
          ENDTRY.
        ENDIF.
      ENDIF.

      UNASSIGN <ls_agg>.
      READ TABLE result ASSIGNING <ls_agg> WITH KEY group_key = lv_key.
      IF <ls_agg> IS NOT ASSIGNED.
        APPEND VALUE #( group_key = lv_key
                        value     = lv_value
                        row_count = 1 ) TO result.
        CONTINUE.
      ENDIF.
      <ls_agg>-row_count = <ls_agg>-row_count + 1.
      CASE lv_method.
        WHEN `MIN`.
          IF lv_value < <ls_agg>-value.
            <ls_agg>-value = lv_value.
          ENDIF.
        WHEN `MAX`.
          IF lv_value > <ls_agg>-value.
            <ls_agg>-value = lv_value.
          ENDIF.
        WHEN OTHERS.
          <ls_agg>-value = <ls_agg>-value + lv_value.
      ENDCASE.
    ENDLOOP.

    "the count through an i - the transpiled runtime sets no decfloat34
    "from an int8
    LOOP AT result ASSIGNING <ls_agg>.
      lv_rows = <ls_agg>-row_count.
      CASE lv_method.
        WHEN `AVG`.
          <ls_agg>-value = <ls_agg>-value / lv_rows.
        WHEN `COUNT`.
          <ls_agg>-value = lv_rows.
      ENDCASE.
    ENDLOOP.
    SORT result BY group_key.

  ENDMETHOD.


  METHOD decode_field_permission.
    result-name = name.
    result-mandatory = xsdbool( value MOD 2 = 1 ).
    result-read_only = xsdbool( ( value DIV 2 ) MOD 2 = 1 ).
    result-mandatory_create = xsdbool( ( value DIV 16 ) MOD 2 = 1 ).
    result-read_only_update = xsdbool( ( value DIV 32 ) MOD 2 = 1 ).
  ENDMETHOD.


  METHOD is_operation_enabled.
    result = xsdbool( value = 0 ).
  ENDMETHOD.


  METHOD get_permission_type_names.
    DATA(lv_base) = |\\BDEF={ to_upper( bdef ) }\\ENTITY={ to_upper( entity_name ) }\\TYPE=|.
    CASE to_upper( kind ).
      WHEN `KEY`.
        result = VALUE #( ( lv_base && `PERMISSIONS_K` ) ( lv_base && `PERMISSIONS_I` ) ( lv_base && `PERMISSIONS_KEY` ) ).
      WHEN `REQUEST`.
        result = VALUE #( ( lv_base && `PERMISSIONS_Q` ) ( lv_base && `PERMISSIONS_REQUEST` ) ).
      WHEN `RESULT`.
        result = VALUE #( ( lv_base && `PERMISSIONS_R` ) ( lv_base && `PERMISSIONS_RESULT` ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD is_permitted.
    READ TABLE ops INTO DATA(ls_op) WITH KEY name = to_upper( name ).
    result = xsdbool( sy-subrc <> 0 OR ls_op-enabled = abap_true ).
  ENDMETHOD.


  METHOD get_instance_permissions.

    DATA lv_match TYPE abap_bool.

    IF is_permissions-answered = abap_false.
      result = VALUE #( keys       = keys
                        can_create = abap_true
                        can_update = abap_true
                        can_delete = abap_true ).
      RETURN.
    ENDIF.
    result = is_permissions-global.
    result-keys = keys.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT is_permissions-instances INTO DATA(ls_instance).
      lv_match = abap_true.
      LOOP AT keys INTO DATA(ls_key).
        READ TABLE ls_instance-keys INTO DATA(ls_inst_key) WITH KEY name = to_upper( ls_key-name ).
        IF sy-subrc <> 0 OR condense( ls_inst_key-value ) <> condense( ls_key-value ).
          lv_match = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_match = abap_false.
        CONTINUE.
      ENDIF.
      result-can_update = xsdbool( result-can_update = abap_true AND ls_instance-can_update = abap_true ).
      result-can_delete = xsdbool( result-can_delete = abap_true AND ls_instance-can_delete = abap_true ).
      LOOP AT ls_instance-actions INTO DATA(ls_op) WHERE enabled = abap_false.
        DELETE result-actions WHERE name = ls_op-name.
        APPEND ls_op TO result-actions.
      ENDLOOP.
      LOOP AT ls_instance-associations INTO ls_op WHERE enabled = abap_false.
        DELETE result-associations WHERE name = ls_op-name.
        APPEND ls_op TO result-associations.
      ENDLOOP.
      LOOP AT ls_instance-fields INTO DATA(ls_field).
        READ TABLE result-fields ASSIGNING FIELD-SYMBOL(<ls_field>) WITH KEY name = ls_field-name.
        IF sy-subrc <> 0.
          APPEND ls_field TO result-fields.
          CONTINUE.
        ENDIF.
        <ls_field>-read_only = xsdbool( <ls_field>-read_only = abap_true OR ls_field-read_only = abap_true ).
        <ls_field>-read_only_update = xsdbool( <ls_field>-read_only_update = abap_true
                                            OR ls_field-read_only_update = abap_true ).
        <ls_field>-mandatory = xsdbool( <ls_field>-mandatory = abap_true OR ls_field-mandatory = abap_true ).
        <ls_field>-mandatory_create = xsdbool( <ls_field>-mandatory_create = abap_true
                                            OR ls_field-mandatory_create = abap_true ).
      ENDLOOP.
      RETURN.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_field_control.

    DATA ls_perm TYPE ty_s_perm_field.

    READ TABLE it_perm_fields INTO ls_perm WITH KEY name = to_upper( is_field-name ).
    IF sy-subrc <> 0.
      CLEAR ls_perm.
    ENDIF.

    result-read_only = xsdbool( is_field-is_readonly = abap_true OR ls_perm-read_only = abap_true ).
    IF is_create = abap_false AND ( is_field-is_key = abap_true OR ls_perm-read_only_update = abap_true ).
      result-read_only = abap_true.
    ENDIF.
    "a key the business object numbers itself is never typed in - early
    "numbering (read-only by its field control) or a UUID (managed)
    IF is_create = abap_true AND is_field-is_key = abap_true
      AND is_field-type_kind = `RAW` AND is_field-length = 16.
      result-read_only = abap_true.
    ENDIF.

    result-mandatory = xsdbool( is_field-is_mandatory = abap_true OR ls_perm-mandatory = abap_true
                             OR ( is_create = abap_true AND ls_perm-mandatory_create = abap_true ) ).
    IF result-read_only = abap_true.
      result-mandatory = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD get_draft_status.
    IF has_draft = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_owner) = condense( to_upper( owner ) ).
    IF lv_owner IS INITIAL OR lv_owner = condense( to_upper( user ) ).
      result-state = cs_editing_status-own_draft.
      result-user = condense( user ).
      RETURN.
    ENDIF.
    result-state = cs_editing_status-locked.
    result-user = condense( owner ).
  ENDMETHOD.


  METHOD matches_editing_status.
    CASE to_upper( filter ).
      WHEN `` OR cs_editing_status-all.
        result = abap_true.
      WHEN cs_editing_status-unchanged.
        result = xsdbool( state IS INITIAL ).
      WHEN OTHERS.
        result = xsdbool( to_upper( filter ) = to_upper( state ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD get_etag_field.
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY admin_field = `LOCAL_LAST_CHANGED_AT`.
    IF sy-subrc = 0.
      result = ls_field-name.
      RETURN.
    ENDIF.
    READ TABLE it_fields INTO ls_field WITH KEY admin_field = `LAST_CHANGED_AT`.
    IF sy-subrc = 0.
      result = ls_field-name.
    ENDIF.
  ENDMETHOD.


  METHOD prepare_messages.

    DATA lv_has_error TYPE abap_bool.

    LOOP AT messages INTO DATA(ls_message).
      IF ls_message-text IS INITIAL.
        CONTINUE.
      ENDIF.
      ls_message-type = to_lower( ls_message-type ).
      IF ls_message-type <> `warning` AND ls_message-type <> `success` AND ls_message-type <> `information`.
        ls_message-type = `error`.
      ENDIF.
      IF line_exists( result[ text = ls_message-text type = ls_message-type ] ).
        CONTINUE.
      ENDIF.
      IF ls_message-type = `error`.
        lv_has_error = abap_true.
      ENDIF.
      APPEND ls_message TO result.
    ENDLOOP.

    IF lv_has_error = abap_true.
      DELETE result WHERE type = `success`.
    ENDIF.

  ENDMETHOD.


  METHOD get_message_display.

    IF messages IS INITIAL.
      result = cs_message_display-none.
      RETURN.
    ENDIF.
    result = cs_message_display-toast.
    LOOP AT messages INTO DATA(ls_message) WHERE type <> `success` AND type <> `information`.
      result = cs_message_display-view.
      EXIT.
    ENDLOOP.
    IF result = cs_message_display-view AND lines( messages ) = 1.
      ls_message = messages[ 1 ].
      IF ls_message-fields IS INITIAL AND ls_message-target IS INITIAL.
        result = cs_message_display-box.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD get_message_items.

    DATA lt_labels TYPE string_table.

    LOOP AT messages INTO DATA(ls_message).
      CLEAR lt_labels.
      LOOP AT ls_message-fields INTO DATA(lv_field).
        READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = to_upper( lv_field ).
        APPEND COND string( WHEN sy-subrc = 0 AND ls_field-label IS NOT INITIAL THEN ls_field-label
                            ELSE lv_field ) TO lt_labels.
      ENDLOOP.
      APPEND VALUE #( type       = SWITCH #( to_lower( ls_message-type )
                                     WHEN `warning`     THEN `Warning`
                                     WHEN `success`     THEN `Success`
                                     WHEN `information` THEN `Information`
                                     ELSE `Error` )
                      title      = ls_message-text
                      subtitle   = concat_lines_of( table = lt_labels sep = `, ` )
                      group_name = ls_message-target ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_data_uri.

    "data:[<mime type>][;charset=...][;base64],<data>
    IF strlen( uri ) < 5 OR to_lower( uri(5) ) <> `data:`.
      RETURN.
    ENDIF.
    DATA(lv_comma) = find( val = uri sub = `,` ).
    IF lv_comma < 0.
      RETURN.
    ENDIF.
    DATA(lv_header) = substring( val = uri off = 5 len = lv_comma - 5 ).
    DATA(lv_data) = substring( val = uri off = lv_comma + 1 ).
    DATA(lv_is_base64) = abap_false.
    SPLIT lv_header AT `;` INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts INTO DATA(lv_part).
      IF sy-tabix = 1.
        result-mime_type = to_lower( condense( lv_part ) ).
      ELSEIF to_lower( condense( lv_part ) ) = `base64`.
        lv_is_base64 = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_is_base64 = abap_true.
      result-content = base64_decode( lv_data ).
    ELSE.
      result-content = to_utf8( url_decode( lv_data ) ).
    ENDIF.
    result-file_name = file_name.
    IF result-mime_type IS INITIAL OR result-mime_type = `application/octet-stream`.
      DATA(lv_by_name) = mime_from_file_name( file_name ).
      IF lv_by_name IS NOT INITIAL.
        result-mime_type = lv_by_name.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD to_data_uri.

    DATA(lv_mime) = to_lower( condense( mime_type ) ).
    IF lv_mime IS INITIAL.
      lv_mime = `application/octet-stream`.
    ENDIF.
    result = |data:{ lv_mime };base64,{ base64_encode( content ) }|.

  ENDMETHOD.


  METHOD base64_decode.

    CONSTANTS lc_alphabet TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`.
    DATA lv_byte TYPE x LENGTH 1.
    DATA lv_char TYPE c LENGTH 1.
    DATA lv_bits TYPE i.
    DATA lv_count TYPE i.
    DATA lv_value TYPE i.

    "6 bits per character, a byte as soon as 8 are there; = and anything
    "outside the alphabet (blanks, line breaks) carries no bits
    DATA(lv_length) = strlen( val ).
    DATA(lv_offset) = 0.
    WHILE lv_offset < lv_length.
      lv_char = val+lv_offset(1).
      lv_offset = lv_offset + 1.
      IF lv_char = ` `.
        CONTINUE.
      ENDIF.
      DATA(lv_index) = find( val = lc_alphabet sub = lv_char case = abap_true ).
      IF lv_index < 0.
        CONTINUE.
      ENDIF.
      lv_bits = lv_bits * 64 + lv_index.
      lv_count = lv_count + 6.
      IF lv_count >= 8.
        lv_count = lv_count - 8.
        lv_value = lv_bits DIV ipow( base = 2 exp = lv_count ).
        lv_bits = lv_bits - lv_value * ipow( base = 2 exp = lv_count ).
        lv_byte = lv_value.
        CONCATENATE result lv_byte INTO result IN BYTE MODE.
      ENDIF.
    ENDWHILE.

  ENDMETHOD.


  METHOD get_mime_map.

    result = VALUE #(
      ( name = `pdf`  value = `application/pdf` )
      ( name = `png`  value = `image/png` )
      ( name = `jpg`  value = `image/jpeg` )
      ( name = `jpeg` value = `image/jpeg` )
      ( name = `gif`  value = `image/gif` )
      ( name = `bmp`  value = `image/bmp` )
      ( name = `webp` value = `image/webp` )
      ( name = `txt`  value = `text/plain` )
      ( name = `csv`  value = `text/csv` )
      ( name = `json` value = `application/json` )
      ( name = `xml`  value = `application/xml` )
      ( name = `zip`  value = `application/zip` )
      ( name = `doc`  value = `application/msword` )
      ( name = `docx` value = `application/vnd.openxmlformats-officedocument.wordprocessingml.document` )
      ( name = `xls`  value = `application/vnd.ms-excel` )
      ( name = `xlsx` value = `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` )
      ( name = `pptx` value = `application/vnd.openxmlformats-officedocument.presentationml.presentation` ) ).

  ENDMETHOD.


  METHOD mime_from_file_name.

    DATA(lv_dot) = find( val = file_name sub = `.` occ = -1 ).
    IF lv_dot < 0.
      RETURN.
    ENDIF.
    DATA(lv_extension) = to_lower( substring( val = file_name off = lv_dot + 1 ) ).
    DATA(lt_map) = get_mime_map( ).
    READ TABLE lt_map INTO DATA(ls_map) WITH KEY name = lv_extension.
    IF sy-subrc = 0.
      result = ls_map-value.
    ENDIF.

  ENDMETHOD.


  METHOD is_mime_type_accepted.

    IF accepted IS INITIAL.
      result = abap_true.
      RETURN.
    ENDIF.
    DATA(lv_mime) = to_lower( condense( mime_type ) ).
    LOOP AT accepted INTO DATA(lv_accepted).
      lv_accepted = to_lower( condense( lv_accepted ) ).
      IF lv_accepted = `*/*` OR lv_accepted = `*` OR lv_accepted = lv_mime.
        result = abap_true.
        RETURN.
      ENDIF.
      "image/* - every type of the group
      DATA(lv_len) = strlen( lv_accepted ).
      IF lv_len > 2 AND substring( val = lv_accepted off = lv_len - 2 ) = `/*`.
        DATA(lv_group) = substring( val = lv_accepted len = lv_len - 1 ).
        IF strlen( lv_mime ) > strlen( lv_group ) AND lv_mime CP |{ lv_group }*|.
          result = abap_true.
          RETURN.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD check_file.

    IF xstrlen( file-content ) = 0.
      result = cs_file_check-empty.
    ELSEIF max_size > 0 AND xstrlen( file-content ) > max_size.
      result = cs_file_check-too_large.
    ELSEIF is_mime_type_accepted( mime_type = file-mime_type
                                  accepted  = accepted ) = abap_false.
      result = cs_file_check-type.
    ELSE.
      result = cs_file_check-ok.
    ENDIF.

  ENDMETHOD.


  METHOD get_file_extensions.

    DATA lt_extensions TYPE string_table.

    DATA(lt_map) = get_mime_map( ).
    LOOP AT accepted INTO DATA(lv_accepted).
      DATA(lv_mime) = to_lower( condense( lv_accepted ) ).
      DATA(lv_found) = abap_false.
      LOOP AT lt_map INTO DATA(ls_map) WHERE value = lv_mime.
        lv_found = abap_true.
        APPEND ls_map-name TO lt_extensions.
      ENDLOOP.
      IF lv_found = abap_false.
        "a group (image/*) or a type without a known extension: no filter
        RETURN.
      ENDIF.
    ENDLOOP.
    result = concat_lines_of( table = lt_extensions sep = `,` ).

  ENDMETHOD.


  METHOD match_inbound_parameters.

    LOOP AT params INTO DATA(ls_param).
      READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = to_upper( condense( ls_param-name ) ).
      IF sy-subrc <> 0
        OR ls_field-is_virtual = abap_true
        OR ls_field-is_large_object = abap_true
        OR line_exists( result[ name = ls_field-name ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = ls_field-name value = ls_param-value ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD clear_large_objects.

    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.
    FIELD-SYMBOLS <lv_file> TYPE any.

    IF data IS NOT BOUND OR NOT line_exists( it_fields[ is_large_object = abap_true ] ).
      RETURN.
    ENDIF.
    ASSIGN data->* TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      LOOP AT it_fields INTO DATA(ls_field) WHERE is_large_object = abap_true.
        ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_row> TO <lv_file>.
        IF sy-subrc = 0.
          CLEAR <lv_file>.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD entries_to_annos.

    LOOP AT it_entries INTO DATA(ls_entry).
      APPEND VALUE #( key = ls_entry-prop value = ls_entry-value ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_entry_bindings.

    DATA lv_idx TYPE i.
    LOOP AT it_entries INTO DATA(ls_entry).
      IF ls_entry-idx = lv_idx.
        CONTINUE.
      ENDIF.
      lv_idx = ls_entry-idx.
      DATA(ls_binding) = VALUE ty_s_additional_binding(
        element       = to_upper( strip_quotes( get_entry_value( it_entries = it_entries idx = lv_idx prop = `ELEMENT` ) ) )
        local_element = to_upper( strip_quotes( get_entry_value( it_entries = it_entries idx = lv_idx prop = `LOCALELEMENT` ) ) )
        usage         = strip_quotes( get_entry_value( it_entries = it_entries idx = lv_idx prop = `USAGE` ) ) ).
      IF ls_binding-local_element IS NOT INITIAL OR ls_binding-element IS NOT INITIAL.
        APPEND ls_binding TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_entry_display.

    cs_entry-criticality = to_upper( strip_quotes( get_entry_value( it_entries = it_entries
                                                                     idx        = idx
                                                                     prop       = `CRITICALITY` ) ) ).
    cs_entry-crit_representation = to_upper( replace( val  = strip_quotes( get_entry_value( it_entries = it_entries
                                                                                           idx        = idx
                                                                                           prop       = `CRITICALITYREPRESENTATION` ) )
                                                      sub  = `#`
                                                      with = `` ) ).
    cs_entry-importance = to_upper( replace( val  = strip_quotes( get_entry_value( it_entries = it_entries
                                                                                  idx        = idx
                                                                                  prop       = `IMPORTANCE` ) )
                                             sub  = `#`
                                             with = `` ) ).
    cs_entry-hidden = hidden_value( get_entry_value( it_entries = it_entries
                                                     idx        = idx
                                                     prop       = `HIDDEN` ) ).

  ENDMETHOD.


  METHOD range_to_condition.

    DATA(lv_option) = to_upper( replace( val = strip_quotes( condense( option ) ) sub = `#` with = `` ) ).
    DATA(lv_sign) = to_upper( replace( val = strip_quotes( condense( sign ) ) sub = `#` with = `` ) ).
    DATA(lv_low) = strip_quotes( low ).
    DATA(lv_len) = strlen( lv_low ).
    result-exclude = xsdbool( lv_sign = `E` ).
    result-low = lv_low.
    result-high = strip_quotes( high ).
    CASE lv_option.
      WHEN `EQ` OR `NE` OR `GT` OR `GE` OR `LT` OR `LE` OR `BT`.
        result-operator = lv_option.
      WHEN `NB`.
        result-operator = cs_condition_op-bt.
        result-exclude = xsdbool( result-exclude = abap_false ).
      WHEN `CP` OR `NP`.
        IF lv_option = `NP`.
          result-exclude = xsdbool( result-exclude = abap_false ).
        ENDIF.
        result-operator = cs_condition_op-contains.
        IF lv_len > 2 AND lv_low(1) = `*` AND substring( val = lv_low off = lv_len - 1 ) = `*`.
          result-low = substring( val = lv_low off = 1 len = lv_len - 2 ).
        ELSEIF lv_len > 1 AND substring( val = lv_low off = lv_len - 1 ) = `*`.
          result-operator = cs_condition_op-starts_with.
          result-low = substring( val = lv_low len = lv_len - 1 ).
        ELSEIF lv_len > 1 AND lv_low(1) = `*`.
          result-operator = cs_condition_op-ends_with.
          result-low = substring( val = lv_low off = 1 ).
        ENDIF.
      WHEN OTHERS.
        result-operator = cs_condition_op-eq.
    ENDCASE.

  ENDMETHOD.


  METHOD read_fixed_values.

    DATA lr_values TYPE REF TO data.
    FIELD-SYMBOLS <lt_values> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_low> TYPE any.
    FIELD-SYMBOLS <lv_high> TYPE any.
    FIELD-SYMBOLS <lv_text> TYPE any.

    "CL_ABAP_ELEMDESCR->GET_DDIC_FIXED_VALUES reads DD07L / DD07T - on-premise
    "RTTI, called dynamically like the other DDIC reads of this class, so a
    "release without it only loses the automatic value help
    TRY.
        CREATE DATA lr_values TYPE (`DDFIXVALUES`).
        ASSIGN lr_values->* TO <lt_values>.
        CALL METHOD io_elem->(`GET_DDIC_FIXED_VALUES`)
          EXPORTING
            p_langu        = sy-langu
          RECEIVING
            p_fixed_values = <lt_values>
          EXCEPTIONS
            not_found      = 1
            no_ddic_type   = 2
            OTHERS         = 3.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        LOOP AT <lt_values> ASSIGNING FIELD-SYMBOL(<ls_value>).
          UNASSIGN: <lv_low>, <lv_high>, <lv_text>.
          ASSIGN COMPONENT `LOW` OF STRUCTURE <ls_value> TO <lv_low>.
          ASSIGN COMPONENT `HIGH` OF STRUCTURE <ls_value> TO <lv_high>.
          ASSIGN COMPONENT `DDTEXT` OF STRUCTURE <ls_value> TO <lv_text>.
          "an interval of the domain is no entry of a list
          IF <lv_low> IS NOT ASSIGNED OR ( <lv_high> IS ASSIGNED AND <lv_high> IS NOT INITIAL ).
            CONTINUE.
          ENDIF.
          APPEND VALUE #( name  = condense( |{ <lv_low> }| )
                          value = COND #( WHEN <lv_text> IS ASSIGNED THEN condense( |{ <lv_text> }| ) ) ) TO result.
        ENDLOOP.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD conditions_to_filter.

    DATA lt_parts TYPE string_table.
    DATA lv_part TYPE string.
    DATA lv_op TYPE string.
    DATA lv_exclude TYPE abap_bool.
    DATA lv_low TYPE string.
    DATA lv_high TYPE string.

    LOOP AT conditions INTO DATA(ls_condition).
      lv_op = to_upper( condense( ls_condition-operator ) ).
      lv_exclude = ls_condition-exclude.
      "the separator of the filter syntax cannot be part of a value
      lv_low = condense( replace( val = ls_condition-low sub = `;` with = `` occ = 0 ) ).
      lv_high = condense( replace( val = ls_condition-high sub = `;` with = `` occ = 0 ) ).
      IF lv_op = cs_condition_op-ne.
        lv_op = cs_condition_op-eq.
        lv_exclude = xsdbool( lv_exclude = abap_false ).
      ENDIF.
      IF lv_low IS INITIAL AND lv_op <> cs_condition_op-empty.
        CONTINUE.
      ENDIF.
      CLEAR lv_part.
      CASE lv_op.
        WHEN cs_condition_op-eq.
          lv_part = |={ lv_low }|.
        WHEN cs_condition_op-bt.
          IF lv_high IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_part = |{ lv_low }..{ lv_high }|.
        WHEN cs_condition_op-gt.
          lv_part = |>{ lv_low }|.
        WHEN cs_condition_op-ge.
          lv_part = |>={ lv_low }|.
        WHEN cs_condition_op-lt.
          lv_part = |<{ lv_low }|.
        WHEN cs_condition_op-le.
          lv_part = |<={ lv_low }|.
        WHEN cs_condition_op-contains.
          lv_part = |*{ lv_low }*|.
        WHEN cs_condition_op-starts_with.
          lv_part = |{ lv_low }*|.
        WHEN cs_condition_op-ends_with.
          lv_part = |*{ lv_low }|.
        WHEN cs_condition_op-empty.
          lv_part = `=`.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
      IF lv_exclude = abap_true.
        lv_part = |!{ lv_part }|.
      ENDIF.
      APPEND lv_part TO lt_parts.
    ENDLOOP.

    result = concat_lines_of( table = lt_parts sep = `;` ).

  ENDMETHOD.


  METHOD filter_to_conditions.

    DATA ls_condition TYPE ty_s_condition.
    DATA lv_part TYPE string.
    DATA lv_len TYPE i.

    LOOP AT split_filter_value( value ) INTO lv_part.
      CLEAR ls_condition.
      IF lv_part(1) = `!`.
        ls_condition-exclude = abap_true.
        lv_part = substring( val = lv_part off = 1 ).
        IF lv_part IS INITIAL.
          CONTINUE.
        ENDIF.
      ENDIF.
      lv_len = strlen( lv_part ).
      IF lv_part = `=`.
        ls_condition-operator = cs_condition_op-empty.
      ELSEIF lv_part CS `..`.
        ls_condition-operator = cs_condition_op-bt.
        SPLIT lv_part AT `..` INTO ls_condition-low ls_condition-high.
        CONDENSE ls_condition-low.
        CONDENSE ls_condition-high.
      ELSEIF lv_len > 2 AND lv_part(2) = `>=`.
        ls_condition-operator = cs_condition_op-ge.
        ls_condition-low = substring( val = lv_part off = 2 ).
      ELSEIF lv_len > 2 AND lv_part(2) = `<=`.
        ls_condition-operator = cs_condition_op-le.
        ls_condition-low = substring( val = lv_part off = 2 ).
      ELSEIF lv_len > 1 AND lv_part(1) = `>`.
        ls_condition-operator = cs_condition_op-gt.
        ls_condition-low = substring( val = lv_part off = 1 ).
      ELSEIF lv_len > 1 AND lv_part(1) = `<`.
        ls_condition-operator = cs_condition_op-lt.
        ls_condition-low = substring( val = lv_part off = 1 ).
      ELSEIF lv_len > 1 AND lv_part(1) = `=`.
        ls_condition-operator = cs_condition_op-eq.
        ls_condition-low = substring( val = lv_part off = 1 ).
      ELSEIF lv_len > 2 AND lv_part(1) = `*` AND substring( val = lv_part off = lv_len - 1 ) = `*`.
        ls_condition-operator = cs_condition_op-contains.
        ls_condition-low = substring( val = lv_part off = 1 len = lv_len - 2 ).
      ELSEIF lv_len > 1 AND substring( val = lv_part off = lv_len - 1 ) = `*`.
        ls_condition-operator = cs_condition_op-starts_with.
        ls_condition-low = substring( val = lv_part len = lv_len - 1 ).
      ELSEIF lv_len > 1 AND lv_part(1) = `*`.
        ls_condition-operator = cs_condition_op-ends_with.
        ls_condition-low = substring( val = lv_part off = 1 ).
      ELSE.
        "no operator: contains for text, equals for the rest
        ls_condition-operator = COND #( WHEN is_field-type_kind = `CHAR` OR is_field-type_kind = `STRING`
                                        THEN cs_condition_op-contains
                                        ELSE cs_condition_op-eq ).
        ls_condition-low = lv_part.
      ENDIF.
      APPEND ls_condition TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD split_filter_value.

    DATA lv_part TYPE string.
    SPLIT value AT `;` INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts INTO lv_part.
      CONDENSE lv_part.
      IF lv_part IS NOT INITIAL.
        APPEND lv_part TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_filter_control.

    IF is_field-is_boolean = abap_true OR is_field-value_help-fixed_values IS NOT INITIAL
      OR ( is_field-value_help-is_dropdown = abap_true AND is_field-value_help-entity_name IS NOT INITIAL ).
      result = cs_filter_control-list.
    ELSEIF is_field-type_kind = `DATS`.
      result = COND #( WHEN is_field-filter_single = abap_true THEN cs_filter_control-date
                       ELSE cs_filter_control-date_range ).
    ELSEIF is_field-value_help-entity_name IS NOT INITIAL AND is_field-filter_single = abap_false.
      result = cs_filter_control-multi.
    ELSE.
      result = cs_filter_control-input.
    ENDIF.

  ENDMETHOD.


  METHOD get_filter_list.

    "the empty entry first - every row
    APPEND VALUE #( ) TO result.
    IF is_field-is_boolean = abap_true.
      APPEND VALUE #( name = `=X` value = yes ) TO result.
      APPEND VALUE #( name = `=`  value = no ) TO result.
      RETURN.
    ENDIF.
    LOOP AT is_field-value_help-fixed_values INTO DATA(ls_value).
      APPEND VALUE #( name  = |={ ls_value-name }|
                      value = COND #( WHEN ls_value-value IS INITIAL THEN ls_value-name
                                      ELSE |{ ls_value-value } ({ ls_value-name })| ) ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD selection_variant_filters.

    DATA lt_words TYPE string_table.
    DATA lt_found TYPE ty_t_name_value.
    DATA lv_failed TYPE abap_bool.
    DATA lv_value TYPE string.
    DATA lv_index TYPE i.
    DATA lv_field TYPE string.
    DATA lv_op TYPE string.

    CLEAR: filters, where.
    LOOP AT is_variant-select_options INTO DATA(ls_option).
      IF line_exists( it_fields[ name = ls_option-name ] ).
        APPEND ls_option TO filters.
      ENDIF.
    ENDLOOP.
    IF is_variant-filter IS INITIAL.
      RETURN.
    ENDIF.

    "an AND of single comparisons (Field OP Value) becomes filter values,
    "anything else is applied as it is
    DATA(lv_filter) = condense( is_variant-filter ).
    IF lv_filter CA `()` OR to_upper( lv_filter ) CS ` OR `.
      lv_failed = abap_true.
    ELSE.
      SPLIT lv_filter AT ` ` INTO TABLE lt_words.
      DELETE lt_words WHERE table_line IS INITIAL.
      lv_index = 1.
      WHILE lv_index <= lines( lt_words ) AND lv_failed = abap_false.
        IF lv_index + 2 > lines( lt_words ).
          lv_failed = abap_true.
          EXIT.
        ENDIF.
        lv_field = to_upper( lt_words[ lv_index ] ).
        lv_op = to_upper( lt_words[ lv_index + 1 ] ).
        lv_value = strip_quotes( lt_words[ lv_index + 2 ] ).
        lv_value = SWITCH #( lv_op
          WHEN `EQ` OR `=`         THEN |={ lv_value }|
          WHEN `NE` OR `<>` OR `!=` THEN |!={ lv_value }|
          WHEN `GT` OR `>`         THEN |>{ lv_value }|
          WHEN `GE` OR `>=`        THEN |>={ lv_value }|
          WHEN `LT` OR `<`         THEN |<{ lv_value }|
          WHEN `LE` OR `<=`        THEN |<={ lv_value }|
          ELSE `` ).
        IF lv_value IS INITIAL OR NOT line_exists( it_fields[ name = lv_field ] )
          OR line_exists( filters[ name = lv_field ] ) OR line_exists( lt_found[ name = lv_field ] ).
          lv_failed = abap_true.
          EXIT.
        ENDIF.
        APPEND VALUE #( name = lv_field value = lv_value ) TO lt_found.
        lv_index = lv_index + 3.
        IF lv_index <= lines( lt_words ).
          IF to_upper( lt_words[ lv_index ] ) <> `AND`.
            lv_failed = abap_true.
            EXIT.
          ENDIF.
          lv_index = lv_index + 1.
          IF lv_index > lines( lt_words ).
            lv_failed = abap_true.
          ENDIF.
        ENDIF.
      ENDWHILE.
    ENDIF.

    IF lv_failed = abap_true.
      where = selection_filter_to_where( filter    = is_variant-filter
                                         it_fields = it_fields ).
      RETURN.
    ENDIF.
    APPEND LINES OF lt_found TO filters.

  ENDMETHOD.


  METHOD selection_variant_where.

    DATA lt_and TYPE string_table.

    IF is_variant-filter IS NOT INITIAL.
      DATA(lv_filter_where) = selection_filter_to_where( filter    = is_variant-filter
                                                         it_fields = it_fields ).
      IF lv_filter_where IS NOT INITIAL.
        APPEND lv_filter_where TO lt_and.
      ENDIF.
    ENDIF.
    LOOP AT is_variant-select_options INTO DATA(ls_option).
      READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = ls_option-name.
      IF sy-subrc <> 0 OR ls_field-is_virtual = abap_true.
        CONTINUE.
      ENDIF.
      DATA(lv_cond) = build_filter_condition( is_field = ls_field
                                              value    = ls_option-value ).
      IF lv_cond IS NOT INITIAL.
        APPEND lv_cond TO lt_and.
      ENDIF.
    ENDLOOP.
    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD get_line_item_columns.

    DATA ls_column TYPE ty_s_field_info.

    IF qualifier IS INITIAL.
      LOOP AT it_fields INTO ls_column WHERE line_item_pos > 0 AND is_hidden = abap_false.
        APPEND ls_column TO result.
      ENDLOOP.
      SORT result STABLE BY line_item_pos.
      RETURN.
    ENDIF.

    LOOP AT it_fields INTO ls_column WHERE is_hidden = abap_false.
      READ TABLE ls_column-line_items INTO DATA(ls_entry) WITH KEY qualifier = qualifier.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_column-line_item_pos = ls_entry-position.
      ls_column-line_item_label = ls_entry-label.
      ls_column-line_item_importance = ls_entry-importance.
      ls_column-is_high_importance = xsdbool( ls_entry-importance CS `HIGH` ).
      ls_column-line_item_crit_field = ls_entry-criticality.
      ls_column-line_item_crit_repr = ls_entry-crit_representation.
      ls_column-line_item_value_qualifier = ls_entry-value_qualifier.
      ls_column-line_item_hidden = ls_entry-hidden.
      ls_column-line_item_width = ls_entry-width.
      ls_column-line_item_icon_url = ls_entry-icon_url.
      "a link type keeps the unqualified entry's target - the qualified one
      "is a plain column unless it says otherwise
      IF ls_entry-type <> ls_column-line_item_type.
        ls_column-line_item_type = ls_entry-type.
      ENDIF.
      APPEND ls_column TO result.
    ENDLOOP.
    SORT result STABLE BY line_item_pos.

  ENDMETHOD.


  METHOD criticality_binding.

    DATA(lv_crit) = to_upper( condense( criticality ) ).
    lv_crit = replace( val = lv_crit sub = `#` with = `` ).
    IF lv_crit IS INITIAL.
      RETURN.
    ENDIF.

    "a literal: the state (or icon) itself
    IF lv_crit CO `0123456789` OR lv_crit = `POSITIVE` OR lv_crit = `NEGATIVE` OR lv_crit = `CRITICAL`
      OR lv_crit = `NEUTRAL` OR lv_crit = `INFORMATION`.
      DATA(lv_level) = SWITCH string( lv_crit
        WHEN `1` OR `NEGATIVE`    THEN `1`
        WHEN `2` OR `CRITICAL`    THEN `2`
        WHEN `3` OR `POSITIVE`    THEN `3`
        WHEN `5` OR `INFORMATION` THEN `5`
        ELSE `0` ).
      IF kind = `ICON`.
        result = SWITCH #( lv_level
          WHEN `1` THEN `sap-icon://error`
          WHEN `2` THEN `sap-icon://alert`
          WHEN `3` THEN `sap-icon://sys-enter-2`
          WHEN `5` THEN `sap-icon://message-information`
          ELSE `` ).
      ELSE.
        result = SWITCH #( lv_level
          WHEN `1` THEN `Error`
          WHEN `2` THEN `Warning`
          WHEN `3` THEN `Success`
          WHEN `5` THEN `Information`
          ELSE `None` ).
      ENDIF.
      RETURN.
    ENDIF.

    "a field: 1 negative, 2 critical, 3 positive, 5 information, 0 and
    "every other value neutral
    DATA(lv_path) = `${` && lv_crit && `}`.
    IF kind = `ICON`.
      result = `{= ` && lv_path && ` === 3 ? 'sap-icon://sys-enter-2' : (` &&
               lv_path && ` === 1 ? 'sap-icon://error' : (` &&
               lv_path && ` === 2 ? 'sap-icon://alert' : (` &&
               lv_path && ` === 5 ? 'sap-icon://message-information' : ''))) }`.
      RETURN.
    ENDIF.
    result = `{= ` && lv_path && ` === 3 ? 'Success' : (` &&
             lv_path && ` === 1 ? 'Error' : (` &&
             lv_path && ` === 2 ? 'Warning' : (` &&
             lv_path && ` === 5 ? 'Information' : 'None'))) }`.

  ENDMETHOD.


  METHOD get_navigation_params.

    FIELD-SYMBOLS <lv_value> TYPE any.

    IF field IS NOT INITIAL.
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT field OF STRUCTURE row TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED.
        RETURN.
      ENDIF.
      READ TABLE bindings INTO DATA(ls_own) WITH KEY local_element = to_upper( field ).
      APPEND VALUE #( name  = COND #( WHEN sy-subrc = 0 AND ls_own-element IS NOT INITIAL THEN ls_own-element
                                      ELSE to_upper( field ) )
                      value = condense( |{ <lv_value> }| ) ) TO result.
    ENDIF.
    LOOP AT bindings INTO DATA(ls_binding) WHERE local_element IS NOT INITIAL.
      IF field IS NOT INITIAL AND ls_binding-local_element = to_upper( field ).
        CONTINUE.
      ENDIF.
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT ls_binding-local_element OF STRUCTURE row TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      DATA(lv_name) = COND string( WHEN ls_binding-element IS NOT INITIAL THEN ls_binding-element
                                   ELSE ls_binding-local_element ).
      IF line_exists( result[ name = lv_name ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = lv_name value = condense( |{ <lv_value> }| ) ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD normalize_css_width.

    DATA lv_number TYPE string.
    DATA(lv_width) = to_lower( val ).
    CONDENSE lv_width NO-GAPS.
    IF lv_width IS INITIAL.
      RETURN.
    ENDIF.
    IF lv_width = `auto`.
      result = lv_width.
      RETURN.
    ENDIF.
    DATA(lv_unit) = ``.
    DATA(lv_len) = strlen( lv_width ).
    IF lv_len > 3 AND substring( val = lv_width off = lv_len - 3 ) = `rem`.
      lv_unit = `rem`.
    ELSEIF lv_len > 2 AND ( substring( val = lv_width off = lv_len - 2 ) = `px`
                         OR substring( val = lv_width off = lv_len - 2 ) = `em` ).
      lv_unit = substring( val = lv_width off = lv_len - 2 ).
    ELSEIF lv_len > 1 AND substring( val = lv_width off = lv_len - 1 ) = `%`.
      lv_unit = `%`.
    ENDIF.
    lv_number = substring( val = lv_width len = lv_len - strlen( lv_unit ) ).
    IF lv_number IS INITIAL OR lv_number CN `0123456789.` OR lv_number CS `..` OR lv_number(1) = `.`.
      RETURN.
    ENDIF.
    result = |{ lv_number }{ COND string( WHEN lv_unit IS INITIAL THEN `rem` ELSE lv_unit ) }|.

  ENDMETHOD.

ENDCLASS.
