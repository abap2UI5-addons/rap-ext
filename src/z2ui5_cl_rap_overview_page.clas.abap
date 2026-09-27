"! Grid of cards (table or KPI) for multiple CDS views.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code - e.g.
"! render_table_card / render_kpi_card to change a single card type.
"! Events the floorplan does not know are routed to on_event.
CLASS z2ui5_cl_rap_overview_page DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        back TYPE string VALUE `BACK`,
      END OF cs_event.

    TYPES:
      BEGIN OF ty_s_card,
        cds_view_name TYPE string,
        title         TYPE string,
        card_type     TYPE string,
        max_rows      TYPE i,
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
        count    TYPE i,
      END OF ty_s_card_data.

    TYPES ty_t_card_data TYPE STANDARD TABLE OF ty_s_card_data WITH DEFAULT KEY.

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

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_overview_page IMPLEMENTATION.

  METHOD constructor.
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

    IF client->check_on_event( cs_event-back ).
      client->nav_app_leave( ).
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


  METHOD load_all_cards.

    LOOP AT mt_cards INTO DATA(ls_card).
      DATA(ls_cd) = VALUE ty_s_card_data( ).
      DATA(lv_view) = to_upper( ls_card-cds_view_name ).

      ls_cd-entity = z2ui5_cl_rap_util=>read_entity( lv_view ).
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

      TRY.
          DATA(lo_descr) = CAST cl_abap_structdescr(
            cl_abap_typedescr=>describe_by_name( lv_view ) ).
          DATA(lo_table_type) = cl_abap_tabledescr=>create( lo_descr ).
          CREATE DATA ls_cd-data_ref TYPE HANDLE lo_table_type.
          FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
          ASSIGN ls_cd-data_ref->* TO <lt_data>.
          SELECT * FROM (lv_view) INTO TABLE @<lt_data>
            UP TO @lv_max ROWS.
          ls_cd-count = lines( <lt_data> ).
        CATCH cx_root.
          CLEAR ls_cd-data_ref.
      ENDTRY.

      APPEND ls_cd TO mt_card_data.
    ENDLOOP.

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
        )->a( n = `xmlns:layout`
              v = `sap.ui.layout`
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

    "grid layout for cards
    DATA(lo_grid) = lo_page->ele( n  = `Grid`
                                   ns = `layout`
        )->a( n = `defaultSpan`
              v = `L6 M12 S12` ).

    LOOP AT mt_card_data INTO DATA(ls_cd).
      DATA(lv_card_idx) = sy-tabix.
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
        WHEN OTHERS.
          render_table_card(
            io_container = lo_grid
            is_card      = ls_cd
            client       = client ).
      ENDCASE.
    ENDLOOP.

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_table_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.

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

    "panel as card container
    DATA(lo_panel) = io_container->ele( `Panel`
        )->a( n = `headerText`
              t = |{ is_card-title } ({ is_card-count })| ).

    "table inside panel
    DATA(lo_table) = lo_panel->ele( `Table`
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
    DATA(lo_cells) = lo_row->ele( `cells` ).
    LOOP AT lt_columns INTO ls_field.
      DATA(lv_path) = |\{{ ls_field-name }\}|.
      lo_cells->tag( `Text`
          )->a( n = `text`
                v = lv_path ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_kpi_card.

    IF is_card-data_ref IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    ASSIGN is_card-data_ref->* TO <lt_data>.

    "find dataPoint fields for KPI
    DATA lv_kpi_value TYPE string.
    LOOP AT is_card-entity-fields INTO DATA(ls_field)
      WHERE datapoint_qualifier IS NOT INITIAL.
      FIELD-SYMBOLS <lv_val> TYPE any.
      READ TABLE <lt_data> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF sy-subrc = 0.
        ASSIGN COMPONENT ls_field-name OF STRUCTURE <ls_row> TO <lv_val>.
        IF sy-subrc = 0.
          lv_kpi_value = <lv_val>.
        ENDIF.
      ENDIF.
      EXIT.
    ENDLOOP.

    IF lv_kpi_value IS INITIAL.
      lv_kpi_value = CONV string( is_card-count ).
    ENDIF.

    "render as GenericTile with NumericContent
    io_container->ele( `GenericTile`
        )->a( n = `header`
              t = is_card-title
        )->a( n = `subheader`
              t = |{ is_card-count } items|
        )->a( n = `frameType`
              v = `OneByOne`
        )->ele( `TileContent`
            )->tag( `NumericContent`
                )->a( n = `value`
                      t = lv_kpi_value ).

  ENDMETHOD.

ENDCLASS.
