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
    METHODS selection_filter_where       FOR TESTING RAISING cx_static_check.
    METHODS selection_filter_unreadable  FOR TESTING RAISING cx_static_check.
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
