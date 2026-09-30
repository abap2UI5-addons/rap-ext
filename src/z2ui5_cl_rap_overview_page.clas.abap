"! Grid of cards (table, KPI or chart) for multiple CDS views.
"!
"! - TABLE: the first rows of the view; a row opens its object page
"! - KPI: one aggregated number - SUM (or kpi_aggregation) of kpi_field,
"!   else of the first numeric @UI.dataPoint field, else the row count
"! - CHART: a bar per value of the first dimension of @UI.chart, the
"!   measure summed up - drawn with sap.m.ProgressIndicator, which every
"!   UI5 runtime has (the microchart library is SAPUI5 only)
"! Every card links to the list report of its view.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code - e.g.
"! render_table_card / render_kpi_card to change a single card type.
"! Events the floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_overview_page DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        back     TYPE string VALUE `BACK`,
        card     TYPE string VALUE `CARD`,
        card_row TYPE string VALUE `CARD_ROW`,
      END OF cs_event.

    TYPES:
      BEGIN OF ty_s_card,
        cds_view_name   TYPE string,
        title           TYPE string,
        "TABLE (default), KPI or CHART
        card_type       TYPE string,
        max_rows        TYPE i,
        "added 2026-09 - appended so the existing layout stays as it was
        "KPI: the field to aggregate and how (SUM, AVG, MIN, MAX, COUNT)
        kpi_field       TYPE string,
        kpi_aggregation TYPE string,
        "KPI: the unit shown next to the number
        kpi_unit        TYPE string,
        "CHART: the @UI.chart to draw - the first one when empty
        chart_qualifier TYPE string,
      END OF ty_s_card.

    TYPES ty_t_card TYPE STANDARD TABLE OF ty_s_card WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        title TYPE string OPTIONAL
        cards TYPE ty_t_card.

    TYPES:
      BEGIN OF ty_s_card_data,
        entity   TYPE z2ui5_cl_rap_util=>ty_s_entity_info,
        data_ref TYPE REF TO data,
        title    TYPE string,
        "the rows of the view (all of them, not only the ones loaded)
        count    TYPE i,
        "added 2026-09 - appended so the existing layout stays as it was
        kpi_value       TYPE string,
        chart_dimension TYPE string,
        chart_measure   TYPE string,
        "the largest measure - the 100 % of the chart's bars
        chart_max       TYPE decfloat34,
      END OF ty_s_card_data.

    TYPES ty_t_card_data TYPE STANDARD TABLE OF ty_s_card_data WITH DEFAULT KEY.

    "! a bar of a chart card - fixed names, so the card binds static paths
    TYPES:
      BEGIN OF ty_s_chart_row,
        dimension TYPE string,
        measure   TYPE decfloat34,
        "the bar's length - measure against the largest measure
        percent   TYPE decfloat34,
      END OF ty_s_chart_row.

    TYPES ty_t_chart_row TYPE STANDARD TABLE OF ty_s_chart_row WITH DEFAULT KEY.

    DATA mt_card_data TYPE ty_t_card_data.

    "! The rows of every loaded card - what the card render hooks bind. A
    "! structure built at runtime with one component per card, CARD_1,
    "! CARD_2, ... after the card's position in mt_card_data, each typed as
    "! that card's table. PUBLIC and a REF TO data on purpose: that is what
    "! the abap2UI5 model resolves a binding into and carries through the
    "! draft. The data_ref in a row of mt_card_data is neither - the model
    "! never looks into the rows of a table, so a binding on it ended the
    "! first render of every table card with BINDING_ERROR.
    DATA mr_card_rows TYPE REF TO data.

  PROTECTED SECTION.
    DATA mv_title TYPE string.
    DATA mt_cards TYPE ty_t_card.
    "! the position of the card render_page is rendering - what its
    "! events carry (two cards may well have the same title)
    DATA mv_card_index TYPE i.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS load_all_cards.

    "! Move the rows each loaded card holds into mr_card_rows, one component
    "! per card, and point the card's data_ref at its component - so the
    "! is_card-data_ref->* a render hook binds is a data object the model
    "! can resolve. Runs between load_all_cards and render_page.
    METHODS collect_card_rows.

    "! load, collect the rows into mr_card_rows, render, then drop the
    "! generic references again - render_page( ) needs every data_ref BOUND
    "! and pointing into mr_card_rows, and a data_ref cannot survive
    "! serialization, so the four steps only ever make sense together
    METHODS display
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_table_card
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

    METHODS render_kpi_card
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

    METHODS render_chart_card
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

    "! the "show all" link of a card - it opens the view's list report
    METHODS render_card_link
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_card      TYPE ty_s_card_data
        client       TYPE REF TO z2ui5_if_client.

    "! the aggregated number of a KPI card
    METHODS load_kpi_value
      IMPORTING
        is_card       TYPE ty_s_card
      CHANGING
        cs_card_data  TYPE ty_s_card_data.

    "! the rows of a chart card: the measure summed up per dimension value
    METHODS load_chart_rows
      IMPORTING
        is_card       TYPE ty_s_card
      CHANGING
        cs_card_data  TYPE ty_s_card_data.

    "! a card's header or link - its list report
    METHODS on_card
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a row of a table card - its object page
    METHODS on_card_row
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the position of the card in mt_card_data, from its event argument
    METHODS get_card_index
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE i.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_overview_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-overview_page.
    mv_title = title.
    mt_cards = cards.
    IF mv_title IS INITIAL.
      mv_title = `Overview`.
    ENDIF.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      display( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-card ).
      on_card( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-card_row ).
      on_card_row( client ).
      RETURN.
    ENDIF.

    "returning from a called app or a restored bookmark: check_on_init( ) is
    "false here and the browser still shows the OTHER app's view, so the view
    "has to be built again - a model push would reach nothing
    IF client->check_on_navigated( ).
      display( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD get_card_index.
    DATA(lv_arg) = client->get_event_arg( ).
    REPLACE `CARD_` IN lv_arg WITH ``.
    IF lv_arg IS INITIAL OR lv_arg CN `0123456789`.
      RETURN.
    ENDIF.
    result = lv_arg.
  ENDMETHOD.


  METHOD on_card.

    READ TABLE mt_cards INTO DATA(ls_card) INDEX get_card_index( client ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lo_lr) = NEW z2ui5_cl_rap_list_report( cds_view_name = ls_card-cds_view_name
                                                title         = ls_card-title ).
    lo_lr->set_extension( mo_ext ).
    client->nav_app_call( lo_lr ).

  ENDMETHOD.


  METHOD on_card_row.

    FIELD-SYMBOLS <ls_rows> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    DATA(lv_index) = get_card_index( client ).
    READ TABLE mt_card_data INTO DATA(ls_cd) INDEX lv_index.
    IF sy-subrc <> 0 OR mr_card_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_card_rows->* TO <ls_rows>.
    ASSIGN COMPONENT |CARD_{ lv_index }| OF STRUCTURE <ls_rows> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lr_row) = find_row_by_event_keys( data       = REF #( <lt_rows> )
                                           key_fields = ls_cd-entity-keys
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO FIELD-SYMBOL(<ls_row>).
    DATA(lr_entity_row) = to_entity_row( entity_name = ls_cd-entity-name
                                         row         = <ls_row> ).
    ASSIGN lr_entity_row->* TO <ls_row>.
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( val = <ls_row> ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD load_all_cards.

    LOOP AT mt_cards INTO DATA(ls_card).
      DATA(ls_cd) = VALUE ty_s_card_data( ).
      DATA(lv_view) = CONV string( to_upper( ls_card-cds_view_name ) ).

      ls_cd-entity = z2ui5_cl_rap_util=>read_entity( lv_view ).
      adjust_entity( CHANGING cs_entity = ls_cd-entity ).
      ls_cd-title = ls_card-title.
      IF ls_cd-title IS INITIAL.
        IF ls_cd-entity-header_info-type_name_plural IS NOT INITIAL.
          ls_cd-title = ls_cd-entity-header_info-type_name_plural.
        ELSE.
          ls_cd-title = lv_view.
        ENDIF.
      ENDIF.

      DATA(lv_max) = ls_card-max_rows.
      IF lv_max <= 0.
        lv_max = 5.
      ENDIF.

      ls_cd-count = count_rows( lv_view ).

      CASE to_upper( ls_card-card_type ).
        WHEN `KPI` OR `NUMERIC`.
          load_kpi_value( EXPORTING is_card      = ls_card
                          CHANGING  cs_card_data = ls_cd ).
        WHEN `CHART`.
          load_chart_rows( EXPORTING is_card      = ls_card
                           CHANGING  cs_card_data = ls_cd ).
        WHEN OTHERS.
          ls_cd-data_ref = select_rows( entity_name = lv_view
                                        max_rows    = lv_max ).
      ENDCASE.

      APPEND ls_cd TO mt_card_data.
    ENDLOOP.

  ENDMETHOD.


  METHOD load_kpi_value.

    DATA lv_value TYPE decfloat34.
    DATA(lv_view) = CONV string( to_upper( is_card-cds_view_name ) ).

    "the field: the card's, else the first numeric data point
    DATA(lv_field) = CONV string( to_upper( is_card-kpi_field ) ).
    IF lv_field IS INITIAL.
      LOOP AT cs_card_data-entity-fields INTO DATA(ls_field)
        WHERE datapoint_qualifier IS NOT INITIAL
          AND ( type_kind = `DEC` OR type_kind = `INT` ).
        lv_field = ls_field-name.
        EXIT.
      ENDLOOP.
    ENDIF.

    DATA(lv_aggregation) = to_upper( is_card-kpi_aggregation ).
    IF lv_aggregation IS INITIAL.
      lv_aggregation = `SUM`.
    ENDIF.

    IF lv_field IS INITIAL OR lv_aggregation = `COUNT`
      OR NOT line_exists( cs_card_data-entity-fields[ name = lv_field ] ).
      cs_card_data-kpi_value = |{ cs_card_data-count }|.
      RETURN.
    ENDIF.
    IF lv_aggregation <> `SUM` AND lv_aggregation <> `AVG`
      AND lv_aggregation <> `MIN` AND lv_aggregation <> `MAX`.
      lv_aggregation = `SUM`.
    ENDIF.

    DATA(lv_select) = |{ lv_aggregation }( { lv_field } )|.
    TRY.
        SELECT SINGLE (lv_select) FROM (lv_view) INTO @lv_value.
        cs_card_data-kpi_value = |{ lv_value NUMBER = USER }|.
      CATCH cx_root.
        cs_card_data-kpi_value = |{ cs_card_data-count }|.
    ENDTRY.

  ENDMETHOD.


  METHOD load_chart_rows.

    DATA lt_rows TYPE ty_t_chart_row.

    DATA(lv_view) = CONV string( to_upper( is_card-cds_view_name ) ).
    DATA(ls_chart) = VALUE z2ui5_cl_rap_util=>ty_s_chart( ).
    IF is_card-chart_qualifier IS NOT INITIAL.
      READ TABLE cs_card_data-entity-charts INTO ls_chart WITH KEY qualifier = is_card-chart_qualifier.
    ELSEIF cs_card_data-entity-charts IS NOT INITIAL.
      ls_chart = cs_card_data-entity-charts[ 1 ].
    ENDIF.
    IF ls_chart-dimensions IS INITIAL OR ls_chart-measures IS INITIAL.
      RETURN.
    ENDIF.

    cs_card_data-chart_dimension = ls_chart-dimensions[ 1 ].
    cs_card_data-chart_measure = ls_chart-measures[ 1 ].
    IF NOT line_exists( cs_card_data-entity-fields[ name = cs_card_data-chart_dimension ] )
      OR NOT line_exists( cs_card_data-entity-fields[ name = cs_card_data-chart_measure ] ).
      RETURN.
    ENDIF.

    DATA(lv_select) = |{ cs_card_data-chart_dimension } AS dimension, SUM( { cs_card_data-chart_measure } ) AS measure|.
    DATA(lv_max) = COND i( WHEN is_card-max_rows > 0 THEN is_card-max_rows ELSE 8 ).
    TRY.
        SELECT (lv_select) FROM (lv_view)
          GROUP BY (cs_card_data-chart_dimension)
          ORDER BY (cs_card_data-chart_dimension)
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO @lv_max ROWS.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_rows INTO DATA(ls_row).
      IF ls_row-measure > cs_card_data-chart_max.
        cs_card_data-chart_max = ls_row-measure.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF cs_card_data-chart_max > 0.
        <ls_row>-percent = <ls_row>-measure * 100 / cs_card_data-chart_max.
      ENDIF.
    ENDLOOP.

    CREATE DATA cs_card_data-data_ref TYPE ty_t_chart_row.
    cs_card_data-data_ref->* = lt_rows.
    IF cs_card_data-title IS INITIAL AND ls_chart-title IS NOT INITIAL.
      cs_card_data-title = ls_chart-title.
    ENDIF.

  ENDMETHOD.


  METHOD collect_card_rows.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lv_name TYPE string.
    FIELD-SYMBOLS <ls_rows> TYPE any.
    FIELD-SYMBOLS <lt_card> TYPE any.
    FIELD-SYMBOLS <lt_comp> TYPE any.

    CLEAR mr_card_rows.

    LOOP AT mt_card_data INTO DATA(ls_cd).
      DATA(lv_card) = sy-tabix.
      IF ls_cd-data_ref IS NOT BOUND.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = |CARD_{ lv_card }|
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( ls_cd-data_ref ) ) )
        TO lt_comp.
    ENDLOOP.

    IF lt_comp IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_rows) = cl_abap_structdescr=>create( lt_comp ).
    CREATE DATA mr_card_rows TYPE HANDLE lo_rows.
    ASSIGN mr_card_rows->* TO <ls_rows>.

    "a copy per card - the tables are the few rows load_all_cards selected
    LOOP AT mt_card_data ASSIGNING FIELD-SYMBOL(<ls_cd>).
      lv_card = sy-tabix.
      IF <ls_cd>-data_ref IS NOT BOUND.
        CONTINUE.
      ENDIF.
      lv_name = |CARD_{ lv_card }|.
      ASSIGN COMPONENT lv_name OF STRUCTURE <ls_rows> TO <lt_comp>.
      ASSIGN <ls_cd>-data_ref->* TO <lt_card>.
      <lt_comp> = <lt_card>.
      <ls_cd>-data_ref = REF #( <lt_comp> ).
    ENDLOOP.

  ENDMETHOD.


  METHOD display.

    "load_all_cards appends - without this, a second display( )
    "(check_on_navigated) kept the first set in front of the new one, and
    "render_page( ), which reads the card type from mt_cards by row index,
    "rendered every new card with the type of the last one
    CLEAR mt_card_data.
    load_all_cards( ).
    collect_card_rows( ).
    render_page( client ).

    "data_ref points into mr_card_rows now, which the framework carries
    "through the draft; a generic reference in a row of mt_card_data is not
    "serializable, so it is dropped once the view is built
    LOOP AT mt_card_data ASSIGNING FIELD-SYMBOL(<ls_cd>).
      CLEAR <ls_cd>-data_ref.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_page) = lo_view->ele( n  = `View`
                                   ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `xmlns:f`
              v = `sap.f`
        )->a( n = `xmlns:card`
              v = `sap.f.cards`
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
                      v = client->_event( cs_event-back ) ).

    "grid of cards
    DATA(lo_grid) = lo_page->ele( n  = `GridContainer`
                                   ns = `f`
        )->a( n = `class`
              v = `sapUiSmallMargin` ).

    LOOP AT mt_card_data INTO DATA(ls_cd).
      DATA(lv_card_idx) = sy-tabix.
      mv_card_index = lv_card_idx.
      READ TABLE mt_cards INDEX lv_card_idx INTO DATA(ls_card_cfg).

      DATA(lv_type) = `TABLE`.
      IF ls_card_cfg-card_type IS NOT INITIAL.
        lv_type = to_upper( ls_card_cfg-card_type ).
      ENDIF.

      CASE lv_type.
        WHEN `KPI` OR `NUMERIC`.
          render_kpi_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
        WHEN `CHART`.
          render_chart_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
        WHEN OTHERS.
          render_table_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
      ENDCASE.
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_card_link.

    DATA(lv_index) = mv_card_index.
    io_container->tag( `Link`
        )->a( n = `text`
              t = |{ get_text( cs_text-all ) } ({ is_card-count })|
        )->a( n = `press`
              v = client->_event( val = cs_event-card
                                  arg = |CARD_{ lv_index }| )
        )->a( n = `class`
              v = `sapUiSmallMargin` ).

  ENDMETHOD.


  METHOD render_table_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.
    DATA(lv_index) = mv_card_index.

    "get lineItem fields or all visible
    DATA lt_columns TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    LOOP AT is_card-entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO lt_columns.
    ENDLOOP.
    SORT lt_columns BY line_item_pos.
    IF lt_columns IS INITIAL.
      LOOP AT is_card-entity-fields INTO ls_field
        WHERE is_hidden = abap_false.
        APPEND ls_field TO lt_columns.
        IF lines( lt_columns ) >= 5.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA(lo_card) = io_container->ele( n  = `Card`
                                        ns = `f` ).
    lo_card->ele( n  = `layoutData`
                  ns = `f`
        )->tag( n  = `GridContainerItemLayoutData`
                ns = `f`
            )->a( n = `columns`
                  v = `6` ).
    lo_card->ele( n  = `header`
                  ns = `f`
        )->tag( n  = `Header`
                ns = `card`
            )->a( n = `title`
                  t = is_card-title
            )->a( n = `subtitle`
                  t = |{ is_card-count } { get_text( cs_text-items ) }| ).

    DATA(lo_content) = lo_card->ele( n  = `content`
                                     ns = `f`
        )->ele( `VBox` ).

    "table inside the card
    DATA(lo_table) = lo_content->ele( `Table`
        )->a( n = `items`
              v = `{path:'` && client->_bind( val  = <lt_data>
                                              path = abap_true ) && `'}`
        )->a( n = `mode`
              v = `None` ).

    DATA(lo_columns) = lo_table->ele( `columns` ).
    LOOP AT lt_columns INTO ls_field.
      DATA(lv_label) = ls_field-line_item_label.
      IF lv_label IS INITIAL.
        lv_label = ls_field-label.
      ENDIF.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = lv_label ).
    ENDLOOP.

    DATA(lo_items) = lo_table->ele( `items` ).
    DATA(lo_row) = lo_items->ele( `ColumnListItem` ).
    "a row opens its object page - which needs the entity's keys
    IF is_card-entity-keys IS NOT INITIAL.
      DATA(lt_arg) = VALUE string_table( ( |CARD_{ lv_index }| ) ).
      LOOP AT is_card-entity-keys INTO DATA(lv_key).
        APPEND `${` && lv_key && `}` TO lt_arg.
      ENDLOOP.
      lo_row->a( n = `type`
                 v = `Navigation`
          )->a( n = `press`
                v = client->_event( val   = cs_event-card_row
                                    t_arg = lt_arg ) ).
    ENDIF.
    DATA(lo_cells) = lo_row->ele( `cells` ).
    LOOP AT lt_columns INTO ls_field.
      DATA(lv_path) = |\{{ ls_field-name }\}|.
      lo_cells->tag( `Text`
          )->a( n = `text`
                v = lv_path ).
    ENDLOOP.

    render_card_link( io_container = lo_content
                      is_card      = is_card
                      client       = client ).

  ENDMETHOD.


  METHOD render_kpi_card.

    DATA(lv_kpi_value) = is_card-kpi_value.
    IF lv_kpi_value IS INITIAL.
      lv_kpi_value = CONV string( is_card-count ).
    ENDIF.
    DATA(lv_index) = mv_card_index.
    READ TABLE mt_cards INDEX lv_index INTO DATA(ls_card).

    DATA(lo_card) = io_container->ele( n  = `Card`
                                        ns = `f` ).
    lo_card->ele( n  = `layoutData`
                  ns = `f`
        )->tag( n  = `GridContainerItemLayoutData`
                ns = `f`
            )->a( n = `columns`
                  v = `3` ).
    lo_card->ele( n  = `header`
                  ns = `f`
        )->tag( n  = `NumericHeader`
                ns = `card`
            )->a( n = `title`
                  t = is_card-title
            )->a( n = `subtitle`
                  t = |{ is_card-count } { get_text( cs_text-items ) }|
            )->a( n = `number`
                  t = lv_kpi_value
            )->a( n = `unitOfMeasurement`
                  t = ls_card-kpi_unit ).

    DATA(lo_content) = lo_card->ele( n  = `content`
                                     ns = `f` ).
    render_card_link( io_container = lo_content
                      is_card      = is_card
                      client       = client ).

  ENDMETHOD.


  METHOD render_chart_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.

    DATA(lo_card) = io_container->ele( n  = `Card`
                                        ns = `f` ).
    lo_card->ele( n  = `layoutData`
                  ns = `f`
        )->tag( n  = `GridContainerItemLayoutData`
                ns = `f`
            )->a( n = `columns`
                  v = `4` ).
    lo_card->ele( n  = `header`
                  ns = `f`
        )->tag( n  = `Header`
                ns = `card`
            )->a( n = `title`
                  t = is_card-title ).

    DATA(lo_content) = lo_card->ele( n  = `content`
                                     ns = `f`
        )->ele( `VBox`
            )->a( n = `class`
                  v = `sapUiSmallMargin` ).

    "one bar per dimension value - the largest measure is the full bar
    DATA(lo_bars) = lo_content->ele( `VBox`
        )->a( n = `items`
              v = `{path:'` && client->_bind( val  = <lt_data>
                                              path = abap_true ) && `'}` ).
    DATA(lo_bar) = lo_bars->ele( `VBox` ).
    lo_bar->tag( `Label`
        )->a( n = `text`
              v = `{DIMENSION}` ).
    lo_bar->tag( `ProgressIndicator`
        )->a( n = `percentValue`
              v = `{PERCENT}`
        )->a( n = `displayValue`
              v = `{MEASURE}`
        )->a( n = `displayOnly`
              v = `true` ).

    render_card_link( io_container = lo_content
                      is_card      = is_card
                      client       = client ).

  ENDMETHOD.

ENDCLASS.
