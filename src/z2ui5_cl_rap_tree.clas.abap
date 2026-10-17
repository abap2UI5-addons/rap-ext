"! Tree of a CDS view with a hierarchy - a list report whose rows are the
"! nodes, each under its parent, with expand and collapse (added 2026-10,
"! third round). The hierarchy comes from the annotations
"! (z2ui5_cl_rap_util=>read_hierarchy: the parent child hierarchy
"! annotation, the CDS hierarchy of @OData.hierarchy.recursiveHierarchy, a
"! parent association of the entity to itself), from the constructor or
"! from z2ui5_if_rap_ext~adjust_hierarchy.
"!
"! The nodes are read at once, up to max_rows, sorted by the order of the
"! siblings; expand and collapse are a roundtrip that reads nothing (the
"! collapsed nodes stay in the rows, hidden). A node whose parent is not
"! read - filtered away, or beyond max_rows - is shown as a root. The
"! filter bar, the search, the views, the actions and the object page are
"! the list report's; the table is the responsive one.
"!
"! Create child opens the object page of a new record with the parent
"! field set to the selected node; Delete removes the selected node and,
"! by the delete mode (z2ui5_cl_rap_util=>cs_tree_delete, the
"! constructor, the hierarchy, get_delete_mode), its subtree, or moves
"! its children up to its parent, or refuses a node with children.
"!
"! Like every floorplan the class is not FINAL: the steps below are
"! protected and can be redefined.
CLASS z2ui5_cl_rap_tree DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_list_report
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_tree_event,
        toggle         TYPE string VALUE `TREE_TOGGLE`,
        expand_all     TYPE string VALUE `TREE_EXPAND_ALL`,
        collapse_all   TYPE string VALUE `TREE_COLLAPSE_ALL`,
        create_child   TYPE string VALUE `TREE_CREATE_CHILD`,
        delete         TYPE string VALUE `TREE_DELETE`,
        delete_confirm TYPE string VALUE `TREE_DELETE_CONFIRM`,
        delete_cancel  TYPE string VALUE `TREE_DELETE_CANCEL`,
      END OF cs_tree_event.

    " the columns a row of the tree gets: the node's key, its indent (a CSS
    " size), whether it has children and is expanded
    CONSTANTS:
      BEGIN OF cs_tree_column,
        key      TYPE string VALUE `ZZTREE_KEY`,
        indent   TYPE string VALUE `ZZTREE_INDENT`,
        children TYPE string VALUE `ZZTREE_CHILDREN`,
        expanded TYPE string VALUE `ZZTREE_EXPANDED`,
      END OF cs_tree_column.

    "! hierarchy: the fields, order and delete mode instead of the
    "! annotations' (empty components are read from them); delete_mode:
    "! z2ui5_cl_rap_util=>cs_tree_delete; expand_levels: the levels shown
    "! expanded at the start (1 - the roots)
    METHODS constructor
      IMPORTING
        cds_view_name TYPE clike
        title         TYPE string OPTIONAL
        max_rows      TYPE i DEFAULT 1000
        hierarchy     TYPE z2ui5_cl_rap_util=>ty_s_hierarchy OPTIONAL
        delete_mode   TYPE string OPTIONAL
        expand_levels TYPE i DEFAULT 1.

  PROTECTED SECTION.

    "! the hierarchy the rows are ordered by - empty node_field: a plain
    "! list
    DATA ms_hierarchy TYPE z2ui5_cl_rap_util=>ty_s_hierarchy.
    "! the nodes in the order of the rows
    DATA mt_tree TYPE z2ui5_cl_rap_util=>ty_t_tree_node.
    "! the keys of the expanded nodes
    DATA mt_expanded TYPE string_table.
    DATA mv_expand_levels TYPE i.
    "! the hierarchy was resolved, the start's levels were expanded
    DATA mv_hierarchy_read TYPE abap_bool.
    DATA mv_tree_started TYPE abap_bool.
    "! the node the delete dialog asks about
    DATA mv_delete_key TYPE string.
    "! what the constructor was given
    DATA ms_hierarchy_preset TYPE z2ui5_cl_rap_util=>ty_s_hierarchy.
    DATA mv_delete_mode_preset TYPE string.

    METHODS load_data REDEFINITION.
    METHODS get_order_by REDEFINITION.
    METHODS render_cell REDEFINITION.
    METHODS render_toolbar_content REDEFINITION.
    METHODS on_event REDEFINITION.
    METHODS has_selection REDEFINITION.

    "! the hierarchy: the constructor's, completed by the annotations
    "! (z2ui5_cl_rap_util=>read_hierarchy), as the extension adjusts it
    METHODS get_hierarchy
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_hierarchy.

    "! what deleting the node key does to its children
    "! (z2ui5_cl_rap_util=>cs_tree_delete) - the hierarchy's delete mode
    METHODS get_delete_mode
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the rows (mr_data) in the order of the tree, with the tree's
    "! columns
    METHODS build_tree_rows.

    "! the tree's columns of the rows after an expand or collapse - the
    "! rows stay where they are
    METHODS refresh_tree_state.

    "! the key of the node of a row of mr_data
    METHODS get_node_key
      IMPORTING
        row           TYPE data
      RETURNING
        VALUE(result) TYPE string.

    "! the row of mr_data of the node key, as a row of the entity
    METHODS get_node_row
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the key of the one selected node - empty (and a message) when not
    "! exactly one is selected
    METHODS get_selected_node
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE string.

    METHODS on_create_child
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the dialog that asks before a node is deleted
    METHODS render_delete_popup
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! delete the node key by its delete mode: the descendants first
    "! (SUBTREE), the children moved to its parent (MOVE_UP), or nothing
    "! when it has children (LEAF) - stops at the first write that fails
    METHODS delete_node
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_result.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_tree IMPLEMENTATION.

  METHOD constructor.
    super->constructor( cds_view_name = cds_view_name
                        title         = title
                        max_rows      = max_rows ).
    mv_floorplan = cs_floorplan-tree.
    ms_hierarchy_preset = hierarchy.
    mv_delete_mode_preset = to_upper( delete_mode ).
    mv_expand_levels = expand_levels.
  ENDMETHOD.


  METHOD get_hierarchy.

    result = z2ui5_cl_rap_util=>read_hierarchy( ms_entity ).
    IF ms_hierarchy_preset-node_field IS NOT INITIAL AND ms_hierarchy_preset-parent_field IS NOT INITIAL.
      result-node_field = to_upper( ms_hierarchy_preset-node_field ).
      result-parent_field = to_upper( ms_hierarchy_preset-parent_field ).
    ENDIF.
    IF ms_hierarchy_preset-order_by IS NOT INITIAL.
      result-order_by = ms_hierarchy_preset-order_by.
    ENDIF.
    IF ms_hierarchy_preset-delete_mode IS NOT INITIAL.
      result-delete_mode = to_upper( ms_hierarchy_preset-delete_mode ).
    ENDIF.
    IF mv_delete_mode_preset IS NOT INITIAL.
      result-delete_mode = mv_delete_mode_preset.
    ENDIF.
    IF mo_ext IS BOUND.
      mo_ext->adjust_hierarchy( EXPORTING floorplan   = mv_floorplan
                                          entity_name = mv_cds_view
                                CHANGING  hierarchy   = result ).
    ENDIF.
    "a field the entity does not have is no hierarchy
    IF NOT line_exists( ms_entity-fields[ name = result-node_field ] )
      OR NOT line_exists( ms_entity-fields[ name = result-parent_field ] ).
      CLEAR: result-node_field, result-parent_field.
    ENDIF.

  ENDMETHOD.


  METHOD get_delete_mode.
    result = ms_hierarchy-delete_mode.
    IF result <> z2ui5_cl_rap_util=>cs_tree_delete-move_up AND result <> z2ui5_cl_rap_util=>cs_tree_delete-leaf.
      result = z2ui5_cl_rap_util=>cs_tree_delete-subtree.
    ENDIF.
  ENDMETHOD.


  METHOD load_data.

    IF mv_hierarchy_read = abap_false.
      ms_hierarchy = get_hierarchy( ).
      mv_hierarchy_read = abap_true.
    ENDIF.
    "the order of the tree - no groups
    IF ms_hierarchy-node_field IS NOT INITIAL.
      CLEAR mv_group_field.
    ENDIF.
    super->load_data( ).
    build_tree_rows( ).

  ENDMETHOD.


  METHOD get_order_by.

    DATA lt_order TYPE string_table.
    DATA lt_used TYPE string_table.

    LOOP AT ms_hierarchy-order_by INTO DATA(ls_sort).
      IF line_exists( ms_entity-fields[ name = ls_sort-field ] ) AND NOT line_exists( lt_used[ table_line = ls_sort-field ] ).
        APPEND |{ ls_sort-field }{ COND #( WHEN ls_sort-descending = abap_true THEN ` DESCENDING` ELSE `` ) }| TO lt_order.
        APPEND ls_sort-field TO lt_used.
      ENDIF.
    ENDLOOP.
    "then the list report's order - without a field named already
    SPLIT super->get_order_by( ) AT `, ` INTO TABLE DATA(lt_super).
    LOOP AT lt_super INTO DATA(lv_part) WHERE table_line IS NOT INITIAL.
      SPLIT lv_part AT ` ` INTO TABLE DATA(lt_words).
      DATA(lv_field) = lt_words[ 1 ].
      IF NOT line_exists( lt_used[ table_line = lv_field ] ).
        APPEND lv_part TO lt_order.
        APPEND lv_field TO lt_used.
      ENDIF.
    ENDLOOP.
    result = concat_lines_of( table = lt_order sep = `, ` ).

  ENDMETHOD.


  METHOD get_node_key.
    FIELD-SYMBOLS <lv_node> TYPE any.
    ASSIGN COMPONENT ms_hierarchy-node_field OF STRUCTURE row TO <lv_node>.
    IF sy-subrc = 0 AND <lv_node> IS NOT INITIAL.
      result = |{ <lv_node> }|.
    ENDIF.
  ENDMETHOD.


  METHOD build_tree_rows.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_new> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_parent> TYPE any.
    DATA lt_nodes TYPE z2ui5_cl_rap_util=>ty_t_tree_node.
    DATA lr_new TYPE REF TO data.
    DATA lv_parent TYPE string.

    CLEAR mt_tree.
    IF ms_hierarchy-node_field IS INITIAL OR mr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lo_string) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_name( `STRING` ) ).
    DATA(lo_bool) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_name( `ABAP_BOOL` ) ).
    add_row_columns( VALUE #( ( name = cs_tree_column-key          type = lo_string )
                              ( name = cs_tree_column-indent       type = lo_string )
                              ( name = cs_tree_column-children     type = lo_bool )
                              ( name = cs_tree_column-expanded     type = lo_bool )
                              ( name = cs_row_column-row_visible   type = lo_bool ) ) ).
    ASSIGN mr_data->* TO <lt_rows>.
    IF <lt_rows> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      CLEAR lv_parent.
      UNASSIGN <lv_parent>.
      ASSIGN COMPONENT ms_hierarchy-parent_field OF STRUCTURE <ls_row> TO <lv_parent>.
      IF <lv_parent> IS ASSIGNED AND <lv_parent> IS NOT INITIAL.
        lv_parent = |{ <lv_parent> }|.
      ENDIF.
      APPEND VALUE #( key    = get_node_key( <ls_row> )
                      parent = lv_parent
                      index  = sy-tabix ) TO lt_nodes.
    ENDLOOP.

    "the start: the first levels expanded
    IF mv_tree_started = abap_false.
      mv_tree_started = abap_true.
      LOOP AT z2ui5_cl_rap_util=>build_tree( lt_nodes ) INTO DATA(ls_start)
        WHERE level < mv_expand_levels AND has_children = abap_true.
        APPEND ls_start-key TO mt_expanded.
      ENDLOOP.
    ENDIF.
    mt_tree = z2ui5_cl_rap_util=>build_tree( it_nodes  = lt_nodes
                                             expanded = mt_expanded ).

    CREATE DATA lr_new LIKE <lt_rows>.
    ASSIGN lr_new->* TO <lt_new>.
    LOOP AT mt_tree INTO DATA(ls_node).
      READ TABLE <lt_rows> INDEX ls_node-index ASSIGNING <ls_row>.
      IF sy-subrc = 0.
        APPEND <ls_row> TO <lt_new>.
      ENDIF.
    ENDLOOP.
    mr_data = lr_new.
    refresh_tree_state( ).

  ENDMETHOD.


  METHOD refresh_tree_state.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_target> TYPE any.

    IF mt_tree IS INITIAL OR mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    "the rows are in the order of the tree - the same order again
    mt_tree = z2ui5_cl_rap_util=>build_tree( it_nodes  = mt_tree
                                             expanded = mt_expanded ).
    ASSIGN mr_data->* TO <lt_rows>.
    LOOP AT mt_tree INTO DATA(ls_node).
      READ TABLE <lt_rows> INDEX sy-tabix ASSIGNING <ls_row>.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      ASSIGN COMPONENT cs_tree_column-key OF STRUCTURE <ls_row> TO <lv_target>.
      IF sy-subrc = 0.
        <lv_target> = ls_node-key.
      ENDIF.
      ASSIGN COMPONENT cs_tree_column-indent OF STRUCTURE <ls_row> TO <lv_target>.
      IF sy-subrc = 0.
        <lv_target> = z2ui5_cl_rap_util=>get_tree_indent( ls_node-level ).
      ENDIF.
      ASSIGN COMPONENT cs_tree_column-children OF STRUCTURE <ls_row> TO <lv_target>.
      IF sy-subrc = 0.
        <lv_target> = ls_node-has_children.
      ENDIF.
      ASSIGN COMPONENT cs_tree_column-expanded OF STRUCTURE <ls_row> TO <lv_target>.
      IF sy-subrc = 0.
        <lv_target> = ls_node-expanded.
      ENDIF.
      ASSIGN COMPONENT cs_row_column-row_visible OF STRUCTURE <ls_row> TO <lv_target>.
      IF sy-subrc = 0.
        <lv_target> = ls_node-visible.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_cell.

    DATA(lt_tree_columns) = get_visible_columns( ).
    IF ms_hierarchy-node_field IS INITIAL OR lt_tree_columns IS INITIAL
      OR lt_tree_columns[ 1 ]-name <> is_col-name.
      super->render_cell( io_cells = io_cells
                          is_col   = is_col
                          client   = client ).
      RETURN.
    ENDIF.

    "the first column: the indent of the level, the expand button
    DATA(lo_tree_cell) = io_cells->ele( `HBox`
        )->a( n = `alignItems`
              v = `Center` ).
    lo_tree_cell->tag( `Label`
        )->a( n = `width`
              v = |\{{ cs_tree_column-indent }\}| ).
    IF client IS BOUND.
      lo_tree_cell->tag( `Button`
          )->a( n = `icon`
                v = `{= ${ZZTREE_CHILDREN} ? ( ${ZZTREE_EXPANDED} ? 'sap-icon://navigation-down-arrow' : 'sap-icon://navigation-right-arrow' ) : '' }`
          )->a( n = `tooltip`
                t = get_text( cs_text-toggle )
          )->a( n = `type`
                v = `Transparent`
          )->a( n = `enabled`
                v = |\{{ cs_tree_column-children }\}|
          )->a( n = `press`
                v = client->_event( val = cs_tree_event-toggle
                                    arg = `${ZZTREE_KEY}` ) ).
    ENDIF.
    super->render_cell( io_cells = lo_tree_cell
                        is_col   = is_col
                        client   = client ).

  ENDMETHOD.


  METHOD render_toolbar_content.

    super->render_toolbar_content( io_toolbar = io_toolbar
                                   client     = client ).
    IF ms_hierarchy-node_field IS INITIAL.
      RETURN.
    ENDIF.

    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://expand-group`
        )->a( n = `tooltip`
              t = get_text( cs_text-expand_all )
        )->a( n = `press`
              v = client->_event( cs_tree_event-expand_all ) ).
    io_toolbar->tag( `Button`
        )->a( n = `icon`
              v = `sap-icon://collapse-group`
        )->a( n = `tooltip`
              t = get_text( cs_text-collapse_all )
        )->a( n = `press`
              v = client->_event( cs_tree_event-collapse_all ) ).
    IF ms_caps-can_create = abap_true.
      io_toolbar->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-create_child )
          )->a( n = `press`
                v = client->_event( cs_tree_event-create_child ) ).
    ENDIF.
    IF ms_caps-can_delete = abap_true.
      io_toolbar->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-delete )
          )->a( n = `press`
                v = client->_event( cs_tree_event-delete ) ).
    ENDIF.

  ENDMETHOD.


  METHOD has_selection.
    result = super->has_selection( ).
    IF result = abap_false AND ms_hierarchy-node_field IS NOT INITIAL.
      result = xsdbool( ms_caps-can_create = abap_true OR ms_caps-can_delete = abap_true ).
    ENDIF.
  ENDMETHOD.


  METHOD on_event.

    DATA lv_key TYPE string.

    IF client->check_on_event( cs_tree_event-toggle ).
      lv_key = client->get_event_arg( ).
      IF line_exists( mt_expanded[ table_line = lv_key ] ).
        DELETE mt_expanded WHERE table_line = lv_key.
      ELSE.
        APPEND lv_key TO mt_expanded.
      ENDIF.
      refresh_tree_state( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-expand_all ).
      CLEAR mt_expanded.
      LOOP AT mt_tree INTO DATA(ls_node) WHERE has_children = abap_true.
        APPEND ls_node-key TO mt_expanded.
      ENDLOOP.
      refresh_tree_state( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-collapse_all ).
      CLEAR mt_expanded.
      refresh_tree_state( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-create_child ).
      on_create_child( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-delete ).
      mv_delete_key = get_selected_node( client ).
      IF mv_delete_key IS NOT INITIAL.
        render_delete_popup( client ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-delete_cancel ).
      CLEAR mv_delete_key.
      client->popup_destroy( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_tree_event-delete_confirm ).
      client->popup_destroy( ).
      lv_key = mv_delete_key.
      CLEAR mv_delete_key.
      IF lv_key IS INITIAL.
        RETURN.
      ENDIF.
      DATA(ls_result) = delete_node( lv_key ).
      IF ls_result-success = abap_true.
        client->message_toast_display( get_text( cs_text-deleted ) ).
      ELSE.
        show_messages( client   = client
                       messages = ls_result-messages
                       details  = ls_result-details
                       fields   = ms_entity-fields ).
      ENDIF.
      load_data( ).
      render_page( client ).
      RETURN.
    ENDIF.

    super->on_event( client ).

  ENDMETHOD.


  METHOD get_node_row.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.

    IF mr_data IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_data->* TO <lt_rows>.
    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      IF get_node_key( <ls_row> ) = key.
        result = to_entity_row( entity_name = mv_cds_view
                                row         = <ls_row> ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_selected_node.

    FIELD-SYMBOLS <lt_selected> TYPE STANDARD TABLE.

    DATA(lr_selected) = get_selected_rows( entity_name = mv_cds_view
                                           data        = mr_data ).
    IF lr_selected IS BOUND.
      ASSIGN lr_selected->* TO <lt_selected>.
    ENDIF.
    IF <lt_selected> IS NOT ASSIGNED OR lines( <lt_selected> ) <> 1.
      client->message_box_display( text = get_text( cs_text-select_one )
                                   type = `warning` ).
      RETURN.
    ENDIF.
    result = get_node_key( <lt_selected>[ 1 ] ).

  ENDMETHOD.


  METHOD on_create_child.

    FIELD-SYMBOLS <ls_child> TYPE any.
    FIELD-SYMBOLS <ls_parent> TYPE any.
    FIELD-SYMBOLS <lv_parent> TYPE any.
    FIELD-SYMBOLS <lv_node> TYPE any.
    DATA lr_child TYPE REF TO data.

    IF ms_caps-can_create = abap_false.
      client->message_box_display( text = get_text( cs_text-read_only )
                                   type = `error` ).
      RETURN.
    ENDIF.
    DATA(lv_key) = get_selected_node( client ).
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lr_parent) = get_node_row( lv_key ).
    IF lr_parent IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_parent->* TO <ls_parent>.

    TRY.
        CREATE DATA lr_child TYPE (mv_cds_view).
        ASSIGN lr_child->* TO <ls_child>.
        "the new node's parent is the selected node
        ASSIGN COMPONENT ms_hierarchy-parent_field OF STRUCTURE <ls_child> TO <lv_parent>.
        ASSIGN COMPONENT ms_hierarchy-node_field OF STRUCTURE <ls_parent> TO <lv_node>.
        IF <lv_parent> IS ASSIGNED AND <lv_node> IS ASSIGNED.
          <lv_parent> = <lv_node>.
        ENDIF.
        DATA(lo_op) = NEW z2ui5_cl_rap_object_page(
          val       = <ls_child>
          title     = |{ get_text( cs_text-create_child ) } { mv_title }|
          editable  = abap_true
          is_create = abap_true ).
        lo_op->set_extension( mo_ext ).
        client->nav_app_call( lo_op ).
      CATCH cx_root.
        client->message_box_display( text = get_text( cs_text-read_only )
                                     type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD render_delete_popup.

    DATA(lv_delete_mode) = get_delete_mode( mv_delete_key ).
    DATA(lv_delete_text) = |{ get_text( cs_text-delete ) }: { mv_delete_key }|.
    IF lv_delete_mode = z2ui5_cl_rap_util=>cs_tree_delete-subtree
      AND z2ui5_cl_rap_util=>get_tree_children( it_tree = mt_tree
                                                key     = mv_delete_key ) IS NOT INITIAL.
      lv_delete_text = |{ lv_delete_text } - { get_text( cs_text-has_children ) }|.
    ENDIF.

    DATA(lo_delete_popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(lo_delete_dialog) = lo_delete_popup->ele( n  = `FragmentDefinition`
                                                    ns = `core`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:core`
              v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`
                  t = get_text( cs_text-delete )
            )->a( n = `type`
                  v = `Message`
            )->a( n = `state`
                  v = `Warning` ).

    lo_delete_dialog->ele( `content`
        )->tag( `Text`
            )->a( n = `text`
                  t = lv_delete_text ).

    lo_delete_dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-delete )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `press`
                  v = client->_event( cs_tree_event-delete_confirm )
        )->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-cancel )
            )->a( n = `press`
                  v = client->_event( cs_tree_event-delete_cancel ) ).

    client->popup_display( lo_delete_popup->stringify( ) ).

  ENDMETHOD.


  METHOD delete_node.

    FIELD-SYMBOLS <ls_node> TYPE any.
    FIELD-SYMBOLS <ls_child> TYPE any.
    FIELD-SYMBOLS <lv_parent> TYPE any.
    FIELD-SYMBOLS <lv_new_parent> TYPE any.
    DATA lr_original TYPE REF TO data.

    IF ms_caps-can_delete = abap_false.
      result-messages = VALUE #( ( get_text( cs_text-read_only ) ) ).
      RETURN.
    ENDIF.
    DATA(lr_node) = get_node_row( key ).
    IF lr_node IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_node->* TO <ls_node>.
    DATA(lt_children) = z2ui5_cl_rap_util=>get_tree_children( it_tree = mt_tree
                                                              key     = key ).

    CASE get_delete_mode( key ).
      WHEN z2ui5_cl_rap_util=>cs_tree_delete-leaf.
        IF lt_children IS NOT INITIAL.
          result-messages = VALUE #( ( get_text( cs_text-has_children ) ) ).
          RETURN.
        ENDIF.

      WHEN z2ui5_cl_rap_util=>cs_tree_delete-move_up.
        "the children get the node's parent
        ASSIGN COMPONENT ms_hierarchy-parent_field OF STRUCTURE <ls_node> TO <lv_new_parent>.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        LOOP AT lt_children INTO DATA(lv_child).
          DATA(lr_child) = get_node_row( lv_child ).
          IF lr_child IS NOT BOUND.
            CONTINUE.
          ENDIF.
          ASSIGN lr_child->* TO <ls_child>.
          CREATE DATA lr_original LIKE <ls_child>.
          ASSIGN lr_original->* TO FIELD-SYMBOL(<ls_original>).
          <ls_original> = <ls_child>.
          ASSIGN COMPONENT ms_hierarchy-parent_field OF STRUCTURE <ls_child> TO <lv_parent>.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          <lv_parent> = <lv_new_parent>.
          result = write_row( entity_name = mv_cds_view
                              operation   = `UPDATE`
                              row         = <ls_child>
                              original    = <ls_original> ).
          IF result-success = abap_false.
            RETURN.
          ENDIF.
        ENDLOOP.

      WHEN OTHERS.
        "the subtree, the deepest nodes first
        LOOP AT z2ui5_cl_rap_util=>get_tree_descendants( it_tree = mt_tree
                                                         key     = key ) INTO DATA(lv_descendant).
          DATA(lr_descendant) = get_node_row( lv_descendant ).
          IF lr_descendant IS NOT BOUND.
            CONTINUE.
          ENDIF.
          ASSIGN lr_descendant->* TO <ls_child>.
          result = write_row( entity_name = mv_cds_view
                              operation   = `DELETE`
                              row         = <ls_child> ).
          IF result-success = abap_false.
            RETURN.
          ENDIF.
        ENDLOOP.
    ENDCASE.

    result = write_row( entity_name = mv_cds_view
                        operation   = `DELETE`
                        row         = <ls_node> ).

  ENDMETHOD.

ENDCLASS.
