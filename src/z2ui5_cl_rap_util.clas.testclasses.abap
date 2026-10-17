" apply_annotations( ) on plain key/value tables - the way GET_ANNOS hands
" annotations over: upper-case names, array entries as $n$, strings in
" single quotes, enum values with #. No system is needed, so these run
" transpiled in CI (npm run unit) as well as in a system.
CLASS ltcl_annotations DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_entity TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    METHODS setup.

    METHODS apply
      IMPORTING
        it_entity   TYPE z2ui5_cl_rap_util=>ty_t_annotation OPTIONAL
        it_elements TYPE z2ui5_cl_rap_util=>ty_t_element_annotation OPTIONAL.

    METHODS field
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    METHODS line_item_default_entry   FOR TESTING RAISING cx_static_check.
    METHODS line_item_non_array       FOR TESTING RAISING cx_static_check.
    METHODS line_item_actions         FOR TESTING RAISING cx_static_check.
    METHODS identification_actions    FOR TESTING RAISING cx_static_check.
    METHODS field_groups_all_entries  FOR TESTING RAISING cx_static_check.
    METHODS facets_on_element         FOR TESTING RAISING cx_static_check.
    METHODS text_element_array        FOR TESTING RAISING cx_static_check.
    METHODS value_help_bindings       FOR TESTING RAISING cx_static_check.
    METHODS chart_entries             FOR TESTING RAISING cx_static_check.
    METHODS header_info_and_keys      FOR TESTING RAISING cx_static_check.
    METHODS flags_and_semantics       FOR TESTING RAISING cx_static_check.
    METHODS label_fallback            FOR TESTING RAISING cx_static_check.
    METHODS prefix_is_not_a_match     FOR TESTING RAISING cx_static_check.
    METHODS strip_quotes              FOR TESTING RAISING cx_static_check.
    METHODS json_escape               FOR TESTING RAISING cx_static_check.
    METHODS admin_fields              FOR TESTING RAISING cx_static_check.
    METHODS consumption_filter        FOR TESTING RAISING cx_static_check.
    METHODS line_item_types           FOR TESTING RAISING cx_static_check.
    METHODS intent_navigation_entries FOR TESTING RAISING cx_static_check.
    METHODS identification_qualified  FOR TESTING RAISING cx_static_check.
    METHODS action_groups_and_props   FOR TESTING RAISING cx_static_check.
    METHODS field_group_actions       FOR TESTING RAISING cx_static_check.
    METHODS actions_by_position       FOR TESTING RAISING cx_static_check.
    METHODS hidden_operations         FOR TESTING RAISING cx_static_check.
    METHODS header_type_image         FOR TESTING RAISING cx_static_check.
    METHODS button_type_criticality   FOR TESTING RAISING cx_static_check.
    METHODS static_action_line        FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_annotations IMPLEMENTATION.

  METHOD setup.
    ms_entity = VALUE #(
      name   = `Z_TRAVEL`
      fields = VALUE #( ( name = `TRAVELID`      is_visible = abap_true type_kind = `CHAR` )
                        ( name = `AGENCYID`      is_visible = abap_true type_kind = `CHAR` )
                        ( name = `AGENCYNAME`    is_visible = abap_true type_kind = `CHAR` )
                        ( name = `STATUS`        is_visible = abap_true type_kind = `CHAR` )
                        ( name = `STATUSCRIT`    is_visible = abap_true type_kind = `INT` )
                        ( name = `TOTALPRICE`    is_visible = abap_true type_kind = `DEC` )
                        ( name = `CURRENCYCODE`  is_visible = abap_true type_kind = `CHAR` ) ) ).
  ENDMETHOD.


  METHOD apply.
    z2ui5_cl_rap_util=>apply_annotations( EXPORTING it_entity   = it_entity
                                                    it_elements = it_elements
                                          CHANGING  cs_entity   = ms_entity ).
  ENDMETHOD.


  METHOD field.
    READ TABLE ms_entity-fields INTO result WITH KEY name = name.
    cl_abap_unit_assert=>assert_subrc( msg = |field { name }| ).
  ENDMETHOD.


  METHOD line_item_default_entry.

    " a qualified entry and an action entry come first - the column is the
    " unqualified one that is not an action
    apply( it_elements = VALUE #(
      ( element = `Status` key = `UI.LINEITEM$1$.POSITION`   value = `50` )
      ( element = `Status` key = `UI.LINEITEM$1$.QUALIFIER`  value = `'Other'` )
      ( element = `Status` key = `UI.LINEITEM$2$.TYPE`       value = `#FOR_ACTION` )
      ( element = `Status` key = `UI.LINEITEM$2$.DATAACTION` value = `'accept'` )
      ( element = `Status` key = `UI.LINEITEM$3$.POSITION`   value = `30` )
      ( element = `Status` key = `UI.LINEITEM$3$.IMPORTANCE` value = `#HIGH` )
      ( element = `Status` key = `UI.LINEITEM$3$.LABEL`      value = `'State'` )
      ( element = `Status` key = `UI.LINEITEM$3$.CRITICALITY` value = `'StatusCrit'` ) ) ).

    DATA(ls_field) = field( `STATUS` ).
    cl_abap_unit_assert=>assert_equals( exp = 30          act = ls_field-line_item_pos ).
    cl_abap_unit_assert=>assert_equals( exp = `#HIGH`     act = ls_field-line_item_importance ).
    cl_abap_unit_assert=>assert_true( ls_field-is_high_importance ).
    cl_abap_unit_assert=>assert_equals( exp = `State`     act = ls_field-line_item_label ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = ls_field-line_item_crit_field ).

  ENDMETHOD.


  METHOD line_item_non_array.

    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.LINEITEM.POSITION` value = `10` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 10 act = field( `TRAVELID` )-line_item_pos ).

  ENDMETHOD.


  METHOD line_item_actions.

    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.POSITION`   value = `10` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.TYPE`       value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.DATAACTION` value = `'acceptTravel'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.LABEL`      value = `'Accept'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.POSITION`   value = `20` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.TYPE`       value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.DATAACTION` value = `'copy'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.INLINE`     value = `true` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( ms_entity-actions ) ).
    READ TABLE ms_entity-actions INTO DATA(ls_accept) WITH KEY name = `ACCEPTTRAVEL`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `Accept`   act = ls_accept-label ).
    cl_abap_unit_assert=>assert_equals( exp = `LINEITEM` act = ls_accept-source ).
    cl_abap_unit_assert=>assert_false( ls_accept-inline ).

    READ TABLE ms_entity-actions INTO DATA(ls_copy) WITH KEY name = `COPY`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_true( ls_copy-inline ).
    " no label - the action's name stands in
    cl_abap_unit_assert=>assert_equals( exp = `COPY` act = ls_copy-label ).

    " the action entries do not make the column
    cl_abap_unit_assert=>assert_equals( exp = 10 act = field( `TRAVELID` )-line_item_pos ).

  ENDMETHOD.


  METHOD identification_actions.

    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$1$.POSITION`   value = `10` )
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$2$.TYPE`       value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$2$.DATAACTION` value = `'rejectTravel'` ) ) ).

    DATA(ls_field) = field( `TRAVELID` ).
    cl_abap_unit_assert=>assert_true( ls_field-is_identification ).
    cl_abap_unit_assert=>assert_equals( exp = 10 act = ls_field-identification_pos ).
    cl_abap_unit_assert=>assert_equals( exp = `IDENTIFICATION` act = ms_entity-actions[ 1 ]-source ).
    cl_abap_unit_assert=>assert_equals( exp = `REJECTTRAVEL`   act = ms_entity-actions[ 1 ]-name ).

  ENDMETHOD.


  METHOD field_groups_all_entries.

    apply( it_elements = VALUE #(
      ( element = `AGENCYID` key = `UI.FIELDGROUP$1$.QUALIFIER` value = `'General'` )
      ( element = `AGENCYID` key = `UI.FIELDGROUP$1$.POSITION`  value = `20` )
      ( element = `AGENCYID` key = `UI.FIELDGROUP$2$.QUALIFIER` value = `'Agency'` )
      ( element = `AGENCYID` key = `UI.FIELDGROUP$2$.POSITION`  value = `10` )
      ( element = `AGENCYID` key = `UI.FIELDGROUP$2$.LABEL`     value = `'ID'` )
      ( element = `AGENCYID` key = `UI.FIELDGROUP$2$.GROUPLABEL` value = `'Travel Agency'` ) ) ).

    DATA(ls_field) = field( `AGENCYID` ).
    cl_abap_unit_assert=>assert_equals( exp = 2         act = lines( ls_field-field_groups ) ).
    cl_abap_unit_assert=>assert_equals( exp = `General` act = ls_field-field_group ).
    cl_abap_unit_assert=>assert_equals( exp = 20        act = ls_field-field_group_pos ).
    cl_abap_unit_assert=>assert_equals( exp = `Agency`  act = ls_field-field_groups[ 2 ]-qualifier ).
    cl_abap_unit_assert=>assert_equals( exp = 10        act = ls_field-field_groups[ 2 ]-position ).
    " the field's label in the group and the group's title are two things
    cl_abap_unit_assert=>assert_equals( exp = `ID`            act = ls_field-field_groups[ 2 ]-label ).
    cl_abap_unit_assert=>assert_equals( exp = `Travel Agency` act = ls_field-field_groups[ 2 ]-group_label ).

  ENDMETHOD.


  METHOD facets_on_element.

    " RAP metadata extensions put @UI.facet on the first element
    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.FACET$1$.ID`              value = `'Travel'` )
      ( element = `TRAVELID` key = `UI.FACET$1$.TYPE`            value = `#COLLECTION` )
      ( element = `TRAVELID` key = `UI.FACET$1$.POSITION`        value = `10` )
      ( element = `TRAVELID` key = `UI.FACET$1$.LABEL`           value = `'Travel'` )
      ( element = `TRAVELID` key = `UI.FACET$2$.ID`              value = `'General'` )
      ( element = `TRAVELID` key = `UI.FACET$2$.PARENTID`        value = `'Travel'` )
      ( element = `TRAVELID` key = `UI.FACET$2$.TYPE`            value = `#FIELDGROUP_REFERENCE` )
      ( element = `TRAVELID` key = `UI.FACET$2$.TARGETQUALIFIER` value = `'General'` )
      ( element = `TRAVELID` key = `UI.FACET$2$.POSITION`        value = `20` )
      ( element = `TRAVELID` key = `UI.FACET$3$.ID`              value = `'Booking'` )
      ( element = `TRAVELID` key = `UI.FACET$3$.TYPE`            value = `#LINEITEM_REFERENCE` )
      ( element = `TRAVELID` key = `UI.FACET$3$.TARGETELEMENT`   value = `'_Booking'` )
      ( element = `TRAVELID` key = `UI.FACET$3$.POSITION`        value = `30` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( ms_entity-facets ) ).
    cl_abap_unit_assert=>assert_equals( exp = `#COLLECTION` act = ms_entity-facets[ 1 ]-type ).
    cl_abap_unit_assert=>assert_equals( exp = `Travel`      act = ms_entity-facets[ 2 ]-parent_id ).
    cl_abap_unit_assert=>assert_equals( exp = `General`     act = ms_entity-facets[ 2 ]-target_qualifier ).
    cl_abap_unit_assert=>assert_equals( exp = `_BOOKING`    act = ms_entity-facets[ 3 ]-target_element ).

  ENDMETHOD.


  METHOD text_element_array.

    apply( it_elements = VALUE #(
      ( element = `AGENCYID` key = `OBJECTMODEL.TEXT.ELEMENT$1$` value = `'AgencyName'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `AGENCYNAME` act = field( `AGENCYID` )-text_element ).

  ENDMETHOD.


  METHOD value_help_bindings.

    apply( it_elements = VALUE #(
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ENTITY.NAME`    value = `'/DMO/I_Agency'` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ENTITY.ELEMENT` value = `'AgencyID'` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ADDITIONALBINDING$1$.ELEMENT`      value = `'Name'` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ADDITIONALBINDING$1$.LOCALELEMENT` value = `'AgencyName'` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ADDITIONALBINDING$1$.USAGE`        value = `#RESULT` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ADDITIONALBINDING$2$.ELEMENT`      value = `'CountryCode'` )
      ( element = `AGENCYID` key = `CONSUMPTION.VALUEHELPDEFINITION$1$.ADDITIONALBINDING$2$.LOCALELEMENT` value = `'Country'` ) ) ).

    DATA(ls_vh) = field( `AGENCYID` )-value_help.
    cl_abap_unit_assert=>assert_equals( exp = `/DMO/I_AGENCY` act = ls_vh-entity_name ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCYID`      act = ls_vh-element ).
    cl_abap_unit_assert=>assert_equals( exp = 2               act = lines( ls_vh-additional_binding ) ).
    cl_abap_unit_assert=>assert_equals( exp = `NAME`          act = ls_vh-additional_binding[ 1 ]-element ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCYNAME`    act = ls_vh-additional_binding[ 1 ]-local_element ).
    cl_abap_unit_assert=>assert_equals( exp = `#RESULT`       act = ls_vh-additional_binding[ 1 ]-usage ).
    cl_abap_unit_assert=>assert_equals( exp = `COUNTRY`       act = ls_vh-additional_binding[ 2 ]-local_element ).
    cl_abap_unit_assert=>assert_initial( ls_vh-additional_binding[ 2 ]-usage ).

  ENDMETHOD.


  METHOD chart_entries.

    apply( it_entity = VALUE #(
      ( key = `UI.CHART$1$.QUALIFIER`      value = `'ByStatus'` )
      ( key = `UI.CHART$1$.CHARTTYPE`      value = `#BAR` )
      ( key = `UI.CHART$1$.TITLE`          value = `'Price by status'` )
      ( key = `UI.CHART$1$.DIMENSIONS$1$`  value = `'Status'` )
      ( key = `UI.CHART$1$.MEASURES$1$`    value = `'TotalPrice'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( ms_entity-charts ) ).
    DATA(ls_chart) = ms_entity-charts[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = `ByStatus`        act = ls_chart-qualifier ).
    cl_abap_unit_assert=>assert_equals( exp = `Price by status` act = ls_chart-title ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`          act = ls_chart-dimensions[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = `TOTALPRICE`      act = ls_chart-measures[ 1 ] ).

  ENDMETHOD.


  METHOD header_info_and_keys.

    apply( it_entity = VALUE #(
      ( key = `UI.HEADERINFO.TYPENAME`          value = `'Travel'` )
      ( key = `UI.HEADERINFO.TYPENAMEPLURAL`    value = `'Travels'` )
      ( key = `UI.HEADERINFO.TITLE.VALUE`       value = `'TravelID'` )
      ( key = `UI.HEADERINFO.DESCRIPTION.VALUE` value = `'AgencyName'` )
      ( key = `OBJECTMODEL.SEMANTICKEY$1$`      value = `'TravelID'` )
      ( key = `SEARCH.SEARCHABLE`               value = `true` )
      ( key = `ENDUSERTEXT.LABEL`               value = `'Travel'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `Travels`    act = ms_entity-header_info-type_name_plural ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID`   act = ms_entity-header_info-title_field ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCYNAME` act = ms_entity-header_info-description_field ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID`   act = ms_entity-semantic_key[ 1 ] ).
    cl_abap_unit_assert=>assert_true( ms_entity-is_searchable ).
    cl_abap_unit_assert=>assert_equals( exp = `Travel`     act = ms_entity-description ).

  ENDMETHOD.


  METHOD flags_and_semantics.

    apply( it_elements = VALUE #(
      ( element = `STATUS`       key = `UI.HIDDEN`                          value = `true` )
      ( element = `TRAVELID`     key = `OBJECTMODEL.MANDATORY`              value = `true` )
      ( element = `TRAVELID`     key = `OBJECTMODEL.READONLY`               value = `true` )
      ( element = `TOTALPRICE`   key = `SEMANTICS.AMOUNT.CURRENCYCODE`      value = `'CurrencyCode'` )
      ( element = `STATUS`       key = `CONSUMPTION.FILTER.DEFAULTVALUE`    value = `'O'` )
      ( element = `AGENCYID`     key = `UI.SELECTIONFIELD$1$.POSITION`      value = `20` )
      ( element = `STATUSCRIT`   key = `UI.DATAPOINT.CRITICALITY`           value = `'StatusCrit'` ) ) ).

    cl_abap_unit_assert=>assert_true( field( `STATUS` )-is_hidden ).
    cl_abap_unit_assert=>assert_equals( exp = `O` act = field( `STATUS` )-filter_default ).
    cl_abap_unit_assert=>assert_true( field( `TRAVELID` )-is_mandatory ).
    cl_abap_unit_assert=>assert_true( field( `TRAVELID` )-is_readonly ).
    cl_abap_unit_assert=>assert_true( field( `TOTALPRICE` )-is_amount_field ).
    cl_abap_unit_assert=>assert_equals( exp = `CURRENCYCODE` act = field( `TOTALPRICE` )-semantics_currency_code ).
    cl_abap_unit_assert=>assert_true( field( `AGENCYID` )-is_selection_field ).
    cl_abap_unit_assert=>assert_equals( exp = 20 act = field( `AGENCYID` )-selection_field_pos ).
    " a data point without a qualifier is still a data point
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = field( `STATUSCRIT` )-datapoint_qualifier ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = field( `STATUSCRIT` )-datapoint_crit_field ).

  ENDMETHOD.


  METHOD label_fallback.

    ms_entity-fields[ name = `AGENCYNAME` ]-label = `Agency (DDIC)`.
    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `ENDUSERTEXT.LABEL` value = `'Travel ID'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `Travel ID`     act = field( `TRAVELID` )-label ).
    " the data element text read_entity puts in first stays
    cl_abap_unit_assert=>assert_equals( exp = `Agency (DDIC)` act = field( `AGENCYNAME` )-label ).
    " nothing at all - the name
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`        act = field( `STATUS` )-label ).

  ENDMETHOD.


  METHOD prefix_is_not_a_match.

    " UI.LINEITEMS... is another annotation that only shares the prefix
    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.LINEITEMSX.POSITION` value = `10` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = field( `TRAVELID` )-line_item_pos ).

  ENDMETHOD.


  METHOD strip_quotes.

    cl_abap_unit_assert=>assert_equals( exp = `abc` act = z2ui5_cl_rap_util=>strip_quotes( `'abc'` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `abc` act = z2ui5_cl_rap_util=>strip_quotes( ` 'abc' ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `#HIGH` act = z2ui5_cl_rap_util=>strip_quotes( `#HIGH` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>strip_quotes( `` ) ).

  ENDMETHOD.

  METHOD admin_fields.

    apply( it_elements = VALUE #(
      ( element = `AgencyID`   key = `SEMANTICS.USER.CREATEDBY`             value = `true` )
      ( element = `AgencyName` key = `SEMANTICS.SYSTEMDATETIME.CREATEDAT`   value = `true` )
      ( element = `Status`     key = `SEMANTICS.SYSTEMDATETIME.LOCALINSTANCELASTCHANGEDAT` value = `true` )
      ( element = `TravelID`   key = `SEMANTICS.USER.LASTCHANGEDBY`         value = `false` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = field( `AGENCYID` )-admin_field
                                        exp = `CREATED_BY` ).
    cl_abap_unit_assert=>assert_equals( act = field( `AGENCYNAME` )-admin_field
                                        exp = `CREATED_AT` ).
    cl_abap_unit_assert=>assert_equals( act = field( `STATUS` )-admin_field
                                        exp = `LOCAL_LAST_CHANGED_AT` ).
    cl_abap_unit_assert=>assert_initial( field( `TRAVELID` )-admin_field ).

  ENDMETHOD.

  METHOD consumption_filter.

    apply( it_elements = VALUE #(
      ( element = `Status`       key = `CONSUMPTION.FILTER.SELECTIONTYPE`      value = `#SINGLE` )
      ( element = `Status`       key = `CONSUMPTION.FILTER.MANDATORY`          value = `true` )
      ( element = `AgencyID`     key = `CONSUMPTION.FILTER.MULTIPLESELECTIONS` value = `false` )
      ( element = `AgencyName`   key = `CONSUMPTION.FILTER.HIDDEN`             value = `true` )
      ( element = `TotalPrice`   key = `CONSUMPTION.FILTER.SELECTIONTYPE`      value = `#INTERVAL` ) ) ).

    cl_abap_unit_assert=>assert_true( field( `STATUS` )-filter_single ).
    cl_abap_unit_assert=>assert_true( field( `STATUS` )-filter_mandatory ).
    cl_abap_unit_assert=>assert_true( field( `AGENCYID` )-filter_single ).
    cl_abap_unit_assert=>assert_true( field( `AGENCYNAME` )-filter_hidden ).
    cl_abap_unit_assert=>assert_equals( act = field( `TOTALPRICE` )-filter_selection_type
                                        exp = `INTERVAL` ).
    cl_abap_unit_assert=>assert_false( field( `TOTALPRICE` )-filter_single ).

  ENDMETHOD.


  METHOD line_item_types.

    apply( it_elements = VALUE #(
      ( element = `TravelID`  key = `UI.LINEITEM$1$.POSITION`       value = `10` )
      ( element = `TravelID`  key = `UI.LINEITEM$1$.TYPE`           value = `#WITH_URL` )
      ( element = `TravelID`  key = `UI.LINEITEM$1$.URL`            value = `'AgencyName'` )
      ( element = `AgencyID`  key = `UI.LINEITEM$1$.POSITION`       value = `20` )
      ( element = `AgencyID`  key = `UI.LINEITEM$1$.TYPE`           value = `#WITH_NAVIGATION_PATH` )
      ( element = `AgencyID`  key = `UI.LINEITEM$1$.TARGETELEMENT`  value = `'_Agency'` )
      ( element = `Status`    key = `UI.LINEITEM$1$.POSITION`       value = `30` )
      ( element = `Status`    key = `UI.LINEITEM$1$.TYPE`           value = `#WITH_INTENT_BASED_NAVIGATION` )
      ( element = `Status`    key = `UI.LINEITEM$1$.SEMANTICOBJECT` value = `'Travel'` )
      ( element = `Status`    key = `UI.LINEITEM$1$.SEMANTICOBJECTACTION` value = `'manage'` ) ) ).

    DATA(ls_url) = field( `TRAVELID` ).
    cl_abap_unit_assert=>assert_equals( act = ls_url-line_item_type
                                        exp = `WITH_URL` ).
    cl_abap_unit_assert=>assert_equals( act = ls_url-line_item_url
                                        exp = `AGENCYNAME` ).
    cl_abap_unit_assert=>assert_equals( act = ls_url-line_item_pos
                                        exp = 10 ).
    cl_abap_unit_assert=>assert_equals( act = field( `AGENCYID` )-line_item_target
                                        exp = `_AGENCY` ).
    DATA(ls_intent) = field( `STATUS` ).
    cl_abap_unit_assert=>assert_equals( act = ls_intent-line_item_sem_object
                                        exp = `Travel` ).
    cl_abap_unit_assert=>assert_equals( act = ls_intent-line_item_sem_action
                                        exp = `manage` ).

  ENDMETHOD.


  METHOD intent_navigation_entries.

    apply( it_elements = VALUE #(
      ( element = `TravelID` key = `UI.LINEITEM$1$.POSITION`             value = `10` )
      ( element = `TravelID` key = `UI.LINEITEM$2$.TYPE`                 value = `#FOR_INTENT_BASED_NAVIGATION` )
      ( element = `TravelID` key = `UI.LINEITEM$2$.SEMANTICOBJECT`       value = `'Travel'` )
      ( element = `TravelID` key = `UI.LINEITEM$2$.SEMANTICOBJECTACTION` value = `'display'` )
      ( element = `TravelID` key = `UI.LINEITEM$2$.LABEL`                value = `'Open'` ) ) ).

    READ TABLE ms_entity-actions INTO DATA(ls_action) WITH KEY semantic_object = `Travel`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_action-name
                                        exp = `INTENT~TRAVEL~DISPLAY` ).
    cl_abap_unit_assert=>assert_equals( act = ls_action-label
                                        exp = `Open` ).
    "the column is still the field's - the navigation is no column entry
    cl_abap_unit_assert=>assert_equals( act = field( `TRAVELID` )-line_item_pos
                                        exp = 10 ).

  ENDMETHOD.

  METHOD json_escape.
    cl_abap_unit_assert=>assert_equals(
      act = z2ui5_cl_rap_util=>json_escape( |a"b\\c{ cl_abap_char_utilities=>newline }d| )
      exp = `a\"b\\c\nd` ).
  ENDMETHOD.


  METHOD identification_qualified.

    " an unqualified and a qualified entry: the field is in the header and
    " in the section of the qualifier - another field only in the section
    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$1$.POSITION`  value = `10` )
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$2$.POSITION`  value = `30` )
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$2$.QUALIFIER` value = `'Admin'` )
      ( element = `TRAVELID` key = `UI.IDENTIFICATION$2$.LABEL`     value = `'Travel number'` )
      ( element = `AGENCYID` key = `UI.IDENTIFICATION$1$.POSITION`  value = `20` )
      ( element = `AGENCYID` key = `UI.IDENTIFICATION$1$.QUALIFIER` value = `'Admin'` ) ) ).

    DATA(ls_travel) = field( `TRAVELID` ).
    cl_abap_unit_assert=>assert_true( ls_travel-is_identification ).
    cl_abap_unit_assert=>assert_equals( exp = 10 act = ls_travel-identification_pos ).
    cl_abap_unit_assert=>assert_equals( exp = 2  act = lines( ls_travel-identifications ) ).
    READ TABLE ls_travel-identifications INTO DATA(ls_admin) WITH KEY qualifier = `Admin`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = 30              act = ls_admin-position ).
    cl_abap_unit_assert=>assert_equals( exp = `Travel number` act = ls_admin-label ).

    " a qualified entry alone is no header attribute
    DATA(ls_agency) = field( `AGENCYID` ).
    cl_abap_unit_assert=>assert_false( ls_agency-is_identification ).
    cl_abap_unit_assert=>assert_equals( exp = `Admin` act = ls_agency-identifications[ 1 ]-qualifier ).

  ENDMETHOD.


  METHOD action_groups_and_props.

    apply( it_elements = VALUE #(
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.TYPE`               value = `#FOR_ACTION_GROUP` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.ID`                 value = `'Status'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.LABEL`              value = `'Change status'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.POSITION`           value = `5` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.TYPE`               value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.DATAACTION`         value = `'accept'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.ACTIONGROUPID`      value = `'Status'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.CRITICALITY`        value = `'3'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$2$.INVOCATIONGROUPING` value = `#ISOLATED` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.TYPE`               value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.DATAACTION`         value = `'reject'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$3$.CRITICALITY`        value = `'StatusCrit'` ) ) ).

    " the group is no action - it is the menu of its actions
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( ms_entity-actions ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( ms_entity-action_groups ) ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`        act = ms_entity-action_groups[ 1 ]-id ).
    cl_abap_unit_assert=>assert_equals( exp = `Change status` act = ms_entity-action_groups[ 1 ]-label ).
    cl_abap_unit_assert=>assert_equals( exp = `LINEITEM`      act = ms_entity-action_groups[ 1 ]-source ).

    READ TABLE ms_entity-actions INTO DATA(ls_accept) WITH KEY name = `ACCEPT`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`   act = ls_accept-group_id ).
    cl_abap_unit_assert=>assert_equals( exp = `3`        act = ls_accept-criticality ).
    cl_abap_unit_assert=>assert_equals( exp = `ISOLATED` act = ls_accept-invocation_grouping ).

    READ TABLE ms_entity-actions INTO DATA(ls_reject) WITH KEY name = `REJECT`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = ls_reject-criticality ).
    cl_abap_unit_assert=>assert_initial( ls_reject-group_id ).
    cl_abap_unit_assert=>assert_initial( ls_reject-invocation_grouping ).

  ENDMETHOD.


  METHOD field_group_actions.

    " a #FOR_ACTION entry of a field group is an action at that section,
    " not a field of the group; a qualified identification action likewise
    apply( it_elements = VALUE #(
      ( element = `STATUS` key = `UI.FIELDGROUP$1$.QUALIFIER`      value = `'Basic'` )
      ( element = `STATUS` key = `UI.FIELDGROUP$1$.POSITION`       value = `10` )
      ( element = `STATUS` key = `UI.FIELDGROUP$2$.QUALIFIER`      value = `'Other'` )
      ( element = `STATUS` key = `UI.FIELDGROUP$2$.TYPE`           value = `#FOR_ACTION` )
      ( element = `STATUS` key = `UI.FIELDGROUP$2$.DATAACTION`     value = `'recalc'` )
      ( element = `STATUS` key = `UI.IDENTIFICATION$1$.TYPE`       value = `#FOR_ACTION` )
      ( element = `STATUS` key = `UI.IDENTIFICATION$1$.DATAACTION` value = `'recalc'` )
      ( element = `STATUS` key = `UI.IDENTIFICATION$1$.QUALIFIER`  value = `'Admin'` ) ) ).

    DATA(ls_field) = field( `STATUS` ).
    cl_abap_unit_assert=>assert_equals( exp = 1       act = lines( ls_field-field_groups ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Basic` act = ls_field-field_group ).

    READ TABLE ms_entity-actions INTO DATA(ls_group_action) WITH KEY source = `FIELDGROUP`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `RECALC` act = ls_group_action-name ).
    cl_abap_unit_assert=>assert_equals( exp = `Other`  act = ls_group_action-qualifier ).
    READ TABLE ms_entity-actions INTO DATA(ls_ident_action) WITH KEY source = `IDENTIFICATION`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `Admin`  act = ls_ident_action-qualifier ).
    " no identification field - the action entry is none
    cl_abap_unit_assert=>assert_false( ls_field-is_identification ).

  ENDMETHOD.


  METHOD actions_by_position.

    " sorted by position over all elements - one without a position last
    apply( it_elements = VALUE #(
      ( element = `AGENCYID` key = `UI.LINEITEM$1$.TYPE`       value = `#FOR_ACTION` )
      ( element = `AGENCYID` key = `UI.LINEITEM$1$.DATAACTION` value = `'last'` )
      ( element = `STATUS`   key = `UI.LINEITEM$1$.TYPE`       value = `#FOR_ACTION` )
      ( element = `STATUS`   key = `UI.LINEITEM$1$.DATAACTION` value = `'second'` )
      ( element = `STATUS`   key = `UI.LINEITEM$1$.POSITION`   value = `20` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.TYPE`       value = `#FOR_ACTION` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.DATAACTION` value = `'first'` )
      ( element = `TRAVELID` key = `UI.LINEITEM$1$.POSITION`   value = `10` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `FIRST`  act = ms_entity-actions[ 1 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = `SECOND` act = ms_entity-actions[ 2 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = `LAST`   act = ms_entity-actions[ 3 ]-name ).

  ENDMETHOD.


  METHOD hidden_operations.

    apply( it_entity = VALUE #( ( key = `UI.CREATEHIDDEN` value = `true` )
                                ( key = `UI.UPDATEHIDDEN` value = `#(IsLocked)` )
                                ( key = `UI.DELETEHIDDEN` value = `false` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `TRUE`     act = ms_entity-create_hidden ).
    cl_abap_unit_assert=>assert_equals( exp = `ISLOCKED` act = ms_entity-update_hidden ).
    cl_abap_unit_assert=>assert_initial( ms_entity-delete_hidden ).

  ENDMETHOD.


  METHOD header_type_image.

    apply( it_entity = VALUE #( ( key = `UI.HEADERINFO.TYPEIMAGEURL` value = `'sap-icon://flight'` )
                                ( key = `UI.HEADERINFO.IMAGEURL`     value = `'AgencyName'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://flight` act = ms_entity-header_info-type_image_url ).
    cl_abap_unit_assert=>assert_equals( exp = `AGENCYNAME`        act = ms_entity-header_info-image_field ).

  ENDMETHOD.


  METHOD button_type_criticality.

    cl_abap_unit_assert=>assert_equals( exp = `Accept`     act = z2ui5_cl_rap_util=>criticality_button_type( `3` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Accept`     act = z2ui5_cl_rap_util=>criticality_button_type( `#POSITIVE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Reject`     act = z2ui5_cl_rap_util=>criticality_button_type( `1` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Reject`     act = z2ui5_cl_rap_util=>criticality_button_type( `negative` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Emphasized` act = z2ui5_cl_rap_util=>criticality_button_type( `2` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Default`    act = z2ui5_cl_rap_util=>criticality_button_type( `0` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Default`    act = z2ui5_cl_rap_util=>criticality_button_type( `` ) ).

  ENDMETHOD.


  METHOD static_action_line.

    " an instance action carries the key of its instance
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_static_action_line(
      VALUE #( ( `%CID_REF` ) ( `%KEY` ) ( `TRAVELID` ) ( `%PARAM` ) ) ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_static_action_line(
      VALUE #( ( `%TKY` ) ( `%IS_DRAFT` ) ) ) ).
    " a static one only its content ID and parameter
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_static_action_line(
      VALUE #( ( `%CID` ) ( `%PARAM` ) ) ) ).
    " nothing read - nothing says it is static
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_static_action_line( VALUE #( ) ) ).

  ENDMETHOD.

ENDCLASS.


" build_filter_condition( ) / build_search_condition( ) - the WHERE text the
" filter bar and the search field put into a dynamic SELECT. User text ends
" up in it, so what is escaped is asserted here as much as what matches.
CLASS ltcl_filter DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF cs_type,
        char TYPE string VALUE `CHAR`,
        dats TYPE string VALUE `DATS`,
        dec  TYPE string VALUE `DEC`,
      END OF cs_type.

    METHODS cond
      IMPORTING
        type_kind     TYPE string
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS contains_for_text   FOR TESTING RAISING cx_static_check.
    METHODS equals_for_numbers  FOR TESTING RAISING cx_static_check.
    METHODS pattern             FOR TESTING RAISING cx_static_check.
    METHODS exact_and_not       FOR TESTING RAISING cx_static_check.
    METHODS range_and_compare   FOR TESTING RAISING cx_static_check.
    METHODS several_are_ored    FOR TESTING RAISING cx_static_check.
    METHODS dates_internal      FOR TESTING RAISING cx_static_check.
    METHODS quotes_escaped      FOR TESTING RAISING cx_static_check.
    METHODS like_chars_escaped  FOR TESTING RAISING cx_static_check.
    METHODS empty_is_nothing    FOR TESTING RAISING cx_static_check.
    METHODS search_fields       FOR TESTING RAISING cx_static_check.
    METHODS raw_is_no_text      FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_filter IMPLEMENTATION.

  METHOD cond.
    result = z2ui5_cl_rap_util=>build_filter_condition(
      is_field = VALUE #( name = `F` type_kind = type_kind )
      value    = value ).
  ENDMETHOD.


  METHOD contains_for_text.
    cl_abap_unit_assert=>assert_equals( exp = `F LIKE '%abc%' ESCAPE '#'`
                                        act = cond( type_kind = cs_type-char value = `abc` ) ).
  ENDMETHOD.


  METHOD equals_for_numbers.
    cl_abap_unit_assert=>assert_equals( exp = `F = '12.5'`
                                        act = cond( type_kind = cs_type-dec value = `12,5` ) ).
  ENDMETHOD.


  METHOD pattern.
    cl_abap_unit_assert=>assert_equals( exp = `F LIKE 'a%c' ESCAPE '#'`
                                        act = cond( type_kind = cs_type-char value = `a*c` ) ).
  ENDMETHOD.


  METHOD exact_and_not.
    cl_abap_unit_assert=>assert_equals( exp = `F = 'US'`
                                        act = cond( type_kind = cs_type-char value = `=US` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `NOT ( F = 'US' )`
                                        act = cond( type_kind = cs_type-char value = `!=US` ) ).
  ENDMETHOD.


  METHOD range_and_compare.
    cl_abap_unit_assert=>assert_equals( exp = `F BETWEEN '1' AND '9'`
                                        act = cond( type_kind = cs_type-dec value = `1..9` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `F >= '5'`
                                        act = cond( type_kind = cs_type-dec value = `>=5` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `F < '5'`
                                        act = cond( type_kind = cs_type-dec value = `<5` ) ).
  ENDMETHOD.


  METHOD several_are_ored.
    cl_abap_unit_assert=>assert_equals( exp = `( F = 'DE' OR F = 'US' )`
                                        act = cond( type_kind = cs_type-char value = `=DE;=US` ) ).
  ENDMETHOD.


  METHOD dates_internal.
    cl_abap_unit_assert=>assert_equals( exp = `F = '20240115'`
                                        act = cond( type_kind = cs_type-dats value = `2024-01-15` ) ).
  ENDMETHOD.


  METHOD quotes_escaped.
    " a quote cannot end the literal - it is doubled
    cl_abap_unit_assert=>assert_equals( exp = `F = 'x'' OR ''1''=''1'`
                                        act = cond( type_kind = cs_type-char value = `=x' OR '1'='1` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `F LIKE '%x'' OR 1=1 --%' ESCAPE '#'`
                                        act = cond( type_kind = cs_type-char value = `x' OR 1=1 --` ) ).
  ENDMETHOD.


  METHOD like_chars_escaped.
    " the user's own % and _ are text, only * is a wildcard
    cl_abap_unit_assert=>assert_equals( exp = `F LIKE '%50#%#_off%' ESCAPE '#'`
                                        act = cond( type_kind = cs_type-char value = `50%_off` ) ).
  ENDMETHOD.


  METHOD empty_is_nothing.
    cl_abap_unit_assert=>assert_initial( cond( type_kind = cs_type-char value = `` ) ).
    cl_abap_unit_assert=>assert_initial( cond( type_kind = cs_type-char value = ` ; ` ) ).
    cl_abap_unit_assert=>assert_initial( cond( type_kind = cs_type-char value = `!` ) ).
  ENDMETHOD.


  METHOD search_fields.

    DATA(lt_fields) = VALUE z2ui5_cl_rap_util=>ty_t_field_info(
      ( name = `ID`    type_kind = `CHAR` )
      ( name = `NAME`  type_kind = `CHAR` )
      ( name = `PRICE` type_kind = `DEC` )
      ( name = `NOTE`  type_kind = `CHAR` is_hidden = abap_true ) ).

    " no search element - every visible text field
    cl_abap_unit_assert=>assert_equals(
      exp = `( UPPER( ID ) LIKE '%AB#%%' ESCAPE '#' OR UPPER( NAME ) LIKE '%AB#%%' ESCAPE '#' )`
      act = z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields search = `ab%` ) ).

    " a search element - only it
    lt_fields[ name = `NAME` ]-is_searchable = abap_true.
    cl_abap_unit_assert=>assert_equals(
      exp = `( UPPER( NAME ) LIKE '%X%' ESCAPE '#' )`
      act = z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields search = ` x ` ) ).

    cl_abap_unit_assert=>assert_initial(
      z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields search = `  ` ) ).

  ENDMETHOD.

  METHOD raw_is_no_text.

    " a UUID is compared, never LIKEd - LIKE on a RAW column is invalid SQL
    " and emptied the whole list
    cl_abap_unit_assert=>assert_equals( exp = `F = '0A1B'`
                                        act = cond( type_kind = `RAW` value = `0A1B` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>build_search_condition(
      it_fields = VALUE #( ( name = `UUID` type_kind = `RAW` ) ( name = `RATE` type_kind = `FLTP` ) )
      search    = `x` ) ).

  ENDMETHOD.

ENDCLASS.


" @UI.presentationVariant, @UI.selectionVariant, @UI.textArrangement and
" @UI.dataPoint.criticalityCalculation - the annotations the list report's
" sorting, the worklist's tabs, the text cells and the KPI cards read.
CLASS ltcl_variants DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_entity TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    METHODS setup.

    METHODS sort_order_default_variant   FOR TESTING RAISING cx_static_check.
    METHODS selection_variants           FOR TESTING RAISING cx_static_check.
    METHODS presentation_variants        FOR TESTING RAISING cx_static_check.
    METHODS selection_filter_where       FOR TESTING RAISING cx_static_check.
    METHODS selection_filter_unreadable  FOR TESTING RAISING cx_static_check.
    METHODS selection_filter_or          FOR TESTING RAISING cx_static_check.
    METHODS selection_filter_parentheses FOR TESTING RAISING cx_static_check.
    METHODS text_arrangement             FOR TESTING RAISING cx_static_check.
    METHODS criticality_maximize         FOR TESTING RAISING cx_static_check.
    METHODS criticality_minimize         FOR TESTING RAISING cx_static_check.
    METHODS criticality_target           FOR TESTING RAISING cx_static_check.
    METHODS criticality_incomplete       FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_variants IMPLEMENTATION.

  METHOD setup.
    ms_entity = VALUE #(
      fields = VALUE #( ( name = `TRAVELID` type_kind = `CHAR` )
                        ( name = `STATUS`   type_kind = `CHAR` )
                        ( name = `PRIORITY` type_kind = `INT` )
                        ( name = `AGENCYID` type_kind = `CHAR` ) ) ).
  ENDMETHOD.


  METHOD sort_order_default_variant.

    " the qualified variant comes first - the unqualified one is the default
    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #(
                  ( key = `UI.PRESENTATIONVARIANT$1$.QUALIFIER`            value = `'Other'` )
                  ( key = `UI.PRESENTATIONVARIANT$1$.SORTORDER$1$.BY`      value = `'AgencyID'` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.SORTORDER$1$.BY`      value = `'TravelID'` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.SORTORDER$1$.DIRECTION` value = `#DESC` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.SORTORDER$2$.BY`      value = `'Status'` ) )
                it_elements = VALUE #( )
      CHANGING  cs_entity   = ms_entity ).

    cl_abap_unit_assert=>assert_equals( exp = 2          act = lines( ms_entity-sort_order ) ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID` act = ms_entity-sort_order[ 1 ]-field ).
    cl_abap_unit_assert=>assert_true( ms_entity-sort_order[ 1 ]-descending ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS`   act = ms_entity-sort_order[ 2 ]-field ).
    cl_abap_unit_assert=>assert_false( ms_entity-sort_order[ 2 ]-descending ).

  ENDMETHOD.


  METHOD selection_variants.

    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #(
                  ( key = `UI.SELECTIONVARIANT$1$.QUALIFIER` value = `'Open'` )
                  ( key = `UI.SELECTIONVARIANT$1$.TEXT`      value = `'Open travels'` )
                  ( key = `UI.SELECTIONVARIANT$1$.FILTER`    value = `'Status EQ O'` )
                  ( key = `UI.SELECTIONVARIANT$2$.QUALIFIER` value = `'NoFilter'` )
                  ( key = `UI.SELECTIONVARIANT$3$.QUALIFIER` value = `'Urgent'` )
                  ( key = `UI.SELECTIONVARIANT$3$.FILTER`    value = `'Priority GE 3'` ) )
                it_elements = VALUE #( )
      CHANGING  cs_entity   = ms_entity ).

    " a variant without a filter is no tab
    cl_abap_unit_assert=>assert_equals( exp = 2              act = lines( ms_entity-selection_variants ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Open travels` act = ms_entity-selection_variants[ 1 ]-text ).
    cl_abap_unit_assert=>assert_equals( exp = `Status EQ O`  act = ms_entity-selection_variants[ 1 ]-filter ).
    " no text - the qualifier stands in
    cl_abap_unit_assert=>assert_equals( exp = `Urgent`       act = ms_entity-selection_variants[ 2 ]-text ).

  ENDMETHOD.


  METHOD selection_filter_where.

    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS = 'O' AND PRIORITY >= '3'`
      act = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = `Status EQ O and Priority GE 3`
                                                          it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS <> 'X''Y'`
      act = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = `Status NE 'X'Y'`
                                                          it_fields = ms_entity-fields ) ).

  ENDMETHOD.


  METHOD selection_filter_or.

    " AND binds stronger than OR - an OR is put into parentheses of its own
    cl_abap_unit_assert=>assert_equals(
      exp = `( STATUS = 'O' OR STATUS = 'A' AND PRIORITY >= '3' )`
      act = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = `Status EQ O or Status EQ A AND Priority GE 3`
                                                          it_fields = ms_entity-fields ) ).
    " a quoted value keeps its blanks and a word OR inside it
    cl_abap_unit_assert=>assert_equals(
      exp = `( STATUS = 'a OR b' OR AGENCYID = '7' )`
      act = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = `Status = 'a OR b' OR AgencyID = 7`
                                                          it_fields = ms_entity-fields ) ).

  ENDMETHOD.


  METHOD selection_filter_parentheses.

    cl_abap_unit_assert=>assert_equals(
      exp = `( STATUS = 'O' OR STATUS = 'A' ) AND PRIORITY >= '3'`
      act = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = `(Status EQ O OR Status EQ A) AND Priority GE 3`
                                                          it_fields = ms_entity-fields ) ).
    " parentheses as words of their own, nested - an AND needs none
    cl_abap_unit_assert=>assert_equals(
      exp = `PRIORITY > '1' AND ( STATUS = 'O' OR AGENCYID = '7' AND STATUS <> 'X' )`
      act = z2ui5_cl_rap_util=>selection_filter_to_where(
              filter    = `Priority GT 1 AND ( Status EQ O OR ( AgencyID EQ 7 AND Status NE 'X' ) )`
              it_fields = ms_entity-fields ) ).
    " parentheses that do not match, or an operator without its operand
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `(Status EQ O OR Status EQ A` it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `Status EQ O) AND Priority GE 3` it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `Status EQ O OR` it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `() AND Status EQ O` it_fields = ms_entity-fields ) ).

  ENDMETHOD.


  METHOD selection_filter_unreadable.

    " an unknown field or operator restricts nothing wrongly - it is no filter
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `Unknown EQ 1` it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `Status CP O*` it_fields = ms_entity-fields ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>selection_filter_to_where(
      filter = `Status EQ` it_fields = ms_entity-fields ) ).

  ENDMETHOD.


  METHOD text_arrangement.

    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #( )
                it_elements = VALUE #( ( element = `AGENCYID` key = `UI.TEXTARRANGEMENT` value = `#TEXT_ONLY` ) )
      CHANGING  cs_entity   = ms_entity ).

    cl_abap_unit_assert=>assert_equals( exp = `TEXT_ONLY`
                                        act = ms_entity-fields[ name = `AGENCYID` ]-text_arrangement ).

  ENDMETHOD.


  METHOD criticality_maximize.

    DATA(ls_calc) = VALUE z2ui5_cl_rap_util=>ty_s_crit_calc( improvement_direction = `MAXIMIZE`
                                                             deviation_low         = `50`
                                                             tolerance_low         = `80` ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 90 is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 80 is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 60 is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 10 is_calc = ls_calc ) ).

  ENDMETHOD.


  METHOD criticality_minimize.

    DATA(ls_calc) = VALUE z2ui5_cl_rap_util=>ty_s_crit_calc( improvement_direction = `MINIMIZE`
                                                             tolerance_high        = `10`
                                                             deviation_high        = `20` ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 5  is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 15 is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 25 is_calc = ls_calc ) ).

  ENDMETHOD.


  METHOD criticality_target.

    DATA(ls_calc) = VALUE z2ui5_cl_rap_util=>ty_s_crit_calc( improvement_direction = `TARGET`
                                                             deviation_low         = `0`
                                                             tolerance_low         = `40`
                                                             tolerance_high        = `60`
                                                             deviation_high        = `100` ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 50  is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 70  is_calc = ls_calc ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = z2ui5_cl_rap_util=>criticality_by_calculation( value = 120 is_calc = ls_calc ) ).

  ENDMETHOD.


  METHOD criticality_incomplete.

    " no thresholds, a path instead of a number, no direction - neutral
    cl_abap_unit_assert=>assert_equals( exp = 0 act = z2ui5_cl_rap_util=>criticality_by_calculation(
      value = 1 is_calc = VALUE #( improvement_direction = `MAXIMIZE` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = z2ui5_cl_rap_util=>criticality_by_calculation(
      value = 1 is_calc = VALUE #( improvement_direction = `MAXIMIZE` tolerance_low = `TargetField` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = z2ui5_cl_rap_util=>criticality_by_calculation(
      value = 1 is_calc = VALUE #( tolerance_low = `1` ) ) ).

  ENDMETHOD.

  METHOD presentation_variants.

    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #(
                  ( key = `UI.PRESENTATIONVARIANT$1$.SORTORDER$1$.BY`            value = `'TotalPrice'` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.QUALIFIER`                  value = `'TopFive'` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.MAXITEMS`                   value = `5` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.SORTORDER$1$.BY`            value = `'TotalPrice'` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.SORTORDER$1$.DIRECTION`     value = `#DESC` )
                  ( key = `UI.PRESENTATIONVARIANT$2$.VISUALIZATIONS$1$.TYPE`      value = `#AS_LINEITEM` )
                  ( key = `UI.PRESENTATIONVARIANT$3$.QUALIFIER`                  value = `'ByStatus'` )
                  ( key = `UI.PRESENTATIONVARIANT$3$.VISUALIZATIONS$1$.TYPE`      value = `#AS_CHART` )
                  ( key = `UI.PRESENTATIONVARIANT$3$.VISUALIZATIONS$1$.QUALIFIER` value = `'StatusChart'` ) )
                it_elements = VALUE #( )
      CHANGING  cs_entity   = ms_entity ).

    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( ms_entity-presentation_variants ) ).
    READ TABLE ms_entity-presentation_variants INTO DATA(ls_top) WITH KEY qualifier = `TopFive`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = 5          act = ls_top-max_items ).
    cl_abap_unit_assert=>assert_equals( exp = `LINEITEM` act = ls_top-visualization_type ).
    cl_abap_unit_assert=>assert_equals( exp = `TOTALPRICE` act = ls_top-sort_order[ 1 ]-field ).
    cl_abap_unit_assert=>assert_true( ls_top-sort_order[ 1 ]-descending ).
    READ TABLE ms_entity-presentation_variants INTO DATA(ls_chart) WITH KEY qualifier = `ByStatus`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = `CHART`       act = ls_chart-visualization_type ).
    cl_abap_unit_assert=>assert_equals( exp = `StatusChart` act = ls_chart-visualization_qualifier ).
    "the default sort order stays the unqualified variant's
    cl_abap_unit_assert=>assert_false( ms_entity-sort_order[ 1 ]-descending ).

  ENDMETHOD.

