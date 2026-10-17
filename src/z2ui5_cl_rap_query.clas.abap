"! The read path of a custom entity (@ObjectModel.query.implementedBy):
"! ABAP SQL cannot read one, its query provider class does. This class
"! asks it the way the RAP runtime would - it is the request
"! (IF_RAP_QUERY_REQUEST with its filter, paging and aggregation) and the
"! response (IF_RAP_QUERY_RESPONSE) the provider's
"! IF_RAP_QUERY_PROVIDER~SELECT is called with.
"!
"! What the floorplans read becomes the request: the filter as ABAP SQL
"! (get_as_sql_string) and as ranges (get_as_ranges - it raises
"! CX_RAP_QUERY_FILTER_NO_RANGE when the filter is no AND of one range per
"! field), the free-text search apart from it (get_search_expression), the
"! sort order, the first max_rows rows (offset 0), every element of the
"! entity as requested, and whether rows, the count or both are wanted.
"! No aggregation is requested - the floorplans aggregate the rows
"! themselves (z2ui5_cl_rap_util=>aggregate_rows) - and a parameter of the
"! entity is not supplied. get_as_tree answers no tree.
"!
"! The only class of the addon that implements the IF_RAP_QUERY_*
"! interfaces. The floorplans ask z2ui5_cl_rap_floorplan=>query_available( )
"! first - which answers from RTTI without loading this class - and reach
"! it only for an entity with a query provider, so a release whose
"! interfaces differ (see docs/system-test.md) breaks the custom entities
"! only. Not verified in a system by an automated gate - see AGENTS.md.
CLASS z2ui5_cl_rap_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES if_rap_query_request.
    INTERFACES if_rap_query_response.
    INTERFACES if_rap_query_filter.
    INTERFACES if_rap_query_paging.
    INTERFACES if_rap_query_aggregation.

    "! Ask the query provider query_class for the rows of entity_name.
    "! data (a table, bound) asks for the rows - they are moved into it by
    "! their component names; count asks for the number of all matching
    "! rows, answered in total
    CLASS-METHODS select
      IMPORTING
        query_class TYPE string
        entity_name TYPE string
        filter      TYPE z2ui5_cl_rap_util=>ty_s_query_filter
        sort        TYPE z2ui5_cl_rap_util=>ty_t_sort OPTIONAL
        elements    TYPE string_table OPTIONAL
        page_size   TYPE i DEFAULT 500
        data        TYPE REF TO data OPTIONAL
        count       TYPE abap_bool DEFAULT abap_false
      EXPORTING
        total       TYPE int8
      RAISING
        cx_static_check.

  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA mv_entity_name TYPE string.
    DATA ms_filter TYPE z2ui5_cl_rap_util=>ty_s_query_filter.
    DATA mt_sort TYPE z2ui5_cl_rap_util=>ty_t_sort.
    DATA mt_elements TYPE string_table.
    DATA mv_page_size TYPE i.
    DATA mr_data TYPE REF TO data.
    DATA mv_count TYPE abap_bool.
    DATA mv_total TYPE int8.

ENDCLASS.



CLASS z2ui5_cl_rap_query IMPLEMENTATION.

  METHOD select.

    DATA lo_provider TYPE REF TO if_rap_query_provider.

    DATA(lo_query) = NEW z2ui5_cl_rap_query( ).
    lo_query->mv_entity_name = to_upper( entity_name ).
    lo_query->ms_filter = filter.
    lo_query->mt_sort = sort.
    lo_query->mt_elements = elements.
    lo_query->mv_page_size = page_size.
    lo_query->mr_data = data.
    lo_query->mv_count = count.

    CREATE OBJECT lo_provider TYPE (query_class).
    lo_provider->select( io_request  = lo_query
                         io_response = lo_query ).
    total = lo_query->mv_total.

  ENDMETHOD.


  METHOD if_rap_query_request~get_entity_id.
    rv_entity_id = mv_entity_name.
  ENDMETHOD.


  METHOD if_rap_query_request~is_data_requested.
    rv_is_requested = xsdbool( mr_data IS BOUND ).
  ENDMETHOD.


  METHOD if_rap_query_request~is_total_numb_of_rec_requested.
    rv_is_requested = mv_count.
  ENDMETHOD.


  METHOD if_rap_query_request~get_filter.
    ro_filter = me.
  ENDMETHOD.


  METHOD if_rap_query_request~get_paging.
    ro_paging = me.
  ENDMETHOD.


  METHOD if_rap_query_request~get_sort_elements.
    LOOP AT mt_sort INTO DATA(ls_sort).
      APPEND VALUE #( element_name = ls_sort-field
                      descending   = ls_sort-descending ) TO rt_sort_elements.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_rap_query_request~get_parameters ##NEEDED.
    "a parameter of the entity is not supplied
  ENDMETHOD.


  METHOD if_rap_query_request~get_aggregation.
    ro_aggregation = me.
  ENDMETHOD.


  METHOD if_rap_query_request~get_search_expression.
    rv_search_expression = ms_filter-search.
  ENDMETHOD.


  METHOD if_rap_query_request~get_requested_elements.
    rt_requested_elements = mt_elements.
  ENDMETHOD.


  METHOD if_rap_query_response~set_data.
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_data->* TO <lt_data>.
    MOVE-CORRESPONDING it_data TO <lt_data>.
  ENDMETHOD.


  METHOD if_rap_query_response~set_total_number_of_records.
    mv_total = iv_total_number_of_records.
  ENDMETHOD.


  METHOD if_rap_query_filter~get_as_ranges.
    IF ms_filter-no_ranges = abap_true.
      DATA(lx_no_range) = cx_rap_query_filter_no_range=>not_expressable_as_range( ).
      RAISE EXCEPTION lx_no_range.
    ENDIF.
    LOOP AT ms_filter-ranges INTO DATA(ls_range).
      APPEND VALUE #( name  = ls_range-name
                      range = CORRESPONDING #( ls_range-range ) ) TO rt_ranges.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_rap_query_filter~get_as_sql_string.
    rv_string = ms_filter-sql.
  ENDMETHOD.


  METHOD if_rap_query_filter~get_as_tree ##NEEDED.
    "no filter tree - a provider reads the ranges or the SQL string
  ENDMETHOD.


  METHOD if_rap_query_paging~get_offset.
    rv_offset = 0.
  ENDMETHOD.


  METHOD if_rap_query_paging~get_page_size.
    "only the count: no rows - a provider that reads them anyway gets all
    rv_page_size = COND #( WHEN mr_data IS BOUND THEN mv_page_size
                           ELSE if_rap_query_paging=>page_size_unlimited ).
  ENDMETHOD.


  METHOD if_rap_query_aggregation~get_aggregated_elements ##NEEDED.
    "no aggregation is requested
  ENDMETHOD.


  METHOD if_rap_query_aggregation~get_grouped_elements ##NEEDED.
    "no aggregation is requested
  ENDMETHOD.

ENDCLASS.
