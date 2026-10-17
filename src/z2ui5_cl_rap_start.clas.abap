"! Opens a floorplan from the parameters of its URL - the target of a deep
"! link or a bookmark that outlives the abap2UI5 draft:
"!   ...?app_start=zcl_my_rap_start&amp;floorplan=OBJECT_PAGE&amp;entity=I_COUNTRY&amp;Country=DE
"! or the same as startup parameters of a launchpad tile. floorplan is
"! OBJECT_PAGE (the default when keys are given), LIST_REPORT or WORKLIST;
"! every other parameter is a key of the object page - or, for a list
"! report or a worklist, the value of the filter of the field it names
"! (since 2026-10, third round; map_parameters, a parameter that names no
"! field is ignored). mode=edit opens the object page in edit mode. The
"! floorplan replaces this app (nav_app_leave), so Back does not return
"! to it.
"!
"! A URL can name any entity, so this class opens none by itself: a
"! subclass lists the entities it may open (get_allowed_entities) and can
"! hand the floorplans an extension (get_extension); its name is the one
"! app_start names. get_link( ) builds such a link, and the object page's
"! link button uses it when z2ui5_if_rap_ext~get_start_app names the class.
CLASS z2ui5_cl_rap_start DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_param,
        floorplan TYPE string VALUE `floorplan`,
        entity    TYPE string VALUE `entity`,
        "added 2026-10, third round: display (the default) or edit - the
        "mode the object page opens in
        mode      TYPE string VALUE `mode`,
      END OF cs_param.

    " the values of cs_param-mode
    CONSTANTS:
      BEGIN OF cs_mode,
        display TYPE string VALUE `display`,
        edit    TYPE string VALUE `edit`,
      END OF cs_mode.

    "! the absolute URL that opens floorplan (one of
    "! z2ui5_cl_rap_floorplan=>cs_floorplan) for entity_name, with keys,
    "! through start_class - a subclass of this class
    CLASS-METHODS get_link
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
        start_class   TYPE clike
        floorplan     TYPE clike
        entity_name   TYPE clike
        keys          TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

    "! why nothing was opened
    DATA mv_message TYPE string.

    "! the entities a URL may open - none here; redefine it
    METHODS get_allowed_entities
      RETURNING
        VALUE(result) TYPE string_table.

    "! the extension the floorplan of entity_name gets - none here
    METHODS get_extension
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_if_rap_ext.

    "! the launchpad's startup parameters and the URL's query, names and
    "! values decoded
    METHODS get_parameters
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.

    "! the parameters that are no floorplan, entity or mode - as the
    "! extension maps them (z2ui5_if_rap_ext~map_inbound_parameter): a
    "! renamed one gets its new name, one whose name the extension clears
    "! is left out. Redefine it to map them here (added 2026-10, third
    "! round)
    METHODS map_parameters
      IMPORTING
        floorplan     TYPE string
        entity_name   TYPE string
        params        TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.

    "! open the floorplan the parameters name, if the entity is allowed
    METHODS open
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a page with mv_message - when nothing could be opened
    METHODS render_message
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_start IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      open( client ).
      RETURN.
    ENDIF.

    IF client->check_on_navigated( ).
      render_message( client ).
    ENDIF.

  ENDMETHOD.


  METHOD get_allowed_entities ##NEEDED.
    "a subclass names them - a URL opens nothing here
  ENDMETHOD.


  METHOD get_extension ##NEEDED.
    "a subclass hands one over - none here
  ENDMETHOD.


  METHOD get_parameters.

    "the core names them n and v
    LOOP AT client->get( )-t_comp_params INTO DATA(ls_comp).
      APPEND VALUE #( name = ls_comp-n value = ls_comp-v ) TO result.
    ENDLOOP.
    APPEND LINES OF z2ui5_cl_rap_util=>parse_url_query( client->get( )-s_config-search ) TO result.
    "the framework's and the system's own
    DELETE result WHERE name = `app_start` OR name CP `sap-*`.

  ENDMETHOD.


  METHOD map_parameters.

    DATA(lo_ext) = get_extension( entity_name ).
    LOOP AT params INTO DATA(ls_param).
      IF lo_ext IS BOUND.
        lo_ext->map_inbound_parameter( EXPORTING floorplan   = floorplan
                                                 entity_name = entity_name
                                       CHANGING  name        = ls_param-name
                                                 value       = ls_param-value ).
      ENDIF.
      IF ls_param-name IS NOT INITIAL.
        APPEND ls_param TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD open.

    DATA lt_keys TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.
    DATA lt_others TYPE z2ui5_cl_rap_floorplan=>ty_t_name_value.
    DATA lo_floorplan TYPE REF TO z2ui5_cl_rap_floorplan.

    DATA(lt_params) = get_parameters( client ).
    DATA(lv_entity) = ``.
    DATA(lv_floorplan) = ``.
    DATA(lv_mode) = cs_mode-display.
    LOOP AT lt_params INTO DATA(ls_param).
      CASE to_lower( ls_param-name ).
        WHEN cs_param-entity.
          lv_entity = to_upper( ls_param-value ).
        WHEN cs_param-floorplan.
          lv_floorplan = to_upper( ls_param-value ).
        WHEN cs_param-mode.
          lv_mode = to_lower( ls_param-value ).
        WHEN OTHERS.
          APPEND ls_param TO lt_others.
      ENDCASE.
    ENDLOOP.

    DATA(lt_allowed) = get_allowed_entities( ).
    LOOP AT lt_allowed ASSIGNING FIELD-SYMBOL(<lv_allowed>).
      <lv_allowed> = to_upper( <lv_allowed> ).
    ENDLOOP.
    IF lv_entity IS INITIAL OR NOT line_exists( lt_allowed[ table_line = lv_entity ] ).
      mv_message = |{ lv_entity }: { z2ui5_cl_rap_floorplan=>get_default_text( z2ui5_cl_rap_floorplan=>cs_text-no_authority ) }|.
      render_message( client ).
      RETURN.
    ENDIF.

    IF lv_floorplan IS INITIAL.
      lv_floorplan = COND #( WHEN lt_others IS INITIAL THEN z2ui5_cl_rap_floorplan=>cs_floorplan-list_report
                             ELSE z2ui5_cl_rap_floorplan=>cs_floorplan-object_page ).
    ENDIF.
    IF lv_floorplan <> z2ui5_cl_rap_floorplan=>cs_floorplan-worklist
      AND lv_floorplan <> z2ui5_cl_rap_floorplan=>cs_floorplan-object_page.
      lv_floorplan = z2ui5_cl_rap_floorplan=>cs_floorplan-list_report.
    ENDIF.

    "the other parameters: keys of an object page, filter values of a list
    LOOP AT map_parameters( floorplan   = lv_floorplan
                            entity_name = lv_entity
                            params      = lt_others ) INTO DATA(ls_mapped).
      IF NOT line_exists( lt_keys[ name = to_upper( ls_mapped-name ) ] ).
        APPEND VALUE #( name = to_upper( ls_mapped-name ) value = ls_mapped-value ) TO lt_keys.
      ENDIF.
    ENDLOOP.

    CASE lv_floorplan.
      WHEN z2ui5_cl_rap_floorplan=>cs_floorplan-worklist.
        DATA(lo_worklist) = NEW z2ui5_cl_rap_worklist( cds_view_name = lv_entity ).
        lo_worklist->set_filter_presets( lt_keys ).
        lo_floorplan = lo_worklist.
      WHEN z2ui5_cl_rap_floorplan=>cs_floorplan-object_page.
        lo_floorplan = NEW z2ui5_cl_rap_object_page( cds_view_name = lv_entity
                                                      keys          = lt_keys
                                                      editable      = xsdbool( lv_mode = cs_mode-edit ) ).
      WHEN OTHERS.
        DATA(lo_list) = NEW z2ui5_cl_rap_list_report( cds_view_name = lv_entity ).
        lo_list->set_filter_presets( lt_keys ).
        lo_floorplan = lo_list.
    ENDCASE.

    DATA(lo_ext) = get_extension( lv_entity ).
    IF lo_ext IS BOUND.
      lo_floorplan->set_extension( lo_ext ).
    ENDIF.
    "the floorplan replaces this app - Back does not lead here
    client->nav_app_leave( CAST z2ui5_if_app( lo_floorplan ) ).

  ENDMETHOD.


  METHOD render_message.

    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).
    lo_view->ele( n  = `View`
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
                      v = `abap2UI5`
                )->tag( `MessageStrip`
                    )->a( n = `text`
                          t = mv_message
                    )->a( n = `type`
                          v = `Warning`
                    )->a( n = `class`
                          v = `sapUiSmallMargin` ).
    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD get_link.

    DATA(ls_config) = client->get( )-s_config.
    "the system's own parameters (sap-client, sap-language) stay
    DATA lt_query TYPE string_table.
    LOOP AT z2ui5_cl_rap_util=>parse_url_query( ls_config-search ) INTO DATA(ls_param) WHERE name CP `sap-*`.
      APPEND |{ z2ui5_cl_rap_util=>url_encode( ls_param-name ) }={ z2ui5_cl_rap_util=>url_encode( ls_param-value ) }|
        TO lt_query.
    ENDLOOP.
    APPEND |app_start={ z2ui5_cl_rap_util=>url_encode( to_lower( start_class ) ) }| TO lt_query.
    APPEND |{ cs_param-floorplan }={ z2ui5_cl_rap_util=>url_encode( floorplan ) }| TO lt_query.
    APPEND |{ cs_param-entity }={ z2ui5_cl_rap_util=>url_encode( entity_name ) }| TO lt_query.
    LOOP AT keys INTO DATA(ls_key).
      APPEND |{ z2ui5_cl_rap_util=>url_encode( ls_key-name ) }={ z2ui5_cl_rap_util=>url_encode( ls_key-value ) }|
        TO lt_query.
    ENDLOOP.
    result = |{ ls_config-origin }{ ls_config-pathname }?{ concat_lines_of( table = lt_query sep = `&` ) }|.

  ENDMETHOD.

ENDCLASS.