ENDCLASS.


" parse_ddl_associations( ) on DDL sources as DDDDLSRC holds them - the
" interface view of a RAP business object, its projection, the 7.58 forms
" and comments in between.
CLASS ltcl_associations DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS assoc
      IMPORTING
        it_assoc      TYPE z2ui5_cl_rap_util=>ty_t_association
        name          TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_association.

    METHODS interface_view           FOR TESTING RAISING cx_static_check.
    METHODS to_parent_condition      FOR TESTING RAISING cx_static_check.
    METHODS projection_redirects     FOR TESTING RAISING cx_static_check.
    METHODS new_cardinality_syntax   FOR TESTING RAISING cx_static_check.
    METHODS comments_are_skipped     FOR TESTING RAISING cx_static_check.
    METHODS literal_is_no_field_pair FOR TESTING RAISING cx_static_check.
    METHODS merge_with_base          FOR TESTING RAISING cx_static_check.
    METHODS parent_conditions        FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_associations IMPLEMENTATION.

  METHOD assoc.
    READ TABLE it_assoc INTO result WITH KEY name = name.
    cl_abap_unit_assert=>assert_subrc( msg = |association { name }| ).
  ENDMETHOD.


  METHOD interface_view.

    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |define root view entity ZI_Travel as select from ztravel\n| &&
      |  composition [0..*] of ZI_Booking as _Booking\n| &&
      |  association [0..1] to /DMO/I_Agency as _Agency on $projection.AgencyID = _Agency.AgencyID\n| &&
      |  association [0..1] to I_Currency as _Currency\n| &&
      |    on $projection.CurrencyCode = _Currency.Currency and _Currency.Decimals = $projection.Decimals\n| &&
      |\{\n  key travel_uuid as TravelUUID,\n  agency_id as AgencyID,\n  _Booking,\n  _Agency\n\}| ).

    cl_abap_unit_assert=>assert_initial( ls_parsed-base ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_parsed-associations )
                                        exp = 3 ).

    DATA(ls_booking) = assoc( it_assoc = ls_parsed-associations name = `_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = ls_booking-target
                                        exp = `ZI_BOOKING` ).
    cl_abap_unit_assert=>assert_true( ls_booking-is_composition ).
    cl_abap_unit_assert=>assert_initial( ls_booking-conditions ).

    DATA(ls_agency) = assoc( it_assoc = ls_parsed-associations name = `_AGENCY` ).
    cl_abap_unit_assert=>assert_equals( act = ls_agency-target
                                        exp = `/DMO/I_AGENCY` ).
    cl_abap_unit_assert=>assert_false( ls_agency-is_composition ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_agency-conditions
      exp = VALUE z2ui5_cl_rap_util=>ty_t_assoc_condition( ( local = `AGENCYID` target = `AGENCYID` ) ) ).

    "either side may name the target first
    DATA(ls_currency) = assoc( it_assoc = ls_parsed-associations name = `_CURRENCY` ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_currency-conditions
      exp = VALUE z2ui5_cl_rap_util=>ty_t_assoc_condition( ( local = `CURRENCYCODE` target = `CURRENCY` )
                                                          ( local = `DECIMALS`     target = `DECIMALS` ) ) ).

  ENDMETHOD.


  METHOD to_parent_condition.

    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |define view entity ZI_Booking as select from zbooking\n| &&
      |  association to parent ZI_Travel as _Travel on $projection.TravelUUID = _Travel.TravelUUID\n| &&
      |\{ key booking_uuid as BookingUUID, parent_uuid as TravelUUID, _Travel \}| ).

    DATA(ls_travel) = assoc( it_assoc = ls_parsed-associations name = `_TRAVEL` ).
    cl_abap_unit_assert=>assert_true( ls_travel-is_to_parent ).
    cl_abap_unit_assert=>assert_equals( act = ls_travel-target
                                        exp = `ZI_TRAVEL` ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_travel-conditions
      exp = VALUE z2ui5_cl_rap_util=>ty_t_assoc_condition( ( local = `TRAVELUUID` target = `TRAVELUUID` ) ) ).

  ENDMETHOD.


  METHOD projection_redirects.

    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |define root view entity ZC_Travel provider contract transactional_query\n| &&
      |  as projection on ZI_Travel\n| &&
      |\{\n  key TravelUUID,\n  AgencyID,\n| &&
      |  _Booking : redirected to composition child ZC_Booking,\n| &&
      |  _Agency\n\}| ).

    cl_abap_unit_assert=>assert_equals( act = ls_parsed-base
                                        exp = `ZI_TRAVEL` ).
    cl_abap_unit_assert=>assert_equals( act = ls_parsed-exposed
                                        exp = VALUE string_table( ( `_BOOKING` ) ( `_AGENCY` ) ) ).
    DATA(ls_booking) = assoc( it_assoc = ls_parsed-associations name = `_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = ls_booking-target
                                        exp = `ZC_BOOKING` ).
    cl_abap_unit_assert=>assert_true( ls_booking-is_composition ).

    ls_parsed = z2ui5_cl_rap_util=>parse_ddl_associations(
      `define view entity ZC_Booking as projection on ZI_Booking { key BookingUUID, _Travel : redirected to parent ZC_Travel }` ).
    DATA(ls_travel) = assoc( it_assoc = ls_parsed-associations name = `_TRAVEL` ).
    cl_abap_unit_assert=>assert_true( ls_travel-is_to_parent ).
    cl_abap_unit_assert=>assert_equals( act = ls_travel-target
                                        exp = `ZC_TRAVEL` ).

  ENDMETHOD.


  METHOD new_cardinality_syntax.

    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |define view entity ZI_X as select from zx\n| &&
      |  association of many to one I_Country as _Country on $projection.Country = _Country.Country\n| &&
      |  composition of exact one to many ZI_Item as _Item\n| &&
      |\{ key id as Id, country as Country \}| ).

    cl_abap_unit_assert=>assert_equals( act = assoc( it_assoc = ls_parsed-associations name = `_COUNTRY` )-target
                                        exp = `I_COUNTRY` ).
    DATA(ls_item) = assoc( it_assoc = ls_parsed-associations name = `_ITEM` ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-target
                                        exp = `ZI_ITEM` ).
    cl_abap_unit_assert=>assert_true( ls_item-is_composition ).

  ENDMETHOD.


  METHOD comments_are_skipped.

    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |// association [0..1] to ZI_Old as _Old on $projection.A = _Old.A\n| &&
      |define view entity ZI_X as select from zx\n| &&
      |  /* association to ZI_Gone as _Gone\n     on $projection.A = _Gone.A */\n| &&
      |  association [0..1] to ZI_Kept as _Kept on $projection.A = _Kept.A // the real one\n| &&
      |\{ key a as A \}| ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_parsed-associations )
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = assoc( it_assoc = ls_parsed-associations name = `_KEPT` )-target
                                        exp = `ZI_KEPT` ).

  ENDMETHOD.


  METHOD literal_is_no_field_pair.

    "a text association: the language is compared with the session, which
    "is no field of the entity
    DATA(ls_parsed) = z2ui5_cl_rap_util=>parse_ddl_associations(
      |define view entity ZI_X as select from zx\n| &&
      |  association [0..*] to ZI_XText as _Text on $projection.Id = _Text.Id\n| &&
      |    and _Text.Language = $session.system_language and _Text.Kind = 'A'\n| &&
      |\{ key id as Id \}| ).

    cl_abap_unit_assert=>assert_equals(
      act = assoc( it_assoc = ls_parsed-associations name = `_TEXT` )-conditions
      exp = VALUE z2ui5_cl_rap_util=>ty_t_assoc_condition( ( local = `ID` target = `ID` ) ) ).

  ENDMETHOD.


  METHOD merge_with_base.

    DATA(lt_own) = VALUE z2ui5_cl_rap_util=>ty_t_association(
      ( name = `_BOOKING` target = `ZC_BOOKING` is_composition = abap_true ) ).
    z2ui5_cl_rap_util=>merge_base_associations(
      EXPORTING it_base  = VALUE #(
                  ( name = `_BOOKING` target = `ZI_BOOKING` is_composition = abap_true
                    conditions = VALUE #( ( local = `TRAVELUUID` target = `PARENTUUID` ) ) )
                  ( name = `_AGENCY` target = `/DMO/I_AGENCY`
                    conditions = VALUE #( ( local = `AGENCYID` target = `AGENCYID` ) ) ) )
      CHANGING  ct_assoc = lt_own ).

    "the redirect keeps its target and takes the condition
    DATA(ls_booking) = assoc( it_assoc = lt_own name = `_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = ls_booking-target
                                        exp = `ZC_BOOKING` ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_booking-conditions )
                                        exp = 1 ).
    "what is not redirected is the base's
    cl_abap_unit_assert=>assert_equals( act = assoc( it_assoc = lt_own name = `_AGENCY` )-target
                                        exp = `/DMO/I_AGENCY` ).

    "what the projection does not expose, it does not have
    CLEAR lt_own.
    z2ui5_cl_rap_util=>merge_base_associations(
      EXPORTING it_base    = VALUE #( ( name = `_AGENCY` target = `/DMO/I_AGENCY` )
                                      ( name = `_HIDDEN` target = `Z_HIDDEN` ) )
                it_exposed = VALUE #( ( `_AGENCY` ) )
      CHANGING  ct_assoc   = lt_own ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_own )
                                        exp = 1 ).

  ENDMETHOD.


  METHOD parent_conditions.

    DATA(lt_conditions) = z2ui5_cl_rap_util=>get_parent_conditions(
      it_child_assoc = VALUE #( ( name = `_TRAVEL` target = `ZI_TRAVEL` is_to_parent = abap_true
                                  conditions = VALUE #( ( local = `PARENTUUID` target = `TRAVELUUID` ) ) ) )
      parent         = `zi_travel` ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_conditions
      exp = VALUE z2ui5_cl_rap_util=>ty_t_assoc_condition( ( local = `TRAVELUUID` target = `PARENTUUID` ) ) ).

  ENDMETHOD.

ENDCLASS.


" the export of the list report: CSV, UTF-8 and Base64 - what becomes the
" data: URL of the download
CLASS ltcl_export DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_row,
        id    TYPE c LENGTH 4,
        name  TYPE string,
        day   TYPE d,
        price TYPE p LENGTH 8 DECIMALS 2,
      END OF ty_s_row.

    METHODS csv_lines       FOR TESTING RAISING cx_static_check.
    METHODS base64_padding  FOR TESTING RAISING cx_static_check.
    METHODS utf8_with_bom   FOR TESTING RAISING cx_static_check.
    METHODS url_round_trip  FOR TESTING RAISING cx_static_check.
    METHODS url_query       FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_export IMPLEMENTATION.

  METHOD csv_lines.

    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    lt_rows = VALUE #( ( id = `A1` name = `Say "hi"` day = '20240115' price = '12.50' )
                       ( id = `B2` name = `x;y`      day = '00000000' price = '-3.10' ) ).

    DATA(lv_csv) = z2ui5_cl_rap_util=>to_csv(
      data      = REF #( lt_rows )
      it_fields = VALUE #( ( name = `ID`    label = `Id`         type_kind = `CHAR` )
                           ( name = `NAME`  label = `Name`       type_kind = `STRING` )
                           ( name = `DAY`   label = `Day`        type_kind = `DATS` )
                           ( name = `PRICE` label = `Price "EUR"` type_kind = `DEC` ) ) ).

    DATA(lv_crlf) = cl_abap_char_utilities=>cr_lf.
    cl_abap_unit_assert=>assert_equals(
      act = lv_csv
      exp = |"Id";"Name";"Day";"Price ""EUR"""{ lv_crlf }| &&
            |"A1";"Say ""hi""";"2024-01-15";"12.50"{ lv_crlf }| &&
            |"B2";"x;y";"";"-3.10"{ lv_crlf }| ).

  ENDMETHOD.


  METHOD base64_padding.
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>base64_encode( `4D616E` )
                                        exp = `TWFu` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>base64_encode( `4D61` )
                                        exp = `TWE=` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>base64_encode( `4D` )
                                        exp = `TQ==` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>base64_encode( `FFFEFD` )
                                        exp = `//79` ).
  ENDMETHOD.


  METHOD utf8_with_bom.
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>to_utf8( val = |ä| bom = abap_true )
                                        exp = CONV xstring( `EFBBBFC3A4` ) ).
  ENDMETHOD.

  METHOD url_round_trip.
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>url_encode( `/DMO/C_TRAVEL a&b=ä` )
                                        exp = `%2FDMO%2FC_TRAVEL%20a%26b%3D%C3%A4` ).
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>url_decode( `%2FDMO%2FC_TRAVEL+a%26b%3D%C3%A4` )
                                        exp = `/DMO/C_TRAVEL a&b=ä` ).
    "a lone % is text
    cl_abap_unit_assert=>assert_equals( act = z2ui5_cl_rap_util=>url_decode( `50%` )
                                        exp = `50%` ).
  ENDMETHOD.


  METHOD url_query.
    cl_abap_unit_assert=>assert_equals(
      act = z2ui5_cl_rap_util=>parse_url_query( `?app_start=zcl_x&entity=%2FDMO%2FC_TRAVEL&TravelID=42` )
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `app_start` value = `zcl_x` )
                                                           ( name = `entity`    value = `/DMO/C_TRAVEL` )
                                                           ( name = `TravelID`  value = `42` ) ) ).
  ENDMETHOD.

