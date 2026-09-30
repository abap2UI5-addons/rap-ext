"! Worklist of a CDS view: the items to work through, with a search field
"! instead of a filter bar, optional segments (an IconTabBar with the count
"! of each tab), row navigation to the object page and the @UI.lineItem
"! actions. The tabs are one per value of segment_field when it is given,
"! else one per @UI.selectionVariant of the entity (its filter string, see
"! z2ui5_cl_rap_util=>selection_filter_to_where).
"!
"! Since 2026-09 a subclass of z2ui5_cl_rap_list_report - it used to be a
"! copy of it with fewer features. Its steps (render_page, load_data,
"! get_line_item_fields, on_event) keep their names and signatures, and
"! the list report's steps (render_toolbar, render_cell, get_where_clause,
"! on_row_press, ...) are now overridable here as well.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_worklist DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_list_report
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS cv_event_segment TYPE string VALUE `SEGMENT`.
    CONSTANTS cv_segment_all TYPE string VALUE `ALL`.
    "! the tab of the items without a value - an empty key is no key to
    "! the IconTabBar, which answers the tab's control id instead
    CONSTANTS cv_segment_empty TYPE string VALUE `#EMPTY#`.

    TYPES:
      BEGIN OF ty_s_segment,
        key   TYPE string,
        text  TYPE string,
        count TYPE i,
      END OF ty_s_segment.

    TYPES ty_t_segment TYPE STANDARD TABLE OF ty_s_segment WITH DEFAULT KEY.

    "! segment_field: a field whose values split the items into tabs
    "! (a status, a type) - no tabs without it
    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 500
        segment_field TYPE clike OPTIONAL.

    METHODS z2ui5_if_app~main REDEFINITION.

    "! the tabs - the first is all items
    DATA mt_segment TYPE ty_t_segment.
    "! the selected tab
    DATA mv_segment TYPE string.

  PROTECTED SECTION.
    DATA mv_segment_field TYPE string.

    METHODS load_data REDEFINITION.
    METHODS get_where_clause REDEFINITION.
    METHODS render_page REDEFINITION.
    METHODS render_filter_bar REDEFINITION.
    METHODS render_toolbar REDEFINITION.
    METHODS get_selection_fields REDEFINITION.

    "! the values of segment_field with their counts
    METHODS load_segments
      IMPORTING
        where TYPE string.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_worklist IMPLEMENTATION.

  METHOD constructor.
    super->constructor( cds_view_name = cds_view_name
                        title         = title
                        max_rows      = max_rows ).
    mv_floorplan = cs_floorplan-worklist.
    mv_segment_field = to_upper( segment_field ).
    mv_segment = cv_segment_all.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ) = abap_false
      AND client->check_on_event( cv_event_segment ).
      mv_segment = client->get_event_arg( ).
      load_data( ).
      RETURN.
    ENDIF.

    super->z2ui5_if_app~main( client ).

  ENDMETHOD.


  METHOD get_where_clause.

    result = super->get_where_clause( ).
    IF mv_segment IS INITIAL OR mv_segment = cv_segment_all.
      RETURN.
    ENDIF.

    "a tab of a selection variant: its filter
    IF mv_segment_field IS INITIAL.
      READ TABLE ms_entity-selection_variants INTO DATA(ls_variant) WITH KEY qualifier = mv_segment.
      IF sy-subrc = 0.
        DATA(lv_variant_where) = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = ls_variant-filter
                                                                              it_fields = ms_entity-fields ).
        IF lv_variant_where IS NOT INITIAL.
          result = COND #( WHEN result IS INITIAL THEN lv_variant_where ELSE |{ result } AND { lv_variant_where }| ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = mv_segment_field.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_cond) = COND string( WHEN mv_segment = cv_segment_empty
                                 THEN |{ ls_field-name } IS INITIAL|
                                 ELSE build_filter_condition( is_field = ls_field
                                                              value    = |={ mv_segment }| ) ).
    result = COND #( WHEN result IS INITIAL THEN lv_cond ELSE |{ result } AND { lv_cond }| ).

  ENDMETHOD.


  METHOD load_data.

    super->load_data( ).
    "the counts of every tab, whatever tab is selected
    load_segments( super->get_where_clause( ) ).

  ENDMETHOD.


  METHOD load_segments.

    TYPES:
      BEGIN OF ty_s_group,
        segment_key   TYPE string,
        segment_count TYPE int8,
      END OF ty_s_group.
    DATA lt_group TYPE STANDARD TABLE OF ty_s_group WITH DEFAULT KEY.

    CLEAR mt_segment.

    "no segment field: the selection variants that can be read
    IF mv_segment_field IS INITIAL.
      DATA lt_variant_tab TYPE ty_t_segment.
      LOOP AT ms_entity-selection_variants INTO DATA(ls_variant) WHERE qualifier IS NOT INITIAL.
        DATA(lv_variant_where) = z2ui5_cl_rap_util=>selection_filter_to_where( filter    = ls_variant-filter
                                                                              it_fields = ms_entity-fields ).
        IF lv_variant_where IS INITIAL.
          CONTINUE.
        ENDIF.
        APPEND VALUE #( key   = ls_variant-qualifier
                        text  = ls_variant-text
                        count = count_rows( entity_name = mv_cds_view
                                            where       = COND #( WHEN where IS INITIAL THEN lv_variant_where
                                                                  ELSE |{ where } AND { lv_variant_where }| ) ) )
          TO lt_variant_tab.
      ENDLOOP.
      IF lt_variant_tab IS NOT INITIAL.
        APPEND VALUE #( key   = cv_segment_all
                        text  = get_text( cs_text-all )
                        count = count_rows( entity_name = mv_cds_view
                                            where       = where ) ) TO mt_segment.
        APPEND LINES OF lt_variant_tab TO mt_segment.
      ENDIF.
      RETURN.
    ENDIF.

    IF NOT line_exists( ms_entity-fields[ name = mv_segment_field ] ).
      RETURN.
    ENDIF.

    DATA(lv_select) = |{ mv_segment_field } AS segment_key, COUNT(*) AS segment_count|.
    DATA(lv_where) = get_ext_where( entity_name = mv_cds_view
                                    where       = where ).
    TRY.
        SELECT (lv_select) FROM (mv_cds_view)
          WHERE (lv_where)
          GROUP BY (mv_segment_field)
          INTO CORRESPONDING FIELDS OF TABLE @lt_group
          UP TO 20 ROWS.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    "all items - counted, not summed up from the first 20 groups
    APPEND VALUE #( key   = cv_segment_all
                    text  = get_text( cs_text-all )
                    count = count_rows( entity_name = mv_cds_view
                                        where       = where ) ) TO mt_segment.
    LOOP AT lt_group INTO DATA(ls_group).
      APPEND VALUE #( key   = COND #( WHEN ls_group-segment_key IS INITIAL THEN cv_segment_empty
                                      ELSE ls_group-segment_key )
                      text  = COND #( WHEN ls_group-segment_key IS INITIAL THEN `-` ELSE ls_group-segment_key )
                      count = ls_group-segment_count ) TO mt_segment.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_page.

    IF mr_data IS NOT BOUND.
      client->message_box_display( text = |{ get_text( cs_text-load_error ) }: { mv_cds_view }|
                                   type = `error` ).
      RETURN.
    ENDIF.

    "the events of the list report this class inherits
    DATA(ls_event) = z2ui5_cl_rap_list_report=>cs_event.
    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_page) = lo_view->ele( n  = `View`
                                   ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `displayBlock`
              v = `true`
        )->a( n = `height`
              v = `100%`

        )->ele( `Shell`
            )->ele( `Page`
                )->a( n = `title`
                      t = mv_title
                )->a( n = `showNavButton`
                      b = client->check_app_prev_stack( )
                )->a( n = `navButtonPress`
                      v = client->_event( ls_event-back ) ).

    IF mt_segment IS INITIAL.
      render_table( io_page = lo_page
                    client  = client ).
    ELSE.
      "one tab per segment - the table is the content of the bar
      DATA(lo_bar) = lo_page->ele( `IconTabBar`
          )->a( n = `selectedKey`
                v = client->_bind( mv_segment )
          )->a( n = `select`
                v = client->_event( val = cv_event_segment
                                    arg = `${$parameters>/key}` )
          )->a( n = `expandable`
                v = `false`
          )->a( n = `items`
                v = client->_bind( mt_segment ) ).
      lo_bar->ele( `items`
          )->tag( `IconTabFilter`
              )->a( n = `key`
                    v = `{KEY}`
              )->a( n = `text`
                    v = `{TEXT}`
              )->a( n = `count`
                    v = `{COUNT}` ).
      render_table( io_page = lo_bar->ele( `content` )
                    client  = client ).
    ENDIF.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD get_selection_fields ##NEEDED.
    "no filters - a filter the worklist does not show, @Consumption.filter
    "defaultValue included, would silently narrow the items
  ENDMETHOD.


  METHOD render_filter_bar ##NEEDED.
    "no filter bar - the worklist searches in its toolbar
  ENDMETHOD.


  METHOD render_toolbar.

    "the events of the list report this class inherits
    DATA(ls_event) = z2ui5_cl_rap_list_report=>cs_event.
    DATA(lo_toolbar) = io_table->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).

    lo_toolbar->tag( `Title`
        )->a( n = `text`
              v = mv_title && ` (` && client->_bind( mv_count ) && `)` ).

    lo_toolbar->tag( `ToolbarSpacer` ).

    lo_toolbar->tag( `SearchField`
        )->a( n = `value`
              v = client->_bind( mv_search )
        )->a( n = `search`
              v = client->_event( ls_event-search )
        )->a( n = `width`
              v = `15rem` ).

    render_sort_controls( io_toolbar = lo_toolbar
                          client     = client ).

    "@UI.lineItem actions of type #FOR_ACTION - on the selected rows
    LOOP AT get_line_item_actions( abap_false ) INTO DATA(ls_action).
      lo_toolbar->tag( `Button`
          )->a( n = `text`
                t = ls_action-label
          )->a( n = `press`
                v = client->_event( val = ls_event-action
                                    arg = ls_action-name ) ).
    ENDLOOP.

    lo_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://refresh`
        )->a( n = `tooltip`
              t = get_text( cs_text-refresh )
        )->a( n = `press`
              v = client->_event( ls_event-refresh ) ).

  ENDMETHOD.

ENDCLASS.