ENDCLASS.


" the reading of a custom entity and of virtual elements (2026-10, third
" round): what a query provider is asked for - the filter as ABAP SQL and
" as ranges, the search apart from it, the sort order - and the
" annotations that decide how an entity is read
CLASS ltcl_reading DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_s_row,
        status TYPE c LENGTH 1,
        day    TYPE d,
        price  TYPE p LENGTH 8 DECIMALS 2,
      END OF ty_s_row.

    METHODS read_info_annotations  FOR TESTING RAISING cx_static_check.
    METHODS field_annotations      FOR TESTING RAISING cx_static_check.
    METHODS filter_as_ranges       FOR TESTING RAISING cx_static_check.
    METHODS filter_host_values     FOR TESTING RAISING cx_static_check.
    METHODS filter_no_ranges       FOR TESTING RAISING cx_static_check.
    METHODS search_apart           FOR TESTING RAISING cx_static_check.
    METHODS search_strings_hidden  FOR TESTING RAISING cx_static_check.
    METHODS order_by_round_trip    FOR TESTING RAISING cx_static_check.
    METHODS remove_virtual_fields  FOR TESTING RAISING cx_static_check.
    METHODS sortable_filterable    FOR TESTING RAISING cx_static_check.
    METHODS aggregate_groups       FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_reading IMPLEMENTATION.

  METHOD read_info_annotations.

    DATA(ls_info) = z2ui5_cl_rap_util=>parse_read_info(
      it_entity   = VALUE #( ( key = `ObjectModel.query.implementedBy` value = `'ABAP:ZCL_TRAVEL_QUERY'` ) )
      it_elements = VALUE #( ( element = `Status`     key = `UI.HIDDEN`                              value = `true` )
                             ( element = `DaysToGo`   key = `OBJECTMODEL.VIRTUALELEMENTCALCULATEDBY` value = `'ABAP:zcl_days'` )
                             ( element = `DaysToGo`   key = `OBJECTMODEL.SORT.TRANSFORMEDBY`         value = `'ABAP:ZCL_DAYS_SORT'` )
                             ( element = `PlainVirt`  key = `ObjectModel.virtualElement`              value = `true` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `ZCL_TRAVEL_QUERY`
                                        act = ls_info-query_class ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_virtual_element(
              ( name = `DAYSTOGO`  calc_class = `ZCL_DAYS` sort_class = `ZCL_DAYS_SORT` )
              ( name = `PLAINVIRT` ) )
      act = ls_info-virtual_elements ).

  ENDMETHOD.


  METHOD field_annotations.

    DATA(ls_entity) = VALUE z2ui5_cl_rap_util=>ty_s_entity_info(
      fields = VALUE #( ( name = `DAYSTOGO` type_kind = `INT` )
                        ( name = `NAME`     type_kind = `CHAR` ) ) ).
    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #( ( key = `OBJECTMODEL.QUERY.IMPLEMENTEDBY` value = `'ABAP:ZCL_Q'` ) )
                it_elements = VALUE #( ( element = `DAYSTOGO` key = `OBJECTMODEL.VIRTUALELEMENTCALCULATEDBY` value = `'ABAP:ZCL_CALC'` )
                                       ( element = `DAYSTOGO` key = `OBJECTMODEL.FILTER.TRANSFORMEDBY`       value = `'ABAP:ZCL_FILTER'` )
                                       ( element = `NAME`     key = `SEARCH.FUZZINESSTHRESHOLD`              value = `0.8` ) )
      CHANGING  cs_entity   = ls_entity ).

    cl_abap_unit_assert=>assert_equals( exp = `ZCL_Q`
                                        act = ls_entity-query_class ).
    DATA(ls_days) = ls_entity-fields[ name = `DAYSTOGO` ].
    cl_abap_unit_assert=>assert_true( ls_days-is_virtual ).
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_CALC`
                                        act = ls_days-virtual_calc_class ).
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_FILTER`
                                        act = ls_days-filter_transform_class ).
    cl_abap_unit_assert=>assert_equals( exp = `0.8`
                                        act = ls_entity-fields[ name = `NAME` ]-search_fuzziness ).
    cl_abap_unit_assert=>assert_false( ls_entity-fields[ name = `NAME` ]-is_virtual ).

  ENDMETHOD.


  METHOD filter_as_ranges.

    DATA(ls_filter) = z2ui5_cl_rap_util=>build_query_filter(
      `STATUS = 'O' AND ( PRICE > '10' OR PRICE BETWEEN '1' AND '2' )` &&
      ` AND NOT ( CITY LIKE '%Ber#_l''n*%' ESCAPE '#' )` ).

    cl_abap_unit_assert=>assert_false( ls_filter-no_ranges ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_range(
              ( name  = `STATUS`
                range = VALUE #( ( sign = 'I' option = 'EQ' low = `O` ) ) )
              ( name  = `PRICE`
                range = VALUE #( ( sign = 'I' option = 'GT' low = `10` )
                                 ( sign = 'I' option = 'BT' low = `1` high = `2` ) ) )
              ( name  = `CITY`
                range = VALUE #( ( sign = 'E' option = 'CP' low = `*Ber_l'n#**` ) ) ) )
      act = ls_filter-ranges ).
    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS = 'O' AND ( PRICE > '10' OR PRICE BETWEEN '1' AND '2' )` &&
            ` AND NOT ( CITY LIKE '%Ber#_l''n*%' ESCAPE '#' )`
      act = ls_filter-sql ).
    cl_abap_unit_assert=>assert_initial( ls_filter-search ).

  ENDMETHOD.


  METHOD filter_host_values.

    DATA(ls_filter) = z2ui5_cl_rap_util=>build_query_filter(
      where       = `TRAVELID = @<LS_HOST>-TRAVELID AND AGENCY = @<LS_HOST>-AGENCY AND NAME IS INITIAL`
      host_values = VALUE #( ( name = `TRAVELID` value = `42` )
                             ( name = `AGENCY`   value = `O'Neil` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID = '42' AND AGENCY = 'O''Neil' AND NAME IS INITIAL`
                                        act = ls_filter-sql ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_range(
              ( name  = `TRAVELID`
                range = VALUE #( ( sign = 'I' option = 'EQ' low = `42` ) ) )
              ( name  = `AGENCY`
                range = VALUE #( ( sign = 'I' option = 'EQ' low = `O'Neil` ) ) )
              ( name  = `NAME`
                range = VALUE #( ( sign = 'I' option = 'EQ' ) ) ) )
      act = ls_filter-ranges ).

  ENDMETHOD.


  METHOD filter_no_ranges.

    " an OR over two fields
    DATA(ls_filter) = z2ui5_cl_rap_util=>build_query_filter( `( A = '1' OR B = '2' )` ).
    cl_abap_unit_assert=>assert_true( ls_filter-no_ranges ).
    cl_abap_unit_assert=>assert_initial( ls_filter-ranges ).
    cl_abap_unit_assert=>assert_equals( exp = `( A = '1' OR B = '2' )`
                                        act = ls_filter-sql ).

    " a field in two conditions, NOT a OR b, a function
    cl_abap_unit_assert=>assert_true(
      z2ui5_cl_rap_util=>build_query_filter( `A = '1' AND A = '2'` )-no_ranges ).
    cl_abap_unit_assert=>assert_true(
      z2ui5_cl_rap_util=>build_query_filter( `( NOT ( A = '1' ) OR A = '2' )` )-no_ranges ).
    cl_abap_unit_assert=>assert_true(
      z2ui5_cl_rap_util=>build_query_filter( `UPPER( A ) = 'X'` )-no_ranges ).
    " an unknown host variable
    cl_abap_unit_assert=>assert_true(
      z2ui5_cl_rap_util=>build_query_filter( `A = @<LS_HOST>-A` )-no_ranges ).

    " nothing to filter
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>build_query_filter( `` ) ).

  ENDMETHOD.


  METHOD search_apart.

    DATA(lt_fields) = VALUE z2ui5_cl_rap_util=>ty_t_field_info(
      ( name = `ID`   type_kind = `CHAR` )
      ( name = `NAME` type_kind = `CHAR` ) ).
    DATA(lv_search) = z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields
                                                                search    = `a*b%` ).

    DATA(ls_filter) = z2ui5_cl_rap_util=>build_query_filter( |STATUS = 'O' AND { lv_search }| ).
    cl_abap_unit_assert=>assert_equals( exp = `A*B%`
                                        act = ls_filter-search ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUS = 'O'`
                                        act = ls_filter-sql ).
    cl_abap_unit_assert=>assert_false( ls_filter-no_ranges ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ls_filter-ranges ) ).

  ENDMETHOD.


  METHOD search_strings_hidden.

    DATA(lt_fields) = VALUE z2ui5_cl_rap_util=>ty_t_field_info(
      ( name = `ID`   type_kind = `CHAR` )
      ( name = `NOTE` type_kind = `STRING` )
      ( name = `CALC` type_kind = `CHAR` is_virtual = abap_true )
      ( name = `HIDE` type_kind = `CHAR` is_hidden = abap_true ) ).

    " no search element - every visible text and string field, no virtual one
    cl_abap_unit_assert=>assert_equals(
      exp = `( UPPER( ID ) LIKE '%X%' ESCAPE '#' OR UPPER( NOTE ) LIKE '%X%' ESCAPE '#' )`
      act = z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields search = `x` ) ).

    " a hidden search element is searched
    lt_fields[ name = `HIDE` ]-is_searchable = abap_true.
    cl_abap_unit_assert=>assert_equals(
      exp = `( UPPER( HIDE ) LIKE '%X%' ESCAPE '#' )`
      act = z2ui5_cl_rap_util=>build_search_condition( it_fields = lt_fields search = `x` ) ).

  ENDMETHOD.


  METHOD order_by_round_trip.

    DATA(lt_sort) = z2ui5_cl_rap_util=>parse_order_by( `travelid DESCENDING,  STATUS , PRICE ASCENDING` ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_sort( ( field = `TRAVELID` descending = abap_true )
                                                ( field = `STATUS` )
                                                ( field = `PRICE` ) )
      act = lt_sort ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID DESCENDING, STATUS, PRICE`
                                        act = z2ui5_cl_rap_util=>order_by_to_string( lt_sort ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>parse_order_by( `` ) ).

  ENDMETHOD.


  METHOD remove_virtual_fields.

    DATA(lt_virtual) = VALUE string_table( ( `DAYSTOGO` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS = 'O' AND ( UPPER( NAME ) LIKE '%X%' ESCAPE '#' )`
      act = z2ui5_cl_rap_util=>remove_where_fields(
              where  = `STATUS = 'O' AND DaysToGo > '3' AND ( UPPER( NAME ) LIKE '%X%' ESCAPE '#' )`
              fields = lt_virtual ) ).
    " nothing to remove - the condition as it was
    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS='O' AND NOTE = 'DAYSTOGO'`
      act = z2ui5_cl_rap_util=>remove_where_fields( where  = `STATUS='O' AND NOTE = 'DAYSTOGO'`
                                                    fields = lt_virtual ) ).
    cl_abap_unit_assert=>assert_initial(
      z2ui5_cl_rap_util=>remove_where_fields( where  = `DAYSTOGO BETWEEN '1' AND '2'`
                                              fields = lt_virtual ) ).

  ENDMETHOD.


  METHOD sortable_filterable.

    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_sortable( VALUE #( type_kind = `CHAR` ) ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_sortable( VALUE #( type_kind = `STRING` ) ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_sortable(
      VALUE #( type_kind = `INT` is_virtual = abap_true ) ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_sortable(
      VALUE #( type_kind = `INT` is_virtual = abap_true sort_transform_class = `ZCL_SORT` ) ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_filterable( VALUE #( type_kind = `CHAR` ) ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_filterable(
      VALUE #( type_kind = `INT` is_virtual = abap_true filter_transform_class = `ZCL_FILTER` ) ) ).

  ENDMETHOD.


  METHOD aggregate_groups.

    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    lt_rows = VALUE #( ( status = 'O' day = '20240115' price = '10.50' )
                       ( status = 'A' day = '20240116' price = '4.00' )
                       ( status = 'O' day = '20240117' price = '1.50' ) ).
    DATA(lr_rows) = REF #( lt_rows ).

    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_aggregate( ( group_key = `A` value = 4 row_count = 1 )
                                                     ( group_key = `O` value = 12 row_count = 2 ) )
      act = z2ui5_cl_rap_util=>aggregate_rows( data     = lr_rows
                                               group_by = `STATUS`
                                               measure  = `PRICE` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_aggregate( ( group_key = `` value = 3 row_count = 3 ) )
      act = z2ui5_cl_rap_util=>aggregate_rows( data   = lr_rows
                                               method = `COUNT` ) ).
    DATA(lt_min) = z2ui5_cl_rap_util=>aggregate_rows( data    = lr_rows
                                                      measure = `PRICE`
                                                      method  = `MIN` ).
    cl_abap_unit_assert=>assert_equals( exp = `1.5`
                                        act = |{ lt_min[ 1 ]-value }| ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_aggregate( ( group_key = `20240115` value = '10.5' row_count = 1 )
                                                     ( group_key = `20240116` value = 4 row_count = 1 )
                                                     ( group_key = `20240117` value = '1.5' row_count = 1 ) )
      act = z2ui5_cl_rap_util=>aggregate_rows( data     = lr_rows
                                               group_by = `DAY`
                                               measure  = `PRICE`
                                               method   = `AVG` ) ).

  ENDMETHOD.

ENDCLASS.



" RAP behaviour (added 2026-10, third round): what GET PERMISSIONS answers,
" decoded and combined, the field control of edit mode, the draft status
" of a record and the field of the optimistic check - on plain data
CLASS ltcl_behaviour DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS field_permission_flags  FOR TESTING RAISING cx_static_check.
    METHODS operation_permission    FOR TESTING RAISING cx_static_check.
    METHODS permission_type_names   FOR TESTING RAISING cx_static_check.
    METHODS instance_combined       FOR TESTING RAISING cx_static_check.
    METHODS not_answered_allows     FOR TESTING RAISING cx_static_check.
    METHODS field_control_update    FOR TESTING RAISING cx_static_check.
    METHODS field_control_create    FOR TESTING RAISING cx_static_check.
    METHODS draft_status            FOR TESTING RAISING cx_static_check.
    METHODS editing_status_filter   FOR TESTING RAISING cx_static_check.
    METHODS etag_field              FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_behaviour IMPLEMENTATION.

  METHOD field_permission_flags.

    DATA(ls_none) = z2ui5_cl_rap_util=>decode_field_permission( name  = `A`
                                                                value = 0 ).
    cl_abap_unit_assert=>assert_false( ls_none-read_only ).
    cl_abap_unit_assert=>assert_false( ls_none-mandatory ).

    DATA(ls_ro) = z2ui5_cl_rap_util=>decode_field_permission( name  = `A`
                                                              value = 2 ).
    cl_abap_unit_assert=>assert_true( ls_ro-read_only ).
    cl_abap_unit_assert=>assert_false( ls_ro-mandatory ).

    "mandatory : create combined with readonly : update (16 + 32)
    DATA(ls_both) = z2ui5_cl_rap_util=>decode_field_permission( name  = `A`
                                                                value = 48 ).
    cl_abap_unit_assert=>assert_true( ls_both-mandatory_create ).
    cl_abap_unit_assert=>assert_true( ls_both-read_only_update ).
    cl_abap_unit_assert=>assert_false( ls_both-read_only ).
    cl_abap_unit_assert=>assert_equals( exp = `A`
                                        act = ls_both-name ).

    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>decode_field_permission( name  = `A`
                                                                                  value = 1 )-mandatory ).

  ENDMETHOD.


  METHOD operation_permission.
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_operation_enabled( 0 ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_operation_enabled( 1 ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_operation_enabled( 2 ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_permitted(
      ops  = VALUE #( ( name = `ACCEPT` enabled = abap_false ) )
      name = `reject` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_permitted(
      ops  = VALUE #( ( name = `ACCEPT` enabled = abap_false ) )
      name = `accept` ) ).
  ENDMETHOD.


  METHOD permission_type_names.
    DATA(lt_names) = z2ui5_cl_rap_util=>get_permission_type_names( bdef        = `zr_travel`
                                                                   entity_name = `ZR_BOOKING`
                                                                   kind        = `request` ).
    cl_abap_unit_assert=>assert_equals( exp = `\BDEF=ZR_TRAVEL\ENTITY=ZR_BOOKING\TYPE=PERMISSIONS_Q`
                                        act = lt_names[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_names ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>get_permission_type_names( bdef        = `A`
                                                                                       entity_name = `A`
                                                                                       kind        = `OTHER` ) ).
  ENDMETHOD.


  METHOD instance_combined.

    DATA(ls_perm) = VALUE z2ui5_cl_rap_util=>ty_s_permissions(
      answered  = abap_true
      global    = VALUE #( can_create = abap_true
                           can_update = abap_true
                           can_delete = abap_true
                           actions    = VALUE #( ( name = `COPY` enabled = abap_false ) )
                           fields     = VALUE #( ( name = `STATUS` read_only = abap_true ) ) )
      instances = VALUE #( ( keys       = VALUE #( ( name = `TRAVELID` value = ` 1` ) )
                             can_update = abap_true
                             can_delete = abap_false
                             actions    = VALUE #( ( name = `ACCEPT` enabled = abap_false ) )
                             fields     = VALUE #( ( name = `PRICE` read_only = abap_true )
                                                   ( name = `STATUS` mandatory = abap_true ) ) )
                           ( keys       = VALUE #( ( name = `TRAVELID` value = `2` ) )
                             can_update = abap_false
                             can_delete = abap_true ) ) ).

    DATA(ls_one) = z2ui5_cl_rap_util=>get_instance_permissions(
      is_permissions = ls_perm
      keys           = VALUE #( ( name = `TravelID` value = `1` ) ) ).
    cl_abap_unit_assert=>assert_true( ls_one-can_update ).
    cl_abap_unit_assert=>assert_false( ls_one-can_delete ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_permitted( ops  = ls_one-actions
                                                                        name = `ACCEPT` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_permitted( ops  = ls_one-actions
                                                                        name = `COPY` ) ).
    DATA(ls_status) = ls_one-fields[ name = `STATUS` ].
    cl_abap_unit_assert=>assert_true( ls_status-read_only ).
    cl_abap_unit_assert=>assert_true( ls_status-mandatory ).
    cl_abap_unit_assert=>assert_true( ls_one-fields[ name = `PRICE` ]-read_only ).

    DATA(ls_two) = z2ui5_cl_rap_util=>get_instance_permissions(
      is_permissions = ls_perm
      keys           = VALUE #( ( name = `TRAVELID` value = `2` ) ) ).
    cl_abap_unit_assert=>assert_false( ls_two-can_update ).
    cl_abap_unit_assert=>assert_true( ls_two-can_delete ).

    "an instance GET PERMISSIONS did not answer: the global permissions
    DATA(ls_three) = z2ui5_cl_rap_util=>get_instance_permissions(
      is_permissions = ls_perm
      keys           = VALUE #( ( name = `TRAVELID` value = `3` ) ) ).
    cl_abap_unit_assert=>assert_true( ls_three-can_delete ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_permitted( ops  = ls_three-actions
                                                                       name = `ACCEPT` ) ).

  ENDMETHOD.


  METHOD not_answered_allows.
    DATA(ls_set) = z2ui5_cl_rap_util=>get_instance_permissions(
      is_permissions = VALUE #( )
      keys           = VALUE #( ( name = `A` value = `1` ) ) ).
    cl_abap_unit_assert=>assert_true( ls_set-can_create ).
    cl_abap_unit_assert=>assert_true( ls_set-can_update ).
    cl_abap_unit_assert=>assert_true( ls_set-can_delete ).
    cl_abap_unit_assert=>assert_initial( ls_set-fields ).
  ENDMETHOD.


  METHOD field_control_update.

    DATA(lt_perm) = VALUE z2ui5_cl_rap_util=>ty_t_perm_field(
      ( name = `STATUS` read_only = abap_true )
      ( name = `AGENCY` read_only_update = abap_true )
      ( name = `CUSTOMER` mandatory = abap_true )
      ( name = `BEGINDATE` mandatory_create = abap_true ) ).

    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `Status` )
      it_perm_fields = lt_perm )-read_only ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `AGENCY` )
      it_perm_fields = lt_perm )-read_only ).
    DATA(ls_customer) = z2ui5_cl_rap_util=>get_field_control( is_field       = VALUE #( name = `CUSTOMER` )
                                                              it_perm_fields = lt_perm ).
    cl_abap_unit_assert=>assert_false( ls_customer-read_only ).
    cl_abap_unit_assert=>assert_true( ls_customer-mandatory ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `BEGINDATE` )
      it_perm_fields = lt_perm )-mandatory ).
    "a key is set once
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field = VALUE #( name = `TRAVELID` is_key = abap_true ) )-read_only ).
    "@ObjectModel.readOnly, and a read-only field is no mandatory one
    DATA(ls_annotated) = z2ui5_cl_rap_util=>get_field_control(
      is_field = VALUE #( name = `X` is_readonly = abap_true is_mandatory = abap_true ) ).
    cl_abap_unit_assert=>assert_true( ls_annotated-read_only ).
    cl_abap_unit_assert=>assert_false( ls_annotated-mandatory ).

  ENDMETHOD.


  METHOD field_control_create.

    DATA(lt_perm) = VALUE z2ui5_cl_rap_util=>ty_t_perm_field(
      ( name = `TRAVELID` read_only = abap_true )
      ( name = `AGENCY` read_only_update = abap_true )
      ( name = `BEGINDATE` mandatory_create = abap_true ) ).

    "early numbering: the key is read-only by its field control
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `TRAVELID` is_key = abap_true )
      it_perm_fields = lt_perm
      is_create      = abap_true )-read_only ).
    "an external key is typed in on create
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>get_field_control(
      is_field  = VALUE #( name = `CODE` is_key = abap_true type_kind = `CHAR` length = 3 )
      is_create = abap_true )-read_only ).
    "a UUID key is numbered by the business object
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field  = VALUE #( name = `TRAVELUUID` is_key = abap_true type_kind = `RAW` length = 16 )
      is_create = abap_true )-read_only ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `AGENCY` )
      it_perm_fields = lt_perm
      is_create      = abap_true )-read_only ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>get_field_control(
      is_field       = VALUE #( name = `BEGINDATE` )
      it_perm_fields = lt_perm
      is_create      = abap_true )-mandatory ).

  ENDMETHOD.


  METHOD draft_status.
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>get_draft_status( has_draft = abap_false
                                                                              user      = `ME` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_editing_status-own_draft
      act = z2ui5_cl_rap_util=>get_draft_status( has_draft = abap_true
                                                 owner     = `me`
                                                 user      = `ME` )-state ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_editing_status-own_draft
      act = z2ui5_cl_rap_util=>get_draft_status( has_draft = abap_true
                                                 user      = `ME` )-state ).
    DATA(ls_locked) = z2ui5_cl_rap_util=>get_draft_status( has_draft = abap_true
                                                           owner     = `OTHER`
                                                           user      = `ME` ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_editing_status-locked
                                        act = ls_locked-state ).
    cl_abap_unit_assert=>assert_equals( exp = `OTHER`
                                        act = ls_locked-user ).
  ENDMETHOD.


  METHOD editing_status_filter.
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>matches_editing_status( filter = ``
                                                                                 state  = `LOCKED` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>matches_editing_status( filter = `ALL`
                                                                                 state  = `` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>matches_editing_status( filter = `UNCHANGED`
                                                                                 state  = `` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>matches_editing_status( filter = `UNCHANGED`
                                                                                  state  = `OWN` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>matches_editing_status( filter = `own`
                                                                                 state  = `OWN` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>matches_editing_status( filter = `LOCKED`
                                                                                  state  = `OWN` ) ).
  ENDMETHOD.


  METHOD etag_field.
    cl_abap_unit_assert=>assert_equals(
      exp = `LOCALCHANGED`
      act = z2ui5_cl_rap_util=>get_etag_field( VALUE #( ( name = `CHANGED`      admin_field = `LAST_CHANGED_AT` )
                                                        ( name = `LOCALCHANGED` admin_field = `LOCAL_LAST_CHANGED_AT` ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `CHANGED`
      act = z2ui5_cl_rap_util=>get_etag_field( VALUE #( ( name = `CHANGED` admin_field = `LAST_CHANGED_AT` ) ) ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>get_etag_field( VALUE #( ( name = `A` ) ) ) ).
  ENDMETHOD.

ENDCLASS.


" Messages by severity, files of @Semantics.largeObject and the inbound
" parameters of a navigation (added 2026-10, third round) - plain data,
" no system
CLASS ltcl_messages_files DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS prepare_hides_success     FOR TESTING RAISING cx_static_check.
    METHODS prepare_types_and_doubles FOR TESTING RAISING cx_static_check.
    METHODS display_by_severity       FOR TESTING RAISING cx_static_check.
    METHODS message_items             FOR TESTING RAISING cx_static_check.
    METHODS large_object_annotations  FOR TESTING RAISING cx_static_check.
    METHODS base64_round_trip         FOR TESTING RAISING cx_static_check.
    METHODS data_uri                  FOR TESTING RAISING cx_static_check.
    METHODS mime_type_accepted        FOR TESTING RAISING cx_static_check.
    METHODS file_check                FOR TESTING RAISING cx_static_check.
    METHODS file_extensions           FOR TESTING RAISING cx_static_check.
    METHODS inbound_parameters        FOR TESTING RAISING cx_static_check.
    METHODS large_objects_cleared     FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_messages_files IMPLEMENTATION.

  METHOD prepare_hides_success.
    DATA(lt_messages) = z2ui5_cl_rap_util=>prepare_messages( VALUE #(
      ( text = `Saved`        type = `success` )
      ( text = `Begin date`   type = `error` fields = VALUE #( ( `BEGINDATE` ) ) )
      ( text = `Check prices` type = `warning` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_messages ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_messages[ type = `success` ] ) ) ).

    "without an error the success stays
    lt_messages = z2ui5_cl_rap_util=>prepare_messages( VALUE #(
      ( text = `Saved`        type = `success` )
      ( text = `Check prices` type = `warning` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_messages ) ).
  ENDMETHOD.


  METHOD prepare_types_and_doubles.
    DATA(lt_messages) = z2ui5_cl_rap_util=>prepare_messages( VALUE #(
      ( text = `A` type = `ERROR` )
      ( text = `A` type = `error` )
      ( text = ``  type = `error` )
      ( text = `B` type = `odd` )
      ( text = `C` type = `Information` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_messages ) ).
    cl_abap_unit_assert=>assert_equals( exp = `error`
                                        act = lt_messages[ 2 ]-type ).
    cl_abap_unit_assert=>assert_equals( exp = `information`
                                        act = lt_messages[ 3 ]-type ).
  ENDMETHOD.


  METHOD display_by_severity.
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-none
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-toast
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ( text = `Saved` type = `success` )
                                                              ( text = `Note`  type = `information` ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-box
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ( text = `Locked` type = `error` ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-view
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ( text   = `Begin date`
                                                                type   = `error`
                                                                fields = VALUE #( ( `BEGINDATE` ) ) ) ) ) ).
    "a message of the business object names its entity - listed
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-view
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ( text   = `Locked`
                                                                type   = `error`
                                                                target = `Z_TRAVEL` ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_message_display-view
      act = z2ui5_cl_rap_util=>get_message_display( VALUE #( ( text = `A` type = `warning` )
                                                              ( text = `B` type = `success` ) ) ) ).
  ENDMETHOD.


  METHOD message_items.
    DATA(lt_items) = z2ui5_cl_rap_util=>get_message_items(
      messages  = VALUE #( ( text   = `Dates`
                             type   = `error`
                             fields = VALUE #( ( `BEGINDATE` ) ( `ENDDATE` ) )
                             target = `Z_TRAVEL` )
                           ( text = `Note` type = `information` ) )
      it_fields = VALUE #( ( name = `BEGINDATE` label = `Begin` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_items ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = lt_items[ 1 ]-type ).
    cl_abap_unit_assert=>assert_equals( exp = `Begin, ENDDATE`
                                        act = lt_items[ 1 ]-subtitle ).
    cl_abap_unit_assert=>assert_equals( exp = `Z_TRAVEL`
                                        act = lt_items[ 1 ]-group_name ).
    cl_abap_unit_assert=>assert_equals( exp = `Information`
                                        act = lt_items[ 2 ]-type ).
  ENDMETHOD.


  METHOD large_object_annotations.
    DATA(ls_entity) = VALUE z2ui5_cl_rap_util=>ty_s_entity_info(
      fields = VALUE #( ( name = `ATTACHMENT` ) ( name = `MIMETYPE` ) ( name = `FILENAME` ) ) ).
    z2ui5_cl_rap_util=>apply_annotations(
      EXPORTING it_entity   = VALUE #( )
                it_elements = VALUE #(
                  ( element = `Attachment` key = `Semantics.largeObject.mimeType`                     value = `'MimeType'` )
                  ( element = `Attachment` key = `Semantics.largeObject.fileName`                     value = `'FileName'` )
                  ( element = `Attachment` key = `Semantics.largeObject.acceptableMimeTypes$1$`       value = `'image/png'` )
                  ( element = `Attachment` key = `Semantics.largeObject.acceptableMimeTypes$2$`       value = `'Application/PDF'` )
                  ( element = `Attachment` key = `Semantics.largeObject.contentDispositionPreference` value = `#INLINE` )
                  ( element = `MimeType`   key = `Semantics.mimeType`                                 value = `true` ) )
      CHANGING  cs_entity   = ls_entity ).
    DATA(ls_lob) = ls_entity-fields[ name = `ATTACHMENT` ].
    cl_abap_unit_assert=>assert_true( ls_lob-is_large_object ).
    cl_abap_unit_assert=>assert_equals( exp = `MIMETYPE`
                                        act = ls_lob-lob_mime_field ).
    cl_abap_unit_assert=>assert_equals( exp = `FILENAME`
                                        act = ls_lob-lob_file_name_field ).
    cl_abap_unit_assert=>assert_equals( exp = `INLINE`
                                        act = ls_lob-lob_disposition ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `image/png` ) ( `application/pdf` ) )
                                        act = ls_lob-lob_mime_types ).
    cl_abap_unit_assert=>assert_true( ls_entity-fields[ name = `MIMETYPE` ]-is_mime_type ).
    cl_abap_unit_assert=>assert_false( ls_entity-fields[ name = `FILENAME` ]-is_large_object ).
  ENDMETHOD.


  METHOD base64_round_trip.
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( `48656C6C6F` )
                                        act = z2ui5_cl_rap_util=>base64_decode( `SGVsbG8=` ) ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( `00FF10` )
                                        act = z2ui5_cl_rap_util=>base64_decode( `AP8Q` ) ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( `FB` )
                                        act = z2ui5_cl_rap_util=>base64_decode( `+w==` ) ).
    "line breaks and blanks are skipped
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( `48656C6C6F` )
                                        act = z2ui5_cl_rap_util=>base64_decode( |SGVs\nbG8 =| ) ).
    DATA(lv_bytes) = CONV xstring( `000102FDFEFF7F80` ).
    cl_abap_unit_assert=>assert_equals(
      exp = lv_bytes
      act = z2ui5_cl_rap_util=>base64_decode( z2ui5_cl_rap_util=>base64_encode( lv_bytes ) ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>base64_decode( `` ) ).
  ENDMETHOD.


  METHOD data_uri.
    DATA(ls_file) = z2ui5_cl_rap_util=>parse_data_uri( uri       = `data:image/PNG;base64,SGVsbG8=`
                                                        file_name = `a.png` ).
    cl_abap_unit_assert=>assert_equals( exp = `image/png`
                                        act = ls_file-mime_type ).
    cl_abap_unit_assert=>assert_equals( exp = `a.png`
                                        act = ls_file-file_name ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( `48656C6C6F` )
                                        act = ls_file-content ).

    "no type in the URI: the file name's
    ls_file = z2ui5_cl_rap_util=>parse_data_uri( uri       = `data:application/octet-stream;base64,SGVsbG8=`
                                                  file_name = `Report.PDF` ).
    cl_abap_unit_assert=>assert_equals( exp = `application/pdf`
                                        act = ls_file-mime_type ).
    ls_file = z2ui5_cl_rap_util=>parse_data_uri( uri       = `data:;base64,SGVsbG8=`
                                                  file_name = `noext` ).
    cl_abap_unit_assert=>assert_initial( ls_file-mime_type ).

    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>parse_data_uri( `SGVsbG8=` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `data:text/plain;base64,SGVsbG8=`
      act = z2ui5_cl_rap_util=>to_data_uri( content   = CONV xstring( `48656C6C6F` )
                                            mime_type = `Text/Plain` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `data:application/octet-stream;base64,SGVsbG8=`
      act = z2ui5_cl_rap_util=>to_data_uri( CONV xstring( `48656C6C6F` ) ) ).
  ENDMETHOD.


  METHOD mime_type_accepted.
    DATA(lt_accepted) = VALUE string_table( ( `image/*` ) ( `application/pdf` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = `image/png`
                                                                                accepted  = lt_accepted ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = `Application/PDF`
                                                                                accepted  = lt_accepted ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = `text/plain`
                                                                                 accepted  = lt_accepted ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = `image/`
                                                                                 accepted  = lt_accepted ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = ``
                                                                                 accepted  = lt_accepted ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_mime_type_accepted( mime_type = `text/plain`
                                                                                accepted  = VALUE #( ) ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_rap_util=>is_mime_type_accepted(
      mime_type = `text/plain`
      accepted  = VALUE #( ( `*/*` ) ) ) ).
  ENDMETHOD.


  METHOD file_check.
    DATA(ls_file) = VALUE z2ui5_cl_rap_util=>ty_s_file( mime_type = `image/png`
                                                        content   = CONV xstring( `0102030405` ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_file_check-ok
                                        act = z2ui5_cl_rap_util=>check_file( file     = ls_file
                                                                             accepted = VALUE #( ( `image/png` ) )
                                                                             max_size = 5 ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_file_check-too_large
                                        act = z2ui5_cl_rap_util=>check_file( file     = ls_file
                                                                             max_size = 4 ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_file_check-type
                                        act = z2ui5_cl_rap_util=>check_file( file     = ls_file
                                                                             accepted = VALUE #( ( `application/pdf` ) ) ) ).
    CLEAR ls_file-content.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_rap_util=>cs_file_check-empty
                                        act = z2ui5_cl_rap_util=>check_file( ls_file ) ).
  ENDMETHOD.


  METHOD file_extensions.
    cl_abap_unit_assert=>assert_equals(
      exp = `png,jpg,jpeg`
      act = z2ui5_cl_rap_util=>get_file_extensions( VALUE #( ( `image/png` ) ( `image/jpeg` ) ) ) ).
    "a group or an unknown type: no filter
    cl_abap_unit_assert=>assert_initial(
      z2ui5_cl_rap_util=>get_file_extensions( VALUE #( ( `image/png` ) ( `image/*` ) ) ) ).
    cl_abap_unit_assert=>assert_initial(
      z2ui5_cl_rap_util=>get_file_extensions( VALUE #( ( `application/x-odd` ) ) ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>get_file_extensions( VALUE #( ) ) ).
  ENDMETHOD.


  METHOD inbound_parameters.
    DATA(lt_matched) = z2ui5_cl_rap_util=>match_inbound_parameters(
      params    = VALUE #( ( name = `agencyId`   value = `070001` )
                           ( name = `Unknown`    value = `x` )
                           ( name = `AGENCYID`   value = `second` )
                           ( name = `Calculated` value = `1` )
                           ( name = `Status`     value = `O` ) )
      it_fields = VALUE #( ( name = `AGENCYID` )
                           ( name = `STATUS` )
                           ( name = `CALCULATED` is_virtual = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `AGENCYID` value = `070001` )
                                                       ( name = `STATUS`   value = `O` ) )
      act = lt_matched ).
  ENDMETHOD.


  METHOD large_objects_cleared.
    TYPES:
      BEGIN OF ty_s_row,
        id       TYPE string,
        file     TYPE xstring,
        filename TYPE string,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    lt_rows = VALUE #( ( id = `1` file = CONV xstring( `0102` ) filename = `a.png` ) ).
    z2ui5_cl_rap_util=>clear_large_objects( data      = REF #( lt_rows )
                                            it_fields = VALUE #( ( name = `ID` )
                                                                 ( name = `FILE` is_large_object = abap_true ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-file ).
    cl_abap_unit_assert=>assert_equals( exp = `a.png`
                                        act = lt_rows[ 1 ]-filename ).
  ENDMETHOD.

ENDCLASS.


" The filter bar, the table and the display of the 2026-10 third round:
" the conditions of the "define conditions" dialog, the control of a
" filter, selection variants as filter values, qualified line items,
" criticality and the display annotations - plain data, no system.
CLASS ltcl_filter_bar DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_entity TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    METHODS setup.
    METHODS apply
      IMPORTING
        it_entity   TYPE z2ui5_cl_rap_util=>ty_t_annotation OPTIONAL
        it_elements TYPE z2ui5_cl_rap_util=>ty_t_element_annotation OPTIONAL.
    METHODS field
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    METHODS conditions_to_filter     FOR TESTING RAISING cx_static_check.
    METHODS filter_to_conditions     FOR TESTING RAISING cx_static_check.
    METHODS excluding_parts_are_and  FOR TESTING RAISING cx_static_check.
    METHODS empty_is_initial         FOR TESTING RAISING cx_static_check.
    METHODS filter_controls          FOR TESTING RAISING cx_static_check.
    METHODS filter_lists             FOR TESTING RAISING cx_static_check.
    METHODS select_options           FOR TESTING RAISING cx_static_check.
    METHODS variant_as_filters       FOR TESTING RAISING cx_static_check.
    METHODS variant_where            FOR TESTING RAISING cx_static_check.
    METHODS line_item_entries        FOR TESTING RAISING cx_static_check.
    METHODS qualified_line_item      FOR TESTING RAISING cx_static_check.
    METHODS criticality_bindings     FOR TESTING RAISING cx_static_check.
    METHODS display_annotations      FOR TESTING RAISING cx_static_check.
    METHODS entry_display            FOR TESTING RAISING cx_static_check.
    METHODS entity_variants          FOR TESTING RAISING cx_static_check.
    METHODS navigation_params        FOR TESTING RAISING cx_static_check.
    METHODS intent_bindings          FOR TESTING RAISING cx_static_check.
    METHODS css_widths               FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_filter_bar IMPLEMENTATION.

  METHOD setup.
    ms_entity = VALUE #(
      name   = `Z_TRAVEL`
      fields = VALUE #( ( name = `TRAVELID`   type_kind = `CHAR` )
                        ( name = `STATUS`     type_kind = `CHAR` )
                        ( name = `STATUSCRIT` type_kind = `INT` )
                        ( name = `PRICE`      type_kind = `DEC` )
                        ( name = `BEGINDATE`  type_kind = `DATS` )
                        ( name = `AGENCYID`   type_kind = `CHAR` )
                        ( name = `IMAGE`      type_kind = `STRING` ) ) ).
  ENDMETHOD.


  METHOD apply.
    z2ui5_cl_rap_util=>apply_annotations( EXPORTING it_entity   = it_entity
                                                    it_elements = it_elements
                                          CHANGING  cs_entity   = ms_entity ).
  ENDMETHOD.


  METHOD field.
    READ TABLE ms_entity-fields INTO result WITH KEY name = name.
    cl_abap_unit_assert=>assert_subrc( msg = |field { name }| ).
  ENDMETHOD.


  METHOD conditions_to_filter.
    DATA(lv_filter) = z2ui5_cl_rap_util=>conditions_to_filter( VALUE #(
      ( operator = `EQ` low = `A` )
      ( operator = `NE` low = `B` )
      ( operator = `BT` low = `1` high = `9` )
      ( operator = `GT` low = `5` )
      ( operator = `LE` low = `7` exclude = abap_true )
      ( operator = `CONTAINS` low = `x` )
      ( operator = `STARTS_WITH` low = `y` )
      ( operator = `ENDS_WITH` low = `z` )
      ( operator = `EMPTY` )
      "no value, no condition - and a ; cannot split a value
      ( operator = `EQ` )
      ( operator = `BT` low = `1` )
      ( operator = `EQ` low = `a;b` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = `=A;!=B;1..9;>5;!<=7;*x*;y*;*z;=;=ab`
                                        act = lv_filter ).
    "NE excluded is EQ included
    cl_abap_unit_assert=>assert_equals(
      exp = `=C`
      act = z2ui5_cl_rap_util=>conditions_to_filter( VALUE #( ( operator = `NE` low = `C` exclude = abap_true ) ) ) ).
  ENDMETHOD.


  METHOD filter_to_conditions.
    DATA(lt_conditions) = z2ui5_cl_rap_util=>filter_to_conditions(
      value    = `=A; !=B ;1 .. 9;>=5;<3;*x*;y*;*z;=;abc`
      is_field = VALUE #( name = `F` type_kind = `CHAR` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_condition(
        ( operator = `EQ` low = `A` )
        ( operator = `EQ` low = `B` exclude = abap_true )
        ( operator = `BT` low = `1` high = `9` )
        ( operator = `GE` low = `5` )
        ( operator = `LT` low = `3` )
        ( operator = `CONTAINS` low = `x` )
        ( operator = `STARTS_WITH` low = `y` )
        ( operator = `ENDS_WITH` low = `z` )
        ( operator = `EMPTY` )
        ( operator = `CONTAINS` low = `abc` ) )
      act = lt_conditions ).
    "a number without an operator equals
    lt_conditions = z2ui5_cl_rap_util=>filter_to_conditions( value    = `12`
                                                             is_field = VALUE #( type_kind = `DEC` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `EQ`
                                        act = lt_conditions[ 1 ]-operator ).
    "and back
    cl_abap_unit_assert=>assert_equals(
      exp = `=A;!=B;1..9;>=5;<3;*x*;y*;*z;=;*abc*`
      act = z2ui5_cl_rap_util=>conditions_to_filter( z2ui5_cl_rap_util=>filter_to_conditions(
        value    = `=A;!=B;1..9;>=5;<3;*x*;y*;*z;=;abc`
        is_field = VALUE #( type_kind = `CHAR` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( z2ui5_cl_rap_util=>split_filter_value( ` a ;; b ;` ) ) ).
  ENDMETHOD.


  METHOD excluding_parts_are_and.
    DATA(ls_field) = VALUE z2ui5_cl_rap_util=>ty_s_field_info( name = `F` type_kind = `CHAR` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `( ( F = 'A' OR F = 'B' ) AND NOT ( F = 'C' ) )`
      act = z2ui5_cl_rap_util=>build_filter_condition( is_field = ls_field
                                                       value    = `=A;=B;!=C` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `( NOT ( F = 'C' ) AND NOT ( F = 'D' ) )`
      act = z2ui5_cl_rap_util=>build_filter_condition( is_field = ls_field
                                                       value    = `!=C;!=D` ) ).
    "a date range from a DateRangeSelection, blanks around its delimiter
    cl_abap_unit_assert=>assert_equals(
      exp = `F BETWEEN '20240101' AND '20240131'`
      act = z2ui5_cl_rap_util=>build_filter_condition( is_field = VALUE #( name = `F` type_kind = `DATS` )
                                                       value    = `2024-01-01 .. 2024-01-31` ) ).
  ENDMETHOD.


  METHOD empty_is_initial.
    DATA(ls_field) = VALUE z2ui5_cl_rap_util=>ty_s_field_info( name = `F` type_kind = `CHAR` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `F IS INITIAL`
      act = z2ui5_cl_rap_util=>build_filter_condition( is_field = ls_field
                                                       value    = `=` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `NOT ( F IS INITIAL )`
      act = z2ui5_cl_rap_util=>build_filter_condition( is_field = ls_field
                                                       value    = `!=` ) ).
  ENDMETHOD.


  METHOD filter_controls.
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-list
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind = `CHAR` is_boolean = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-list
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind  = `CHAR`
                                                             value_help = VALUE #( fixed_values = VALUE #( ( name = `A` ) ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-date_range
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind = `DATS` ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-date
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind = `DATS` filter_single = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-multi
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind  = `CHAR`
                                                             value_help = VALUE #( entity_name = `I_COUNTRY` ) ) ) ).
    "one value only: the input with its value help
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-input
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind     = `CHAR`
                                                             filter_single = abap_true
                                                             value_help    = VALUE #( entity_name = `I_COUNTRY` ) ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = z2ui5_cl_rap_util=>cs_filter_control-input
      act = z2ui5_cl_rap_util=>get_filter_control( VALUE #( type_kind = `DEC` ) ) ).
  ENDMETHOD.


  METHOD filter_lists.
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( )
                                                       ( name = `=X` value = `Yes` )
                                                       ( name = `=`  value = `No` ) )
      act = z2ui5_cl_rap_util=>get_filter_list( is_field = VALUE #( is_boolean = abap_true )
                                                yes      = `Yes`
                                                no       = `No` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( )
                                                       ( name = `=O` value = `Open (O)` )
                                                       ( name = `=X` value = `X` ) )
      act = z2ui5_cl_rap_util=>get_filter_list(
        is_field = VALUE #( value_help = VALUE #( fixed_values = VALUE #( ( name = `O` value = `Open` )
                                                                          ( name = `X` ) ) ) )
        yes      = `Yes`
        no       = `No` ) ).
  ENDMETHOD.


  METHOD select_options.
    apply( it_entity = VALUE #(
      ( key = `UI.SELECTIONVARIANT$1$.QUALIFIER`                        value = `'Open'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.PROPERTYNAME`    value = `'Status'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$1$.SIGN`  value = `#I` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$1$.OPTION` value = `#EQ` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$1$.LOW`   value = `'O'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$2$.SIGN`  value = `#E` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$2$.OPTION` value = `#CP` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$1$.RANGES$2$.LOW`   value = `'X*'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$2$.PROPERTYNAME`    value = `'Price'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$2$.RANGES$1$.SIGN`  value = `#I` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$2$.RANGES$1$.OPTION` value = `#BT` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$2$.RANGES$1$.LOW`   value = `'10'` )
      ( key = `UI.SELECTIONVARIANT$1$.SELECTOPTIONS$2$.RANGES$1$.HIGH`  value = `'20'` ) ) ).
    "a variant of selectOptions only is a variant too
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ms_entity-selection_variants ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `STATUS` value = `=O;!X*` )
                                                       ( name = `PRICE`  value = `10..20` ) )
      act = ms_entity-selection_variants[ 1 ]-select_options ).
  ENDMETHOD.


  METHOD variant_as_filters.
    DATA lt_filters TYPE z2ui5_cl_rap_util=>ty_t_name_value.
    DATA lv_where TYPE string.

    z2ui5_cl_rap_util=>selection_variant_filters(
      EXPORTING is_variant = VALUE #( filter         = `Status EQ 'O' and Price ge 10`
                                      select_options = VALUE #( ( name = `AGENCYID` value = `=070001` )
                                                                ( name = `UNKNOWN`  value = `=1` ) ) )
                it_fields  = ms_entity-fields
      IMPORTING filters    = lt_filters
                where      = lv_where ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `AGENCYID` value = `=070001` )
                                                       ( name = `STATUS`   value = `=O` )
                                                       ( name = `PRICE`    value = `>=10` ) )
      act = lt_filters ).
    cl_abap_unit_assert=>assert_initial( lv_where ).

    "an OR is applied as it is
    z2ui5_cl_rap_util=>selection_variant_filters(
      EXPORTING is_variant = VALUE #( filter = `Status EQ O OR Status EQ A` )
                it_fields  = ms_entity-fields
      IMPORTING filters    = lt_filters
                where      = lv_where ).
    cl_abap_unit_assert=>assert_initial( lt_filters ).
    cl_abap_unit_assert=>assert_not_initial( lv_where ).
  ENDMETHOD.


  METHOD variant_where.
    cl_abap_unit_assert=>assert_equals(
      exp = `STATUS = 'O' AND PRICE BETWEEN '10' AND '20'`
      act = z2ui5_cl_rap_util=>selection_variant_where(
        is_variant = VALUE #( filter         = `Status EQ O`
                              select_options = VALUE #( ( name = `PRICE` value = `10..20` ) ) )
        it_fields  = ms_entity-fields ) ).
  ENDMETHOD.


  METHOD line_item_entries.
    apply( it_elements = VALUE #(
      ( element = `Status` key = `UI.LINEITEM$1$.POSITION`                  value = `20` )
      ( element = `Status` key = `UI.LINEITEM$1$.CRITICALITY`               value = `'StatusCrit'` )
      ( element = `Status` key = `UI.LINEITEM$1$.CRITICALITYREPRESENTATION` value = `#WITHOUT_ICON` )
      ( element = `Status` key = `UI.LINEITEM$1$.CSSDEFAULT.WIDTH`          value = `'8rem'` )
      ( element = `Status` key = `UI.LINEITEM$1$.HIDDEN`                    value = `#(IsArchived)` )
      ( element = `Status` key = `UI.LINEITEM$1$.ICONURL`                   value = `'sap-icon://flag'` )
      ( element = `Status` key = `UI.LINEITEM$2$.QUALIFIER`                 value = `'Short'` )
      ( element = `Status` key = `UI.LINEITEM$2$.POSITION`                  value = `5` )
      ( element = `Price`  key = `UI.LINEITEM$1$.TYPE`                      value = `#AS_FIELDGROUP` )
      ( element = `Price`  key = `UI.LINEITEM$1$.VALUEQUALIFIER`            value = `'Prices'` )
      ( element = `Price`  key = `UI.LINEITEM$1$.POSITION`                  value = `30` )
      "hidden: true is no column at all
      ( element = `AgencyId` key = `UI.LINEITEM$1$.POSITION`                value = `40` )
      ( element = `AgencyId` key = `UI.LINEITEM$1$.HIDDEN`                  value = `true` ) ) ).

    DATA(ls_status) = field( `STATUS` ).
    cl_abap_unit_assert=>assert_equals( exp = 20             act = ls_status-line_item_pos ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT`   act = ls_status-line_item_crit_field ).
    cl_abap_unit_assert=>assert_equals( exp = `WITHOUT_ICON` act = ls_status-line_item_crit_repr ).
    cl_abap_unit_assert=>assert_equals( exp = `8rem`         act = ls_status-line_item_width ).
    cl_abap_unit_assert=>assert_equals( exp = `ISARCHIVED`   act = ls_status-line_item_hidden ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://flag` act = ls_status-line_item_icon_url ).
    cl_abap_unit_assert=>assert_equals( exp = 2              act = lines( ls_status-line_items ) ).

    DATA(ls_price) = field( `PRICE` ).
    cl_abap_unit_assert=>assert_equals( exp = `AS_FIELDGROUP` act = ls_price-line_item_type ).
    cl_abap_unit_assert=>assert_equals( exp = `Prices`        act = ls_price-line_item_value_qualifier ).

    cl_abap_unit_assert=>assert_equals( exp = 0 act = field( `AGENCYID` )-line_item_pos ).
  ENDMETHOD.


  METHOD qualified_line_item.
    apply( it_elements = VALUE #(
      ( element = `TravelId` key = `UI.LINEITEM$1$.POSITION`   value = `10` )
      ( element = `Status`   key = `UI.LINEITEM$1$.POSITION`   value = `20` )
      ( element = `Status`   key = `UI.LINEITEM$2$.QUALIFIER`  value = `'Short'` )
      ( element = `Status`   key = `UI.LINEITEM$2$.POSITION`   value = `5` )
      ( element = `Status`   key = `UI.LINEITEM$2$.LABEL`      value = `'State'` )
      ( element = `Price`    key = `UI.LINEITEM$1$.QUALIFIER`  value = `'Short'` )
      ( element = `Price`    key = `UI.LINEITEM$1$.POSITION`   value = `1` )
      ( element = `Price`    key = `UI.LINEITEM$1$.IMPORTANCE` value = `#HIGH` ) ) ).

    DATA(lt_default) = z2ui5_cl_rap_util=>get_line_item_columns( ms_entity-fields ).
    cl_abap_unit_assert=>assert_equals( exp = 2          act = lines( lt_default ) ).
    cl_abap_unit_assert=>assert_equals( exp = `TRAVELID` act = lt_default[ 1 ]-name ).

    DATA(lt_short) = z2ui5_cl_rap_util=>get_line_item_columns( it_fields = ms_entity-fields
                                                               qualifier = `Short` ).
    cl_abap_unit_assert=>assert_equals( exp = 2       act = lines( lt_short ) ).
    cl_abap_unit_assert=>assert_equals( exp = `PRICE` act = lt_short[ 1 ]-name ).
    cl_abap_unit_assert=>assert_true( lt_short[ 1 ]-is_high_importance ).
    cl_abap_unit_assert=>assert_equals( exp = `State` act = lt_short[ 2 ]-line_item_label ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>get_line_item_columns( it_fields = ms_entity-fields
                                                                                   qualifier = `None` ) ).
  ENDMETHOD.


  METHOD criticality_bindings.
    cl_abap_unit_assert=>assert_equals( exp = `Information`
                                        act = z2ui5_cl_rap_util=>criticality_binding( `5` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = z2ui5_cl_rap_util=>criticality_binding( `0` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Success`
                                        act = z2ui5_cl_rap_util=>criticality_binding( `#POSITIVE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://alert`
                                        act = z2ui5_cl_rap_util=>criticality_binding( criticality = `2`
                                                                                      kind        = `ICON` ) ).
    DATA(lv_state) = z2ui5_cl_rap_util=>criticality_binding( `Crit` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_state
                                         exp = `{= ${CRIT} === 3 ? 'Success'*=== 5 ? 'Information' : 'None'*` ).
    DATA(lv_icon) = z2ui5_cl_rap_util=>criticality_binding( criticality = `Crit`
                                                             kind        = `ICON` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_icon
                                         exp = `*'sap-icon://message-information' : ''*` ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>criticality_binding( `` ) ).
  ENDMETHOD.


  METHOD display_annotations.
    apply( it_elements = VALUE #(
      ( element = `Image`    key = `SEMANTICS.IMAGEURL`                 value = `true` )
      ( element = `Status`   key = `OBJECTMODEL.TEXT.ASSOCIATION`       value = `'_StatusText'` )
      ( element = `Status`   key = `UI.HIDDEN`                          value = `false` )
      ( element = `StatusCrit` key = `CONSUMPTION.HIDDEN`               value = `true` )
      ( element = `StatusCrit` key = `UI.HIDDEN`                        value = `false` )
      ( element = `AgencyId` key = `CONSUMPTION.SEMANTICOBJECT`         value = `'TravelAgency'` )
      ( element = `AgencyId` key = `CONSUMPTION.SEMANTICOBJECTMAPPING.ADDITIONALBINDING$1$.LOCALELEMENT` value = `'AgencyId'` )
      ( element = `AgencyId` key = `CONSUMPTION.SEMANTICOBJECTMAPPING.ADDITIONALBINDING$1$.ELEMENT`      value = `'Agency'` ) ) ).

    cl_abap_unit_assert=>assert_true( field( `IMAGE` )-is_image_url ).
    cl_abap_unit_assert=>assert_equals( exp = `_STATUSTEXT` act = field( `STATUS` )-text_association ).
    "@Consumption.hidden wins over a later @UI.hidden: false
    cl_abap_unit_assert=>assert_true( field( `STATUSCRIT` )-is_consumption_hidden ).
    cl_abap_unit_assert=>assert_true( field( `STATUSCRIT` )-is_hidden ).
    DATA(ls_agency) = field( `AGENCYID` ).
    cl_abap_unit_assert=>assert_equals( exp = `TravelAgency` act = ls_agency-semantic_object ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_additional_binding( ( local_element = `AGENCYID` element = `AGENCY` ) )
      act = ls_agency-sem_object_bindings ).
  ENDMETHOD.


  METHOD entry_display.
    apply( it_elements = VALUE #(
      ( element = `Status` key = `UI.FIELDGROUP$1$.QUALIFIER`                 value = `'General'` )
      ( element = `Status` key = `UI.FIELDGROUP$1$.CRITICALITY`               value = `'StatusCrit'` )
      ( element = `Status` key = `UI.FIELDGROUP$1$.CRITICALITYREPRESENTATION` value = `#WITH_ICON` )
      ( element = `Status` key = `UI.FIELDGROUP$1$.IMPORTANCE`                value = `#LOW` )
      ( element = `Status` key = `UI.FIELDGROUP$1$.HIDDEN`                    value = `#(IsArchived)` )
      ( element = `Status` key = `UI.FIELDGROUP$2$.QUALIFIER`                 value = `'Gone'` )
      ( element = `Status` key = `UI.FIELDGROUP$2$.HIDDEN`                    value = `true` )
      ( element = `Status` key = `UI.IDENTIFICATION$1$.CRITICALITY`           value = `'StatusCrit'` )
      ( element = `Status` key = `UI.IDENTIFICATION$1$.IMPORTANCE`            value = `#HIGH` ) ) ).

    DATA(ls_status) = field( `STATUS` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( ls_status-field_groups ) ).
    DATA(ls_group) = ls_status-field_groups[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = ls_group-criticality ).
    cl_abap_unit_assert=>assert_equals( exp = `WITH_ICON`  act = ls_group-crit_representation ).
    cl_abap_unit_assert=>assert_equals( exp = `LOW`        act = ls_group-importance ).
    cl_abap_unit_assert=>assert_equals( exp = `ISARCHIVED` act = ls_group-hidden ).
    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = ls_status-identifications[ 1 ]-criticality ).
    cl_abap_unit_assert=>assert_equals( exp = `HIGH`       act = ls_status-identifications[ 1 ]-importance ).
  ENDMETHOD.


  METHOD entity_variants.
    apply( it_entity = VALUE #(
      ( key = `UI.LINEITEM$1$.CRITICALITY`                                     value = `'StatusCrit'` )
      ( key = `UI.PRESENTATIONVARIANT$1$.GROUPBY$1$`                           value = `'Status'` )
      ( key = `UI.PRESENTATIONVARIANT$1$.SORTORDER$1$.BY`                      value = `'Price'` )
      ( key = `UI.PRESENTATIONVARIANT$2$.QUALIFIER`                            value = `'ByAgency'` )
      ( key = `UI.PRESENTATIONVARIANT$2$.GROUPBY$1$`                           value = `'AgencyId'` )
      ( key = `UI.PRESENTATIONVARIANT$2$.VISUALIZATIONS$1$.TYPE`               value = `#AS_LINEITEM` )
      ( key = `UI.PRESENTATIONVARIANT$2$.VISUALIZATIONS$1$.QUALIFIER`          value = `'Short'` )
      ( key = `UI.SELECTIONPRESENTATIONVARIANT$1$.QUALIFIER`                   value = `'Open'` )
      ( key = `UI.SELECTIONPRESENTATIONVARIANT$1$.TEXT`                        value = `'Open travels'` )
      ( key = `UI.SELECTIONPRESENTATIONVARIANT$1$.PRESENTATIONVARIANTQUALIFIER` value = `'ByAgency'` )
      ( key = `UI.SELECTIONPRESENTATIONVARIANT$1$.SELECTIONVARIANTQUALIFIER`   value = `'Open'` ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = `STATUSCRIT` act = ms_entity-row_criticality ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `STATUS` ) )
                                        act = ms_entity-group_by ).
    READ TABLE ms_entity-presentation_variants INTO DATA(ls_pv) WITH KEY qualifier = `ByAgency`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `AGENCYID` ) )
                                        act = ls_pv-group_by ).
    cl_abap_unit_assert=>assert_equals( exp = `Short` act = ls_pv-visualization_qualifier ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_sel_pres_variant( ( qualifier              = `Open`
                                                               text                   = `Open travels`
                                                               presentation_qualifier = `ByAgency`
                                                               selection_qualifier    = `Open` ) )
      act = ms_entity-sel_pres_variants ).
  ENDMETHOD.


  METHOD navigation_params.
    TYPES:
      BEGIN OF ty_s_row,
        agencyid TYPE string,
        travelid TYPE string,
      END OF ty_s_row.
    DATA(ls_row) = VALUE ty_s_row( agencyid = `070001` travelid = `42` ).

    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `AGENCY`   value = `070001` )
                                                       ( name = `TravelID` value = `42` ) )
      act = z2ui5_cl_rap_util=>get_navigation_params(
        row      = ls_row
        field    = `AgencyId`
        bindings = VALUE #( ( local_element = `AGENCYID` element = `AGENCY` )
                            ( local_element = `TRAVELID` element = `TravelID` )
                            ( local_element = `UNKNOWN`  element = `X` ) ) ) ).
    "no binding: the field's own name
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_name_value( ( name = `TRAVELID` value = `42` ) )
      act = z2ui5_cl_rap_util=>get_navigation_params( row      = ls_row
                                                      field    = `TravelId`
                                                      bindings = VALUE #( ) ) ).
  ENDMETHOD.


  METHOD intent_bindings.
    apply( it_elements = VALUE #(
      ( element = `TravelId` key = `UI.LINEITEM$1$.TYPE`                                value = `#FOR_INTENT_BASED_NAVIGATION` )
      ( element = `TravelId` key = `UI.LINEITEM$1$.SEMANTICOBJECT`                      value = `'Travel'` )
      ( element = `TravelId` key = `UI.LINEITEM$1$.SEMANTICOBJECTACTION`                value = `'manage'` )
      ( element = `TravelId` key = `UI.LINEITEM$1$.SEMANTICOBJECTBINDING$1$.LOCALELEMENT` value = `'TravelId'` )
      ( element = `TravelId` key = `UI.LINEITEM$1$.SEMANTICOBJECTBINDING$1$.ELEMENT`    value = `'Travel'` )
      ( element = `Status`   key = `UI.LINEITEM$1$.TYPE`                                value = `#WITH_INTENT_BASED_NAVIGATION` )
      ( element = `Status`   key = `UI.LINEITEM$1$.SEMANTICOBJECT`                      value = `'Status'` )
      ( element = `Status`   key = `UI.LINEITEM$1$.SEMANTICOBJECTBINDING$1$.LOCALELEMENT` value = `'Status'` )
      ( element = `Status`   key = `UI.LINEITEM$1$.SEMANTICOBJECTBINDING$1$.ELEMENT`    value = `'StatusCode'` ) ) ).

    READ TABLE ms_entity-actions INTO DATA(ls_intent) WITH KEY semantic_object = `Travel`.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_additional_binding( ( local_element = `TRAVELID` element = `TRAVEL` ) )
      act = ls_intent-sem_object_bindings ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE z2ui5_cl_rap_util=>ty_t_additional_binding( ( local_element = `STATUS` element = `STATUSCODE` ) )
      act = field( `STATUS` )-sem_object_bindings ).
  ENDMETHOD.


  METHOD css_widths.
    cl_abap_unit_assert=>assert_equals( exp = `10rem` act = z2ui5_cl_rap_util=>normalize_css_width( ` 10 ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `8.5em` act = z2ui5_cl_rap_util=>normalize_css_width( `8.5EM` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `120px` act = z2ui5_cl_rap_util=>normalize_css_width( `120 px` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `25%`   act = z2ui5_cl_rap_util=>normalize_css_width( `25%` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `auto`  act = z2ui5_cl_rap_util=>normalize_css_width( `Auto` ) ).
    "what UI5 would refuse is nothing
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>normalize_css_width( `wide` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>normalize_css_width( `1..2rem` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>normalize_css_width( `rem` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_rap_util=>normalize_css_width( `{x}` ) ).
  ENDMETHOD.

ENDCLASS.
