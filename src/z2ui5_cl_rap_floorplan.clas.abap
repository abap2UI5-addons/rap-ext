"! What every floorplan of the addon shares: reading rows of a CDS entity,
"! the filter and search syntax, the control for a field, calling and
"! applying a value help, writing through RAP (or a database table), the
"! texts and the extension points (z2ui5_if_rap_ext).
"!
"! Everything here is PROTECTED and therefore part of the escape hatch: a
"! subclass of any floorplan can call or redefine it. The floorplans keep
"! their own steps (render_page, load_data, ...) - this class only holds
"! what used to be copied between them.
CLASS z2ui5_cl_rap_floorplan DEFINITION
  PUBLIC
  CREATE PROTECTED.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_floorplan,
        list_report   TYPE string VALUE `LIST_REPORT`,
        worklist      TYPE string VALUE `WORKLIST`,
        object_page   TYPE string VALUE `OBJECT_PAGE`,
        value_help    TYPE string VALUE `VALUE_HELP`,
        action_dialog TYPE string VALUE `ACTION_DIALOG`,
        overview_page TYPE string VALUE `OVERVIEW_PAGE`,
      END OF cs_floorplan.

    " The keys of get_text( ) - z2ui5_if_rap_ext~get_text translates them
    CONSTANTS:
      BEGIN OF cs_text,
        create         TYPE string VALUE `CREATE`,
        edit           TYPE string VALUE `EDIT`,
        delete         TYPE string VALUE `DELETE`,
        save           TYPE string VALUE `SAVE`,
        cancel         TYPE string VALUE `CANCEL`,
        ok             TYPE string VALUE `OK`,
        go             TYPE string VALUE `GO`,
        refresh        TYPE string VALUE `REFRESH`,
        search         TYPE string VALUE `SEARCH`,
        yes            TYPE string VALUE `YES`,
        no             TYPE string VALUE `NO`,
        all            TYPE string VALUE `ALL`,
        general        TYPE string VALUE `GENERAL`,
        items          TYPE string VALUE `ITEMS`,
        saved          TYPE string VALUE `SAVED`,
        deleted        TYPE string VALUE `DELETED`,
        refreshed      TYPE string VALUE `REFRESHED`,
        action_done    TYPE string VALUE `ACTION_DONE`,
        required       TYPE string VALUE `REQUIRED`,
        read_only      TYPE string VALUE `READ_ONLY`,
        load_error     TYPE string VALUE `LOAD_ERROR`,
        no_selection   TYPE string VALUE `NO_SELECTION`,
        filter_hint    TYPE string VALUE `FILTER_HINT`,
        create_title   TYPE string VALUE `CREATE_TITLE`,
        sort           TYPE string VALUE `SORT`,
        more           TYPE string VALUE `MORE`,
        "added 2026-10
        no_authority   TYPE string VALUE `NO_AUTHORITY`,
        locked         TYPE string VALUE `LOCKED`,
        changed        TYPE string VALUE `CHANGED`,
        discard_draft  TYPE string VALUE `DISCARD_DRAFT`,
        no_launchpad   TYPE string VALUE `NO_LAUNCHPAD`,
        not_found      TYPE string VALUE `NOT_FOUND`,
        export         TYPE string VALUE `EXPORT`,
        copy_link      TYPE string VALUE `COPY_LINK`,
        link_copied    TYPE string VALUE `LINK_COPIED`,
        standard       TYPE string VALUE `STANDARD`,
        save_view      TYPE string VALUE `SAVE_VIEW`,
        delete_view    TYPE string VALUE `DELETE_VIEW`,
        view_name      TYPE string VALUE `VIEW_NAME`,
        as_default     TYPE string VALUE `AS_DEFAULT`,
        view_saved     TYPE string VALUE `VIEW_SAVED`,
        columns        TYPE string VALUE `COLUMNS`,
        "added 2026-10, third round (RAP behaviour and draft)
        resume_draft   TYPE string VALUE `RESUME_DRAFT`,
        keep_draft     TYPE string VALUE `KEEP_DRAFT`,
        leave_draft    TYPE string VALUE `LEAVE_DRAFT`,
        own_draft      TYPE string VALUE `OWN_DRAFT`,
        "&1 is the user
        locked_by      TYPE string VALUE `LOCKED_BY`,
        editing_status TYPE string VALUE `EDITING_STATUS`,
        own_drafts     TYPE string VALUE `OWN_DRAFTS`,
        locked_other   TYPE string VALUE `LOCKED_OTHER`,
        unchanged      TYPE string VALUE `UNCHANGED`,
        not_allowed    TYPE string VALUE `NOT_ALLOWED`,
        field_read_only TYPE string VALUE `FIELD_READ_ONLY`,
      END OF cs_text.

    " Where z2ui5_if_rap_ext~extend_view may add controls
    CONSTANTS:
      BEGIN OF cs_spot,
        "the table toolbar of the list report and the worklist
        toolbar        TYPE string VALUE `TOOLBAR`,
        "the header actions of the object page
        header_actions TYPE string VALUE `HEADER_ACTIONS`,
        "the sections of the object page - add ObjectPageSections
        sections       TYPE string VALUE `SECTIONS`,
        "the content of the action dialog, below the form
        dialog_content TYPE string VALUE `DIALOG_CONTENT`,
        "the grid of the overview page - add cards
        cards          TYPE string VALUE `CARDS`,
      END OF cs_spot.

    "! The selection column added to rows a table or dialog lets the user
    "! select - the name the core's own select popup uses
    CONSTANTS cv_select_column TYPE string VALUE `ZZSELKZ`.

    "! the event of an input with a value help while the user types - the
    "! suggestions (load_suggestions); arguments: the field, the text
    CONSTANTS cv_event_suggest TYPE string VALUE `SUGGEST`.

    TYPES:
      BEGIN OF ty_s_capabilities,
        "a RAP business object (a BDEF with this entity as root)
        is_rap_bo  TYPE abap_bool,
        "a transparent database table - written with ABAP SQL, and only
        "where z2ui5_if_rap_ext~adjust_capabilities allows it
        is_table   TYPE abap_bool,
        can_create TYPE abap_bool,
        can_update TYPE abap_bool,
        can_delete TYPE abap_bool,
      END OF ty_s_capabilities.


    TYPES:
      BEGIN OF ty_s_name_value,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_name_value.

    TYPES ty_t_name_value TYPE STANDARD TABLE OF ty_s_name_value WITH DEFAULT KEY.

    TYPES:
      "! one message of a write, as RAP reported it
      BEGIN OF ty_s_message,
        text   TYPE string,
        "error, warning, success or information
        type   TYPE string,
        "the fields the message is about (%element)
        fields TYPE string_table,
      END OF ty_s_message.

    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

    TYPES:
      "! a button of the actions (get_action_entries): one action, or an
      "! action group - a menu of its actions (added 2026-10, third round)
      BEGIN OF ty_s_action_entry,
        position TYPE i,
        action   TYPE z2ui5_cl_rap_util=>ty_s_action,
        group    TYPE z2ui5_cl_rap_util=>ty_s_action_group,
        items    TYPE z2ui5_cl_rap_util=>ty_t_action,
      END OF ty_s_action_entry.

    TYPES ty_t_action_entry TYPE STANDARD TABLE OF ty_s_action_entry WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_result,
        success  TYPE abap_bool,
        messages TYPE string_table,
        "the keys of a created instance, as RAP assigned them (MAPPED)
        keys     TYPE ty_t_name_value,
        "added 2026-10: the messages with their severity and fields
        details  TYPE ty_t_message,
      END OF ty_s_result.

    TYPES:
      "! Where a record sits in a RAP business object. Empty for the root
      "! entity, which is its own behavior definition; set for a child, which
      "! is written through the BDEF of its root - and, for a create by
      "! association, with the parent the new child is created under
      BEGIN OF ty_s_rap_context,
        "the behavior definition - the name of its root entity
        bdef        TYPE string,
        "the keys of the root instance: a draft is edited and activated there
        root_keys   TYPE ty_t_name_value,
        "a create by association: the parent entity, its keys, the composition
        parent      TYPE string,
        parent_keys TYPE ty_t_name_value,
        association TYPE string,
        "the child's fields that point at the parent - the composition
        "fills them, so a create does not send them
        parent_fields TYPE string_table,
      END OF ty_s_rap_context.

    "! what GET PERMISSIONS answers for an entity - global, static and per
    "! instance (z2ui5_cl_rap_util=>ty_s_permissions; added 2026-10, third
    "! round)
    TYPES ty_s_permissions TYPE z2ui5_cl_rap_util=>ty_s_permissions.
    "! the permissions of one record, global and instance combined
    TYPES ty_s_perm_set TYPE z2ui5_cl_rap_util=>ty_s_perm_set.

    "! The dropdown entries of the fields that have a small value help
    "! (sizeCategory #XS) - one component per field, each a table of the
    "! value help entity. PUBLIC and a REF TO data because that is what the
    "! abap2UI5 model resolves a binding into and carries through the draft.
    DATA mr_value_lists TYPE REF TO data.

    "! The suggestions of the inputs with a value help - one component per
    "! field, each a table of the value help entity, filled while the user
    "! types (load_suggestions). PUBLIC and a REF TO data for the same
    "! reason as mr_value_lists.
    DATA mr_suggestions TYPE REF TO data.

    "! Hand the floorplan an implementation of the extension points
    METHODS set_extension
      IMPORTING
        ext TYPE REF TO z2ui5_if_rap_ext.

    "! What can be written to an entity - asked from the BDEF derived types
    "! (a BDEF without `delete` has no delete type). A transparent table is
    "! recognized (is_table) but answered read-only: up to 2026-10 every
    "! table a floorplan was opened on could be changed and deleted by
    "! anyone who reached the app. The writes of a table are switched on per
    "! entity by z2ui5_if_rap_ext~adjust_capabilities - what the floorplans
    "! ask is get_entity_capabilities( ), which applies it
    CLASS-METHODS get_capabilities
      IMPORTING
        entity_name   TYPE clike
        "a child entity: the BDEF of its root and, for its create, the
        "parent and composition - added 2026-10
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_capabilities.

    "! the built-in text for a key of cs_text, in the logon language - what
    "! get_text( ) answers before the extension changes it
    CLASS-METHODS get_default_text
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! RAP is there (IF_ABAP_BEHV exists) - answered from RTTI, so asking
    "! never loads z2ui5_cl_rap_eml
    CLASS-METHODS eml_available
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! The query provider interfaces are there (IF_RAP_QUERY_PROVIDER
    "! exists) - answered from RTTI, so asking never loads
    "! z2ui5_cl_rap_query (added 2026-10, third round)
    CLASS-METHODS query_available
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.

    DATA mo_ext TYPE REF TO z2ui5_if_rap_ext.
    "! one of cs_floorplan - set by the constructor of each floorplan
    DATA mv_floorplan TYPE string.
    "! the field a called value help fills on return
    DATA mv_vh_target TYPE string.

    "! the text element of each value help entity with suggestions - the
    "! additional text of a suggestion (prepare_value_lists)
    DATA mt_suggest_text TYPE ty_t_name_value.

    "! the name select_rows( ) gives the host structure - a dynamic WHERE
    "! compares with its components as @&lt;LS_HOST&gt;-name
    CONSTANTS cv_host TYPE string VALUE `<LS_HOST>`.

    "! what this floorplan lets the user write to entity_name: the
    "! capabilities of the entity, as the extension adjusts them
    "! (z2ui5_if_rap_ext~adjust_capabilities). Every write and action goes
    "! through it, not only the buttons - an event a browser sends without
    "! the button is refused the same way
    METHODS get_entity_capabilities
      IMPORTING
        entity_name   TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_capabilities.

    "! the WHERE condition that compares every field of names with the
    "! component of the same name of the host structure (select_rows,
    "! parameter host) - typed host variables instead of literals, so a RAW
    "! key (a UUID) or a date compares with a value of its own type
    METHODS build_key_condition
      IMPORTING
        names         TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! a structure of the entity with the fields of values set - the host
    "! structure of a key condition (build_key_condition). A value is the
    "! text form a row, an event argument or a URL carries: a date as
    "! 2024-01-15 or 20240115, a RAW as its hex digits
    METHODS create_host
      IMPORTING
        entity_name   TYPE string
        values        TYPE ty_t_name_value
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the text for a key of cs_text - the extension can change it
    METHODS get_text
      IMPORTING
        key           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! let the extension adjust the metadata
    METHODS adjust_entity
      CHANGING
        cs_entity TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

    "! let the extension add controls at one of the cs_spot places
    METHODS render_extension
      IMPORTING
        spot         TYPE string
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        client       TYPE REF TO z2ui5_if_client.

    "! let the extension take an event over - abap_true when it did
    METHODS ext_on_event
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! SELECT * FROM entity_name WHERE where UP TO max_rows into a table of
    "! the entity - with_selection adds the column cv_select_column. Since
    "! 2026-10 (third round) a custom entity is read through its query
    "! provider (query_rows), and a virtual element is left out of the
    "! SELECT, the WHERE and the ORDER BY and calculated afterwards
    "! (calculate_virtual_elements). A failed read is unbound, its reason
    "! in mv_read_error
    METHODS select_rows
      IMPORTING
        entity_name    TYPE string
        where          TYPE string OPTIONAL
        max_rows       TYPE i DEFAULT 500
        with_selection TYPE abap_bool DEFAULT abap_false
        "an ABAP SQL ORDER BY list, e.g. `TRAVELID DESCENDING, STATUS`
        order_by       TYPE string OPTIONAL
        "a structure where compares with as @<LS_HOST>-name (cv_host,
        "build_key_condition) - added 2026-10
        host           TYPE REF TO data OPTIONAL
      RETURNING
        VALUE(result)  TYPE REF TO data.

    "! where, as the extension adjusts it (z2ui5_if_rap_ext~adjust_where) -
    "! every read of rows goes through it, aggregates included
    METHODS get_ext_where
      IMPORTING
        entity_name   TYPE string
        where         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! the number of rows of entity_name that match where
    METHODS count_rows
      IMPORTING
        entity_name   TYPE string
        where         TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE i.

    "! the WHERE condition for the user's filter text on one field - the
    "! syntax is z2ui5_cl_rap_util=>build_filter_condition's
    METHODS build_filter_condition
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the WHERE condition of a free-text search over the searchable text
    "! fields (@Search.defaultSearchElement, else every visible text field)
    METHODS build_search_condition
      IMPORTING
        it_fields     TYPE z2ui5_cl_rap_util=>ty_t_field_info
        search        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the expression binding that maps a criticality field (0-3) to a
    "! ValueState - for an ObjectStatus in a table cell
    METHODS criticality_expression
      IMPORTING
        crit_field    TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! criticality 1/2/3 as the ValueState Error/Warning/Success
    METHODS criticality_state
      IMPORTING
        value         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! fill mr_value_lists for every field of it_fields with a dropdown
    "! value help, and prepare mr_suggestions for every field with another
    "! value help - run it before rendering the controls of those fields
    METHODS prepare_value_lists
      IMPORTING
        it_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the suggestions for what the user typed into the input of a field
    "! with a value help (cv_event_suggest): the rows of the value help
    "! entity whose element starts with it or whose texts contain it
    METHODS load_suggestions
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        it_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the input control for one field, bound to value (a component of a
    "! public attribute): CheckBox, DatePicker, TimePicker, TextArea,
    "! ComboBox (dropdown value help), Input with value help, Input
    METHODS render_field_input
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        is_field     TYPE z2ui5_cl_rap_util=>ty_s_field_info
        client       TYPE REF TO z2ui5_if_client
        value        TYPE data
        editable     TYPE abap_bool DEFAULT abap_true
        vh_event     TYPE string OPTIONAL
        "a sap.ui.core.ValueState (Error, Warning) and its text - a message
        "of the last save about this field (added 2026-10)
        value_state      TYPE string OPTIONAL
        value_state_text TYPE string OPTIONAL.

    "! call the value help of is_field; source holds the values for the
    "! additional bindings with usage FILTER (the structure being edited)
    METHODS open_value_help
      IMPORTING
        client       TYPE REF TO z2ui5_if_client
        is_field     TYPE z2ui5_cl_rap_util=>ty_s_field_info
        source       TYPE data OPTIONAL
        multi_select TYPE abap_bool DEFAULT abap_false.

    "! the value help this floorplan called, when the roundtrip is its
    "! return and the user confirmed - unbound otherwise
    METHODS get_value_help_result
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_rap_value_help.

    "! on the return from open_value_help: write the selected value (and
    "! the additional bindings with usage RESULT) into target
    METHODS apply_value_help
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
        it_fields     TYPE z2ui5_cl_rap_util=>ty_t_field_info
      CHANGING
        target        TYPE data
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the row of data (a table) whose key fields equal the event arguments
    "! arg_offset + 1 ... - how a row press identifies its row
    METHODS find_row_by_event_keys
      IMPORTING
        data          TYPE REF TO data
        key_fields    TYPE string_table
        client        TYPE REF TO z2ui5_if_client
        arg_offset    TYPE i DEFAULT 0
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the row of data (a table) whose key fields equal key_values
    METHODS find_row_by_keys
      IMPORTING
        data          TYPE REF TO data
        key_fields    TYPE string_table
        key_values    TYPE string_table
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! an empty table of the entity - with_selection adds the column
    "! cv_select_column, as select_rows( ) does
    METHODS create_entity_table
      IMPORTING
        entity_name    TYPE string
        with_selection TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)  TYPE REF TO data.

    "! navigate in the Fiori launchpad to semantic_object-action with params
    "! (cross-app navigation) - outside the launchpad the user is told so
    METHODS navigate_to_intent
      IMPORTING
        client          TYPE REF TO z2ui5_if_client
        semantic_object TYPE string
        action          TYPE string
        params          TYPE ty_t_name_value OPTIONAL.

    "! the first record of target the association of entity_name leads to
    "! from row - its ON condition's fields filled from row; unbound when
    "! there is none or the condition is not known
    METHODS read_association_target
      IMPORTING
        is_entity     TYPE z2ui5_cl_rap_util=>ty_s_entity_info
        association   TYPE string
        row           TYPE data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! a copy of row typed as the entity - drops the selection column
    METHODS to_entity_row
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the rows of data (a table with the selection column) the user
    "! selected, as a table of the entity
    METHODS get_selected_rows
      IMPORTING
        entity_name   TYPE string
        data          TYPE REF TO data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! write one row: operation is CREATE, UPDATE or DELETE. Through RAP when
    "! the entity is a business object, with ABAP SQL when it is a table
    "! whose writes the extension allowed (get_entity_capabilities) - an
    "! operation the entity does not allow is refused here, whoever asks
    METHODS write_row
      IMPORTING
        entity_name   TYPE string
        operation     TYPE string
        row           TYPE data
        original      TYPE data OPTIONAL
        "a child entity of a business object - added 2026-10
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! run a RAP action on rows (a table of the entity) - a static action
    "! (is_static_action) runs without rows. The keys of what a factory
    "! action created (MAPPED) are result-keys
    METHODS run_action
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
        rows          TYPE REF TO data
        param         TYPE REF TO data OPTIONAL
        context       TYPE ty_s_rap_context OPTIONAL
        "ISOLATED: one request per row (ty_s_action-invocation_grouping) -
        "added 2026-10, third round
        invocation_grouping TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the action is static - it needs no row: its derived type carries no
    "! key of an instance (z2ui5_cl_rap_util=>is_static_action_line)
    METHODS is_static_action
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! an operation hidden by @UI.createHidden / .updateHidden /
    "! .deleteHidden (ty_s_entity_info-create_hidden, ...): TRUE hides it,
    "! a field hides it when the field of row is true - without a row a
    "! field hides nothing
    METHODS is_hidden_by_annotation
      IMPORTING
        value         TYPE string
        row           TYPE data OPTIONAL
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the sap.m.ButtonType of an action by its criticality - a field's
    "! value is read from row, without a row such a button is Default
    METHODS get_action_button_type
      IMPORTING
        is_action     TYPE z2ui5_cl_rap_util=>ty_s_action
        row           TYPE data OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! the buttons of it_actions in their order: by position, an action
    "! alone or an action group (it_groups) with its actions - a group
    "! without one of them is left out. What render_action_buttons of the
    "! list report and the object page draw
    METHODS get_action_entries
      IMPORTING
        it_actions    TYPE z2ui5_cl_rap_util=>ty_t_action
        it_groups     TYPE z2ui5_cl_rap_util=>ty_t_action_group OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_action_entry.

    "! the business object bdef (its root entity) has a draft
    METHODS is_draft_enabled
      IMPORTING
        bdef          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! a draft action on the root instance of root_keys, committed: EDIT
    "! (a draft appears, an existing one is kept), ACTIVATE, DISCARD -
    "! is_draft addresses the draft instance (Activate, Discard)
    METHODS run_draft_action
      IMPORTING
        bdef          TYPE string
        action        TYPE string
        root_keys     TYPE ty_t_name_value
        is_draft      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! write the changes of row (against original) into its draft,
    "! committed - the draft keeps them between roundtrips until it is
    "! activated or discarded. Checked like write_row, the extension's
    "! before_save is called with operation UPDATE
    METHODS write_draft
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
        original      TYPE data
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the parameter structure of a RAP action, unbound when it has none
    METHODS create_action_parameter
      IMPORTING
        entity_name   TYPE string
        action        TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! a message box with every message
    METHODS show_messages
      IMPORTING
        client   TYPE REF TO z2ui5_if_client
        messages TYPE string_table
        type     TYPE string DEFAULT `error`.

    "! write one row of a database table with ABAP SQL: the authorization
    "! S_TABU_NAM (activity 02) for the table, a lock (ENQUEUE_E_TABLE) on
    "! the row's key, and for UPDATE and DELETE the check that the row is
    "! still what the user saw (original) - a change of somebody else in
    "! between is reported instead of overwritten
    METHODS write_table_row
      IMPORTING
        entity_name   TYPE string
        operation     TYPE string
        row           TYPE data
        original      TYPE data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! the rows aggregate_rows reads at most - a custom entity's aggregates
    "! are computed from its rows (added 2026-10, third round)
    CONSTANTS cv_aggregate_max TYPE i VALUE 5000.

    "! why the last read failed - the text of its exception, empty after a
    "! read that worked (select_rows, count_rows; added 2026-10, third
    "! round)
    DATA mv_read_error TYPE string.

    "! How the rows of entity_name are read: through its query provider (a
    "! custom entity) or by ABAP SQL, and which of its elements are virtual
    "! - from the annotations (z2ui5_cl_rap_util=>get_read_info). A
    "! subclass can name a provider or a calculation the annotations do not
    "! show (added 2026-10, third round)
    METHODS get_read_info
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_read_info.

    "! Read a custom entity through its query provider (z2ui5_cl_rap_query):
    "! where becomes the filter (its search part the search expression,
    "! the host variables of host their values), order_by the sort order,
    "! max_rows the page. data (a table, bound) is filled with the rows,
    "! count_requested asks for count - what select_rows and count_rows
    "! call for such an entity (added 2026-10, third round)
    METHODS query_rows
      IMPORTING
        entity_name     TYPE string
        query_class     TYPE string
        where           TYPE string OPTIONAL
        host            TYPE REF TO data OPTIONAL
        max_rows        TYPE i DEFAULT 500
        order_by        TYPE string OPTIONAL
        data            TYPE REF TO data OPTIONAL
        count_requested TYPE abap_bool DEFAULT abap_false
      EXPORTING
        count           TYPE i
      RAISING
        cx_static_check.

    "! Fill the virtual elements of data (a table of the entity) by their
    "! classes: IF_SADL_EXIT_CALC_ELEMENT_READ~GET_CALCULATION_INFO and
    "! ~CALCULATE, called dynamically, once per class for all of its
    "! elements. A class that fails leaves its elements empty (added
    "! 2026-10, third round)
    METHODS calculate_virtual_elements
      IMPORTING
        entity_name      TYPE string
        virtual_elements TYPE z2ui5_cl_rap_util=>ty_t_virtual_element
        data             TYPE REF TO data.

    "! order_by without the virtual elements, which have no column - one
    "! with @ObjectModel.sort.transformedBy is replaced by the elements its
    "! class names (IF_SADL_EXIT_SORT_TRANSFORM~MAP_ELEMENT, called
    "! dynamically), every other one is dropped (added 2026-10, third round)
    METHODS adjust_virtual_order_by
      IMPORTING
        entity_name      TYPE string
        order_by         TYPE string
        virtual_elements TYPE z2ui5_cl_rap_util=>ty_t_virtual_element
      RETURNING
        VALUE(result)    TYPE string.

    "! The rows of entity_name that match where, grouped by group_by (none:
    "! one group) with method (SUM AVG MIN MAX COUNT) over measure - read
    "! with select_rows (at most cv_aggregate_max rows) and aggregated in
    "! ABAP. What the worklist's tabs and the overview's KPI and chart cards
    "! use for a custom entity, which ABAP SQL cannot aggregate (added
    "! 2026-10, third round)
    METHODS aggregate_rows
      IMPORTING
        entity_name   TYPE string
        where         TYPE string OPTIONAL
        group_by      TYPE string OPTIONAL
        measure       TYPE string OPTIONAL
        method        TYPE string DEFAULT `SUM`
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_aggregate.

    "! the message of a read that failed: the load error text, the entity
    "! and why (mv_read_error) - added 2026-10, third round
    METHODS get_load_error
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! GET PERMISSIONS of entity_name (z2ui5_cl_rap_eml=>get_permissions):
    "! the global and static permissions, and those of the instances of rows
    "! (a table of the entity). Not answered for what is no RAP business
    "! object and where the statement's class did not activate - then the
    "! BDEF derived types alone decide, as before. A subclass can answer it
    "! itself (added 2026-10, third round)
    METHODS get_permissions
      IMPORTING
        entity_name   TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
        rows          TYPE REF TO data OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_permissions.

    "! the permissions of the one record row - the global ones combined
    "! with the instance's (added 2026-10, third round)
    METHODS get_row_permissions
      IMPORTING
        entity_name   TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
        row           TYPE data
      RETURNING
        VALUE(result) TYPE ty_s_perm_set.

    "! the key fields of entity_name with their values in row
    METHODS get_keys_of_row
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the drafts of the instances of rows (a table of the entity), read
    "! back with READ ENTITIES (z2ui5_cl_rap_eml=>read_instances): a table
    "! of the READ RESULT type with a line per draft found - unbound when
    "! the read could not be made (added 2026-10, third round)
    METHODS read_drafts
      IMPORTING
        entity_name   TYPE string
        context       TYPE ty_s_rap_context OPTIONAL
        rows          TYPE REF TO data
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the field of entity_name the optimistic check before an update
    "! compares - z2ui5_cl_rap_util=>get_etag_field. Redefine it to name
    "! the etag master field of the BDEF, which is not read (added 2026-10,
    "! third round)
    METHODS get_etag_field
      IMPORTING
        entity_name   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! the record row (what the user saw) is still the stored one: its etag
    "! field (get_etag_field) has the value it had - abap_true when there
    "! is no such field or the record is no longer there (added 2026-10,
    "! third round)
    METHODS check_etag
      IMPORTING
        entity_name   TYPE string
        row           TYPE data
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! align ABAP and JSON model representations (dates, times, padding)
    METHODS normalize_key_value
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

    "! why an update or delete of row (original: as the user saw it) is
    "! refused - the record's permissions, a changed read-only field, a
    "! changed etag; empty when it may run
    METHODS check_rap_write
      IMPORTING
        entity_name   TYPE string
        operation     TYPE string
        row           TYPE data
        original      TYPE data
        context       TYPE ty_s_rap_context
      RETURNING
        VALUE(result) TYPE string_table.

    "! the value state of the control render_field_input just added - the
    "! container's last child
    METHODS add_value_state
      IMPORTING
        io_container     TYPE REF TO z2ui5_cl_ui5_view_builder
        value_state      TYPE string
        value_state_text TYPE string.

    CLASS-METHODS try_create_data
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the lock argument of ENQUEUE_E_TABLE for one row: the key fields in
    "! their internal form, one after the other - empty (the whole table)
    "! when a key field is not character-like or the key is too long
    METHODS get_table_varkey
      IMPORTING
        row           TYPE data
        key_fields    TYPE ddfields
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.



CLASS z2ui5_cl_rap_floorplan IMPLEMENTATION.

  METHOD set_extension.
    mo_ext = ext.
  ENDMETHOD.


  METHOD eml_available.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = `IF_ABAP_BEHV`
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD query_available.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = `IF_RAP_QUERY_PROVIDER`
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD get_capabilities.

    DATA(lv_entity) = to_upper( entity_name ).
    IF lv_entity IS INITIAL.
      RETURN.
    ENDIF.

    IF eml_available( ) = abap_true.
      DATA(lv_bdef) = COND string( WHEN context-bdef IS NOT INITIAL THEN to_upper( context-bdef ) ELSE lv_entity ).
      DATA(lv_base) = |\\BDEF={ lv_bdef }\\ENTITY={ lv_entity }|.
      result-can_create = try_create_data( lv_base && `\TYPE=CREATE` ).
      "a child is created under its parent - by association, not alone
      IF context-association IS NOT INITIAL.
        "\ASSOC= is the documented form, \ASSOCIATION= the one used up to
        "2026-10 - whichever the system knows (z2ui5_cl_rap_eml)
        DATA(lv_parent_base) = |\\BDEF={ lv_bdef }\\ENTITY={ to_upper( context-parent ) }|.
        result-can_create = xsdbool(
          try_create_data( |{ lv_parent_base }\\ASSOC={ to_upper( context-association ) }\\TYPE=CREATE| ) = abap_true
          OR try_create_data( |{ lv_parent_base }\\ASSOCIATION={ to_upper( context-association ) }\\TYPE=CREATE| ) = abap_true ).
      ENDIF.
      result-can_update = try_create_data( lv_base && `\TYPE=UPDATE` ).
      result-can_delete = try_create_data( lv_base && `\TYPE=DELETE` ).
      result-is_rap_bo = xsdbool( result-can_create = abap_true
                               OR result-can_update = abap_true
                               OR result-can_delete = abap_true
                               OR try_create_data( lv_base && `\TYPE=READ_R` ) = abap_true ).
      IF result-is_rap_bo = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    "a transparent table - what the object page wrote before RAP support.
    "A CDS view is never writable with ABAP SQL, so it ends here read-only,
    "and so does a table until get_entity_capabilities( ) is told otherwise
    TRY.
        DATA lv_tabclass TYPE c LENGTH 8.
        SELECT SINGLE tabclass FROM dd02l
          WHERE tabname  = @lv_entity
            AND as4local = 'A'
          INTO @lv_tabclass.
        "read-only until the extension allows the writes
        result-is_table = xsdbool( sy-subrc = 0 AND lv_tabclass = `TRANSP` ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD add_value_state.
    IF value_state IS INITIAL.
      RETURN.
    ENDIF.
    io_container->a( n = `valueState`
                     v = value_state
        )->a( n = `valueStateText`
              t = value_state_text ).
  ENDMETHOD.


  METHOD try_create_data.
    DATA lr_data TYPE REF TO data.
    TRY.
        CREATE DATA lr_data TYPE (name).
        result = abap_true.
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD get_text.

    result = get_default_text( key ).

    IF mo_ext IS BOUND.
      mo_ext->get_text( EXPORTING key  = key
                        CHANGING  text = result ).
    ENDIF.

  ENDMETHOD.


  METHOD get_default_text.

    "German for a German logon, the text pool (English, translatable in
    "SE63) otherwise - and z2ui5_if_rap_ext~get_text changes any of them
    IF sy-langu = 'D'.
      result = SWITCH #( key
        WHEN cs_text-create       THEN `Anlegen`
        WHEN cs_text-edit         THEN `Bearbeiten`
        WHEN cs_text-delete       THEN `Löschen`
        WHEN cs_text-save         THEN `Sichern`
        WHEN cs_text-cancel       THEN `Abbrechen`
        WHEN cs_text-ok           THEN `OK`
        WHEN cs_text-go           THEN `Start`
        WHEN cs_text-refresh      THEN `Aktualisieren`
        WHEN cs_text-search       THEN `Suchen`
        WHEN cs_text-yes          THEN `Ja`
        WHEN cs_text-no           THEN `Nein`
        WHEN cs_text-all          THEN `Alle`
        WHEN cs_text-general      THEN `Allgemein`
        WHEN cs_text-items        THEN `Einträge`
        WHEN cs_text-saved        THEN `Daten gesichert`
        WHEN cs_text-deleted      THEN `Daten gelöscht`
        WHEN cs_text-refreshed    THEN `Daten aktualisiert`
        WHEN cs_text-action_done  THEN `Aktion ausgeführt`
        WHEN cs_text-required     THEN `Bitte alle Pflichtfelder füllen`
        WHEN cs_text-read_only    THEN `Diese Entität kann nicht geändert werden`
        WHEN cs_text-load_error   THEN `Daten konnten nicht gelesen werden`
        WHEN cs_text-no_selection THEN `Bitte mindestens eine Zeile markieren`
        WHEN cs_text-filter_hint  THEN `abc, a*c, =abc, !abc, a..z, >x - mehrere mit ; trennen`
        WHEN cs_text-create_title THEN `Anlegen`
        WHEN cs_text-sort         THEN `Sortieren`
        WHEN cs_text-more         THEN `Mehr`
        WHEN cs_text-no_authority THEN `Keine Berechtigung`
        WHEN cs_text-locked       THEN `Der Eintrag ist gesperrt`
        WHEN cs_text-changed      THEN `Der Eintrag wurde inzwischen geändert - bitte neu lesen`
        WHEN cs_text-discard_draft THEN `Entwurf verwerfen`
        WHEN cs_text-no_launchpad THEN `Diese Navigation gibt es nur im Fiori Launchpad`
        WHEN cs_text-not_found    THEN `Kein Eintrag gefunden`
        WHEN cs_text-export       THEN `Exportieren`
        WHEN cs_text-copy_link    THEN `Link kopieren`
        WHEN cs_text-link_copied  THEN `Link kopiert`
        WHEN cs_text-standard     THEN `Standard`
        WHEN cs_text-save_view    THEN `Sicht sichern`
        WHEN cs_text-delete_view  THEN `Sicht löschen`
        WHEN cs_text-view_name    THEN `Name`
        WHEN cs_text-as_default   THEN `Als Standard verwenden`
        WHEN cs_text-view_saved   THEN `Sicht gesichert`
        WHEN cs_text-columns      THEN `Spalten`
        WHEN cs_text-resume_draft THEN `Entwurf fortsetzen`
        WHEN cs_text-keep_draft   THEN `Entwurf behalten`
        WHEN cs_text-leave_draft  THEN `Ihren Entwurf behalten oder verwerfen?`
        WHEN cs_text-own_draft    THEN `Entwurf`
        WHEN cs_text-locked_by    THEN `Gesperrt von &1`
        WHEN cs_text-editing_status THEN `Bearbeitungsstatus`
        WHEN cs_text-own_drafts   THEN `Eigener Entwurf`
        WHEN cs_text-locked_other THEN `Von anderem Benutzer gesperrt`
        WHEN cs_text-unchanged    THEN `Ungeändert`
        WHEN cs_text-not_allowed  THEN `Für diesen Eintrag nicht erlaubt`
        WHEN cs_text-field_read_only THEN `Diese Felder können nicht geändert werden`
        ELSE key ).
    ELSE.
      "the text pool of this class, original language English - translate
      "it in SE63; the literal stands in when a system has no text pool
      result = SWITCH #( key
        WHEN cs_text-create        THEN 'Create'(001)
        WHEN cs_text-edit          THEN 'Edit'(002)
        WHEN cs_text-delete        THEN 'Delete'(003)
        WHEN cs_text-save          THEN 'Save'(004)
        WHEN cs_text-cancel        THEN 'Cancel'(005)
        WHEN cs_text-ok            THEN 'OK'(006)
        WHEN cs_text-go            THEN 'Go'(007)
        WHEN cs_text-refresh       THEN 'Refresh'(008)
        WHEN cs_text-search        THEN 'Search'(009)
        WHEN cs_text-yes           THEN 'Yes'(010)
        WHEN cs_text-no            THEN 'No'(011)
        WHEN cs_text-all           THEN 'All'(012)
        WHEN cs_text-general       THEN 'General'(013)
        WHEN cs_text-items         THEN 'items'(014)
        WHEN cs_text-saved         THEN 'Data saved'(015)
        WHEN cs_text-deleted       THEN 'Data deleted'(016)
        WHEN cs_text-refreshed     THEN 'Data refreshed'(017)
        WHEN cs_text-action_done   THEN 'Action executed'(018)
        WHEN cs_text-required      THEN 'Fill in all required fields'(019)
        WHEN cs_text-read_only     THEN 'This entity cannot be changed'(020)
        WHEN cs_text-load_error    THEN 'Could not load data'(021)
        WHEN cs_text-no_selection  THEN 'Select at least one row'(022)
        WHEN cs_text-filter_hint   THEN 'abc, a*c, =abc, !abc, a..z, >x - separate several with ;'(023)
        WHEN cs_text-create_title  THEN 'Create'(024)
        WHEN cs_text-sort          THEN 'Sort'(025)
        WHEN cs_text-more          THEN 'More'(026)
        WHEN cs_text-no_authority  THEN 'No authorization'(027)
        WHEN cs_text-locked        THEN 'The record is locked'(028)
        WHEN cs_text-changed       THEN 'The record was changed meanwhile - read it again'(029)
        WHEN cs_text-discard_draft THEN 'Discard draft'(030)
        WHEN cs_text-no_launchpad  THEN 'This navigation is only available in the Fiori launchpad'(031)
        WHEN cs_text-not_found     THEN 'No record found'(032)
        WHEN cs_text-export        THEN 'Export'(033)
        WHEN cs_text-copy_link     THEN 'Copy link'(034)
        WHEN cs_text-link_copied   THEN 'Link copied'(035)
        WHEN cs_text-standard      THEN 'Standard'(036)
        WHEN cs_text-save_view     THEN 'Save view'(037)
        WHEN cs_text-delete_view   THEN 'Delete view'(038)
        WHEN cs_text-view_name     THEN 'Name'(039)
        WHEN cs_text-as_default    THEN 'Use as default'(040)
        WHEN cs_text-view_saved    THEN 'View saved'(041)
        WHEN cs_text-columns       THEN 'Columns'(042)
        WHEN cs_text-resume_draft  THEN 'Resume draft'(043)
        WHEN cs_text-keep_draft    THEN 'Keep draft'(044)
        WHEN cs_text-leave_draft   THEN 'Keep your draft or discard it?'(045)
        WHEN cs_text-own_draft     THEN 'Draft'(046)
        WHEN cs_text-locked_by     THEN 'Locked by &1'(047)
        WHEN cs_text-editing_status THEN 'Editing status'(048)
        WHEN cs_text-own_drafts    THEN 'Own draft'(049)
        WHEN cs_text-locked_other  THEN 'Locked by another user'(050)
        WHEN cs_text-unchanged     THEN 'Unchanged'(051)
        WHEN cs_text-not_allowed   THEN 'Not allowed for this record'(052)
        WHEN cs_text-field_read_only THEN 'These fields cannot be changed'(053)
        ELSE key ).
    ENDIF.

  ENDMETHOD.


  METHOD adjust_entity.
    IF mo_ext IS BOUND.
      mo_ext->adjust_entity( EXPORTING floorplan = mv_floorplan
                             CHANGING  entity    = cs_entity ).
    ENDIF.
  ENDMETHOD.


  METHOD render_extension.
    IF mo_ext IS BOUND.
      mo_ext->extend_view( floorplan = mv_floorplan
                           spot      = spot
                           container = io_container
                           client    = client ).
    ENDIF.
  ENDMETHOD.


  METHOD ext_on_event.
    IF mo_ext IS BOUND.
      result = mo_ext->on_event( floorplan = mv_floorplan
                                 client    = client ).
    ENDIF.
  ENDMETHOD.


  METHOD select_rows.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    "the host structure - a dynamic WHERE names it as @<LS_HOST>-field
    "(cv_host), so the name of this field symbol is part of the contract
    FIELD-SYMBOLS <ls_host> TYPE any.
    DATA lt_virtual TYPE string_table.
    DATA lt_columns TYPE string_table.
    DATA lv_fields TYPE string.
    DATA lv_order_by TYPE string.
    DATA lv_corresponding TYPE abap_bool.

    CLEAR mv_read_error.
    IF host IS BOUND.
      ASSIGN host->* TO <ls_host>.
    ENDIF.

    DATA(lv_where) = get_ext_where( entity_name = entity_name
                                    where       = where ).
    DATA(ls_read) = get_read_info( entity_name ).

    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        DATA(lt_comp) = lo_struct->get_components( ).
        IF with_selection = abap_true.
          IF NOT line_exists( lt_comp[ name = cv_select_column ] ).
            APPEND VALUE #( name = cv_select_column
                            type = CAST #( cl_abap_typedescr=>describe_by_name( `ABAP_BOOL` ) ) ) TO lt_comp.
          ENDIF.
          lo_struct = cl_abap_structdescr=>create( lt_comp ).
        ENDIF.
        DATA(lo_table) = cl_abap_tabledescr=>create( lo_struct ).
        CREATE DATA result TYPE HANDLE lo_table.
        ASSIGN result->* TO <lt_data>.

        "a custom entity: its query provider reads it - ABAP SQL cannot
        IF ls_read-query_class IS NOT INITIAL.
          query_rows( entity_name = entity_name
                      query_class = ls_read-query_class
                      where       = lv_where
                      host        = host
                      max_rows    = max_rows
                      order_by    = order_by
                      data        = result ).
        ELSE.
          "a virtual element has no column: the others are selected, and
          "a condition or sort criterion on it is left out
          LOOP AT ls_read-virtual_elements INTO DATA(ls_virtual).
            APPEND ls_virtual-name TO lt_virtual.
          ENDLOOP.
          lv_fields = `*`.
          lv_order_by = order_by.
          lv_corresponding = with_selection.
          IF lt_virtual IS NOT INITIAL.
            LOOP AT lt_comp INTO DATA(ls_comp).
              IF ls_comp-name <> cv_select_column AND NOT line_exists( lt_virtual[ table_line = ls_comp-name ] ).
                APPEND ls_comp-name TO lt_columns.
              ENDIF.
            ENDLOOP.
            lv_fields = concat_lines_of( table = lt_columns sep = `, ` ).
            lv_where = z2ui5_cl_rap_util=>remove_where_fields( where  = lv_where
                                                               fields = lt_virtual ).
            lv_order_by = adjust_virtual_order_by( entity_name      = entity_name
                                                   order_by         = order_by
                                                   virtual_elements = ls_read-virtual_elements ).
            lv_corresponding = abap_true.
          ENDIF.

          "sorted in the database - UP TO n ROWS without an ORDER BY is n
          "arbitrary rows, and sorting them afterwards sorts the wrong ones
          IF lv_corresponding = abap_true AND lv_order_by IS NOT INITIAL.
            SELECT (lv_fields) FROM (entity_name)
              WHERE (lv_where)
              ORDER BY (lv_order_by)
              INTO CORRESPONDING FIELDS OF TABLE @<lt_data>
              UP TO @max_rows ROWS.
          ELSEIF lv_corresponding = abap_true.
            SELECT (lv_fields) FROM (entity_name)
              WHERE (lv_where)
              INTO CORRESPONDING FIELDS OF TABLE @<lt_data>
              UP TO @max_rows ROWS.
          ELSEIF lv_order_by IS NOT INITIAL.
            SELECT (lv_fields) FROM (entity_name)
              WHERE (lv_where)
              ORDER BY (lv_order_by)
              INTO TABLE @<lt_data>
              UP TO @max_rows ROWS.
          ELSE.
            SELECT (lv_fields) FROM (entity_name)
              WHERE (lv_where)
              INTO TABLE @<lt_data>
              UP TO @max_rows ROWS.
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(lx_read).
        mv_read_error = lx_read->get_text( ).
        CLEAR result.
        RETURN.
    ENDTRY.

    IF ls_read-query_class IS INITIAL AND ls_read-virtual_elements IS NOT INITIAL.
      calculate_virtual_elements( entity_name      = entity_name
                                  virtual_elements = ls_read-virtual_elements
                                  data             = result ).
    ENDIF.

    IF mo_ext IS BOUND.
      mo_ext->after_load( floorplan   = mv_floorplan
                          entity_name = entity_name
                          data        = result ).
    ENDIF.

  ENDMETHOD.


  METHOD get_ext_where.
    result = where.
    IF mo_ext IS BOUND.
      mo_ext->adjust_where( EXPORTING floorplan   = mv_floorplan
                                      entity_name = entity_name
                            CHANGING  where       = result ).
    ENDIF.
  ENDMETHOD.


  METHOD count_rows.

    DATA lt_virtual TYPE string_table.

    CLEAR mv_read_error.
    DATA(lv_where) = get_ext_where( entity_name = entity_name
                                    where       = where ).
    DATA(ls_read) = get_read_info( entity_name ).
    TRY.
        IF ls_read-query_class IS NOT INITIAL.
          query_rows( EXPORTING entity_name     = entity_name
                                query_class     = ls_read-query_class
                                where           = lv_where
                                count_requested = abap_true
                      IMPORTING count           = result ).
          RETURN.
        ENDIF.
        LOOP AT ls_read-virtual_elements INTO DATA(ls_virtual).
          APPEND ls_virtual-name TO lt_virtual.
        ENDLOOP.
        lv_where = z2ui5_cl_rap_util=>remove_where_fields( where  = lv_where
                                                           fields = lt_virtual ).
        SELECT COUNT(*) FROM (entity_name)
          WHERE (lv_where)
          INTO @result.
      CATCH cx_root INTO DATA(lx_read).
        mv_read_error = lx_read->get_text( ).
        result = 0.
    ENDTRY.

  ENDMETHOD.


  METHOD get_read_info.
    result = z2ui5_cl_rap_util=>get_read_info( entity_name ).
    "the provider is called through the query interfaces - without them
    "there is nothing to read the entity with
    IF result-query_class IS NOT INITIAL AND query_available( ) = abap_false.
      CLEAR result-query_class.
    ENDIF.
  ENDMETHOD.


  METHOD query_rows.

    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lt_host TYPE z2ui5_cl_rap_util=>ty_t_name_value.
    DATA lt_elements TYPE string_table.
    DATA lv_total TYPE int8.

    CLEAR count.

    "the host variables of a key condition as their values - a provider
    "cannot read @<LS_HOST>-field
    IF host IS BOUND.
      ASSIGN host->* TO <ls_host>.
      DATA(lo_host) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <ls_host> ) ).
      LOOP AT lo_host->components INTO DATA(ls_host_comp).
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT ls_host_comp-name OF STRUCTURE <ls_host> TO <lv_value>.
        IF <lv_value> IS ASSIGNED.
          APPEND VALUE #( name  = to_upper( ls_host_comp-name )
                          value = |{ <lv_value> }| ) TO lt_host.
        ENDIF.
      ENDLOOP.
    ENDIF.

    "every element of the entity is requested
    DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
    LOOP AT lo_struct->components INTO DATA(ls_comp).
      IF ls_comp-name <> cv_select_column.
        APPEND |{ ls_comp-name }| TO lt_elements.
      ENDIF.
    ENDLOOP.

    z2ui5_cl_rap_query=>select(
      EXPORTING
        query_class = query_class
        entity_name = entity_name
        filter      = z2ui5_cl_rap_util=>build_query_filter( where       = where
                                                             host_values = lt_host )
        sort        = z2ui5_cl_rap_util=>parse_order_by( order_by )
        elements    = lt_elements
        page_size   = max_rows
        data        = data
        count       = count_requested
      IMPORTING
        total       = lv_total ).
    count = lv_total.

  ENDMETHOD.


  METHOD calculate_virtual_elements.

    "the types of IF_SADL_EXIT_CALC_ELEMENT_READ - its parameters are
    "passed by reference, so they have to be the same
    TYPES ty_t_elements TYPE SORTED TABLE OF string WITH UNIQUE DEFAULT KEY.
    DATA lt_elements TYPE ty_t_elements.
    DATA lt_original TYPE ty_t_elements.
    DATA lt_classes TYPE string_table.
    DATA lr_calculated TYPE REF TO data.
    DATA lo_calc TYPE REF TO object.
    DATA lv_index TYPE i.
    DATA(lv_entity) = to_upper( entity_name ).
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_calculated> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <ls_calculated> TYPE any.
    FIELD-SYMBOLS <lv_target> TYPE any.
    FIELD-SYMBOLS <lv_source> TYPE any.

    IF data IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN data->* TO <lt_data>.
    IF <lt_data> IS NOT ASSIGNED OR <lt_data> IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT virtual_elements INTO DATA(ls_virtual) WHERE calc_class IS NOT INITIAL.
      IF NOT line_exists( lt_classes[ table_line = ls_virtual-calc_class ] ).
        APPEND ls_virtual-calc_class TO lt_classes.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_classes INTO DATA(lv_class).
      CLEAR: lt_elements, lt_original.
      LOOP AT virtual_elements INTO ls_virtual WHERE calc_class = lv_class.
        INSERT ls_virtual-name INTO TABLE lt_elements.
      ENDLOOP.
      TRY.
          CREATE OBJECT lo_calc TYPE (lv_class).
          CALL METHOD lo_calc->('IF_SADL_EXIT_CALC_ELEMENT_READ~GET_CALCULATION_INFO')
            EXPORTING
              it_requested_calc_elements = lt_elements
              iv_entity                  = lv_entity
            IMPORTING
              et_requested_orig_elements = lt_original.
          "every column is read already - the original elements it asks for
          "are there
          CREATE DATA lr_calculated LIKE <lt_data>.
          ASSIGN lr_calculated->* TO <lt_calculated>.
          <lt_calculated> = <lt_data>.
          CALL METHOD lo_calc->('IF_SADL_EXIT_CALC_ELEMENT_READ~CALCULATE')
            EXPORTING
              it_original_data           = <lt_data>
              it_requested_calc_elements = lt_elements
            CHANGING
              ct_calculated_data         = <lt_calculated>.
        CATCH cx_root.
          "the elements of this class stay empty, the rows are shown
          CONTINUE.
      ENDTRY.

      "only the calculated elements are taken over, row by row
      LOOP AT <lt_data> ASSIGNING <ls_row>.
        lv_index = sy-tabix.
        UNASSIGN <ls_calculated>.
        READ TABLE <lt_calculated> INDEX lv_index ASSIGNING <ls_calculated>.
        IF <ls_calculated> IS NOT ASSIGNED.
          EXIT.
        ENDIF.
        LOOP AT lt_elements INTO DATA(lv_element).
          UNASSIGN: <lv_target>, <lv_source>.
          ASSIGN COMPONENT lv_element OF STRUCTURE <ls_row> TO <lv_target>.
          ASSIGN COMPONENT lv_element OF STRUCTURE <ls_calculated> TO <lv_source>.
          IF <lv_target> IS ASSIGNED AND <lv_source> IS ASSIGNED.
            <lv_target> = <lv_source>.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD adjust_virtual_order_by.

    "the type of IF_SADL_EXIT_SORT_TRANSFORM=>TT_SORT_ELEMENTS - passed by
    "reference, so it has to be the same
    TYPES:
      BEGIN OF ty_s_sort_element,
        name    TYPE string,
        reverse TYPE abap_bool,
      END OF ty_s_sort_element.
    TYPES ty_t_sort_elements TYPE STANDARD TABLE OF ty_s_sort_element WITH DEFAULT KEY.
    DATA lt_mapped TYPE ty_t_sort_elements.
    DATA lt_sort TYPE z2ui5_cl_rap_util=>ty_t_sort.
    DATA lo_sort TYPE REF TO object.
    DATA(lv_entity) = to_upper( entity_name ).

    LOOP AT z2ui5_cl_rap_util=>parse_order_by( order_by ) INTO DATA(ls_sort).
      READ TABLE virtual_elements INTO DATA(ls_virtual) WITH KEY name = ls_sort-field.
      IF sy-subrc <> 0.
        APPEND ls_sort TO lt_sort.
        CONTINUE.
      ENDIF.
      IF ls_virtual-sort_class IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR lt_mapped.
      TRY.
          CREATE OBJECT lo_sort TYPE (ls_virtual-sort_class).
          CALL METHOD lo_sort->('IF_SADL_EXIT_SORT_TRANSFORM~MAP_ELEMENT')
            EXPORTING
              iv_entity        = lv_entity
              iv_element       = ls_sort-field
            IMPORTING
              et_sort_elements = lt_mapped.
        CATCH cx_root ##NO_HANDLER.
          "not sorted by it
      ENDTRY.
      LOOP AT lt_mapped INTO DATA(ls_mapped).
        DATA(lv_name) = to_upper( ls_mapped-name ).
        IF line_exists( virtual_elements[ name = lv_name ] ) OR line_exists( lt_sort[ field = lv_name ] ).
          CONTINUE.
        ENDIF.
        "reverse: the element sorts the other way round than the virtual one
        APPEND VALUE #( field      = lv_name
                        descending = xsdbool( ls_sort-descending <> ls_mapped-reverse ) ) TO lt_sort.
      ENDLOOP.
    ENDLOOP.

    result = z2ui5_cl_rap_util=>order_by_to_string( lt_sort ).

  ENDMETHOD.


  METHOD aggregate_rows.
    DATA(lr_rows) = select_rows( entity_name = entity_name
                                 where       = where
                                 max_rows    = cv_aggregate_max ).
    result = z2ui5_cl_rap_util=>aggregate_rows( data     = lr_rows
                                                group_by = group_by
                                                measure  = measure
                                                method   = method ).
  ENDMETHOD.


  METHOD get_load_error.
    result = |{ get_text( cs_text-load_error ) }: { entity_name }|.
    IF mv_read_error IS NOT INITIAL.
      result = |{ result } - { mv_read_error }|.
    ENDIF.
  ENDMETHOD.


  METHOD build_filter_condition.
    result = z2ui5_cl_rap_util=>build_filter_condition( is_field = is_field
                                                        value    = value ).
  ENDMETHOD.


  METHOD build_search_condition.
    result = z2ui5_cl_rap_util=>build_search_condition( it_fields = it_fields
                                                        search    = search ).
  ENDMETHOD.


  METHOD criticality_expression.
    result = `{= ${` && crit_field &&
             `} === 3 ? 'Success' : (${` && crit_field &&
             `} === 1 ? 'Error' : (${` && crit_field &&
             `} === 2 ? 'Warning' : 'None')) }`.
  ENDMETHOD.


  METHOD criticality_state.
    result = SWITCH #( value
      WHEN 1 THEN `Error`
      WHEN 2 THEN `Warning`
      WHEN 3 THEN `Success`
      ELSE `None` ).
  ENDMETHOD.


  METHOD prepare_value_lists.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_lists TYPE STANDARD TABLE OF REF TO data WITH DEFAULT KEY.
    FIELD-SYMBOLS <ls_lists> TYPE any.
    FIELD-SYMBOLS <lt_target> TYPE any.
    FIELD-SYMBOLS <lt_source> TYPE any.

    CLEAR mr_value_lists.

    LOOP AT it_fields INTO DATA(ls_field)
      WHERE value_help-is_dropdown = abap_true AND is_hidden = abap_false.
      DATA(lr_rows) = select_rows( entity_name = ls_field-value_help-entity_name ).
      IF lr_rows IS NOT BOUND OR line_exists( lt_comp[ name = ls_field-name ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = ls_field-name
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_rows ) ) )
        TO lt_comp.
      APPEND lr_rows TO lt_lists.
    ENDLOOP.

    IF lt_comp IS NOT INITIAL.
      DATA(lo_struct) = cl_abap_structdescr=>create( lt_comp ).
      CREATE DATA mr_value_lists TYPE HANDLE lo_struct.
      ASSIGN mr_value_lists->* TO <ls_lists>.
      LOOP AT lt_lists INTO DATA(lr_list).
        ASSIGN COMPONENT sy-tabix OF STRUCTURE <ls_lists> TO <lt_target>.
        ASSIGN lr_list->* TO <lt_source>.
        <lt_target> = <lt_source>.
      ENDLOOP.
    ENDIF.

    "the suggestions: an empty table per field with a value help that is
    "no dropdown - filled while the user types
    CLEAR: mr_suggestions, mt_suggest_text, lt_comp.
    LOOP AT it_fields INTO ls_field
      WHERE value_help-is_dropdown = abap_false AND value_help-entity_name IS NOT INITIAL
        AND value_help-element IS NOT INITIAL AND is_hidden = abap_false.
      IF line_exists( lt_comp[ name = ls_field-name ] ).
        CONTINUE.
      ENDIF.
      DATA(lr_empty) = create_entity_table( ls_field-value_help-entity_name ).
      IF lr_empty IS NOT BOUND.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name = ls_field-name
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_empty ) ) )
        TO lt_comp.
      "the text of the element, shown next to it
      DATA(ls_vh_entity) = z2ui5_cl_rap_util=>read_entity( ls_field-value_help-entity_name ).
      READ TABLE ls_vh_entity-fields INTO DATA(ls_element) WITH KEY name = ls_field-value_help-element.
      IF sy-subrc = 0 AND ls_element-text_element IS NOT INITIAL
        AND line_exists( ls_vh_entity-fields[ name = ls_element-text_element ] ).
        APPEND VALUE #( name = ls_field-name value = ls_element-text_element ) TO mt_suggest_text.
      ENDIF.
    ENDLOOP.
    IF lt_comp IS NOT INITIAL.
      DATA(lo_suggest) = cl_abap_structdescr=>create( lt_comp ).
      CREATE DATA mr_suggestions TYPE HANDLE lo_suggest.
    ENDIF.

  ENDMETHOD.


  METHOD load_suggestions.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_target> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    DATA(lv_field) = client->get_event_arg( 1 ).
    DATA(lv_text) = condense( client->get_event_arg( 2 ) ).
    IF mr_suggestions IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_suggestions->* TO <ls_all>.
    ASSIGN COMPONENT lv_field OF STRUCTURE <ls_all> TO <lt_target>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    CLEAR <lt_target>.
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = lv_field.
    IF sy-subrc <> 0 OR lv_text IS INITIAL.
      RETURN.
    ENDIF.

    "the element starts with the text, or a text field contains it
    DATA(ls_vh_entity) = z2ui5_cl_rap_util=>read_entity( ls_field-value_help-entity_name ).
    DATA lt_or TYPE string_table.
    READ TABLE ls_vh_entity-fields INTO DATA(ls_element) WITH KEY name = ls_field-value_help-element.
    IF sy-subrc = 0.
      "the user's own * and ; are text here, not the filter syntax
      DATA(lv_prefix) = replace( val = lv_text sub = `*` with = `` occ = 0 ).
      lv_prefix = replace( val = lv_prefix sub = `;` with = `` occ = 0 ).
      IF ls_element-type_kind = `CHAR` AND lv_prefix IS NOT INITIAL AND lv_prefix(1) CN `=!<>`.
        APPEND build_filter_condition( is_field = ls_element
                                       value    = |{ lv_prefix }*| ) TO lt_or.
      ENDIF.
    ENDIF.
    DATA(lv_search) = build_search_condition( it_fields = ls_vh_entity-fields
                                              search    = lv_text ).
    IF lv_search IS NOT INITIAL.
      APPEND lv_search TO lt_or.
    ENDIF.
    DELETE lt_or WHERE table_line IS INITIAL.
    IF lt_or IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lr_rows) = select_rows( entity_name = ls_field-value_help-entity_name
                                 where       = |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )|
                                 max_rows    = 20 ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    <lt_target> = <lt_rows>.

  ENDMETHOD.


  METHOD render_field_input.

    FIELD-SYMBOLS <ls_lists> TYPE any.
    FIELD-SYMBOLS <lt_list> TYPE any.

    DATA(lv_editable) = xsdbool( editable = abap_true AND is_field-is_readonly = abap_false ).

    IF is_field-is_boolean = abap_true.
      io_container->tag( `CheckBox`
          )->a( n = `selected`
                v = client->_bind( value )
          )->a( n = `editable`
                b = lv_editable ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `DATS`.
      "the model carries a date as 2024-01-15 (the core's JSON)
      io_container->tag( `DatePicker`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `valueFormat`
                v = `yyyy-MM-dd`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      add_value_state( io_container     = io_container
                       value_state      = value_state
                       value_state_text = value_state_text ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `TIMS`.
      io_container->tag( `TimePicker`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `valueFormat`
                v = `HH:mm:ss`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      add_value_state( io_container     = io_container
                       value_state      = value_state
                       value_state_text = value_state_text ).
      RETURN.
    ENDIF.

    IF is_field-is_multiline = abap_true OR is_field-type_kind = `STRING`.
      io_container->tag( `TextArea`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `rows`
                v = `3`
          )->a( n = `width`
                v = `100%`
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      add_value_state( io_container     = io_container
                       value_state      = value_state
                       value_state_text = value_state_text ).
      RETURN.
    ENDIF.

    IF is_field-value_help-is_dropdown = abap_true AND mr_value_lists IS BOUND.
      ASSIGN mr_value_lists->* TO <ls_lists>.
      ASSIGN COMPONENT is_field-name OF STRUCTURE <ls_lists> TO <lt_list>.
      IF sy-subrc = 0.
        DATA(lv_key_path) = |\{{ is_field-value_help-element }\}|.
        "the core prefix is declared here, so no view has to carry it for
        "a ComboBox it may never render
        io_container->ele( `ComboBox`
            )->a( n = `xmlns:core`
                  v = `sap.ui.core`
            )->a( n = `selectedKey`
                  v = client->_bind( value )
            )->a( n = `items`
                  v = client->_bind( <lt_list> )
            )->a( n = `editable`
                  b = lv_editable
            )->a( n = `required`
                  b = is_field-is_mandatory
            )->tag( n  = `Item`
                    ns = `core`
                )->a( n = `key`
                      v = lv_key_path
                )->a( n = `text`
                      v = lv_key_path ).
        add_value_state( io_container     = io_container
                         value_state      = value_state
                         value_state_text = value_state_text ).
        RETURN.
      ENDIF.
    ENDIF.

    IF is_field-value_help-entity_name IS NOT INITIAL AND vh_event IS NOT INITIAL.
      DATA(lo_input) = io_container->ele( `Input`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `showValueHelp`
                v = `true`
          )->a( n = `valueHelpRequest`
                v = client->_event( val = vh_event
                                    arg = is_field-name )
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      "suggestions while the user types - a per-keystroke wire: the last
      "keystroke is never lost and the busy indicator stays down
      IF mr_suggestions IS BOUND AND lv_editable = abap_true.
        ASSIGN mr_suggestions->* TO <ls_lists>.
        ASSIGN COMPONENT is_field-name OF STRUCTURE <ls_lists> TO <lt_list>.
        IF sy-subrc = 0.
          lo_input->a( n = `xmlns:core`
                       v = `sap.ui.core`
              )->a( n = `showSuggestion`
                    v = `true`
              )->a( n = `suggest`
                    v = client->_event( val    = cv_event_suggest
                                        t_arg  = VALUE #( ( is_field-name ) ( `${$parameters>/suggestValue}` ) )
                                        s_ctrl = VALUE #( check_queue_last = abap_true
                                                          check_no_busy    = abap_true ) )
              )->a( n = `suggestionItems`
                    v = client->_bind( <lt_list> ) ).
          DATA(lo_item) = lo_input->ele( `suggestionItems`
              )->tag( n  = `ListItem`
                      ns = `core`
                  )->a( n = `text`
                        v = |\{{ is_field-value_help-element }\}| ).
          READ TABLE mt_suggest_text INTO DATA(ls_text) WITH KEY name = is_field-name.
          IF sy-subrc = 0.
            lo_item->a( n = `additionalText`
                        v = |\{{ ls_text-value }\}| ).
          ENDIF.
        ENDIF.
      ENDIF.
      add_value_state( io_container     = io_container
                       value_state      = value_state
                       value_state_text = value_state_text ).
      RETURN.
    ENDIF.

    IF is_field-type_kind = `CHAR` AND is_field-length > 0.
      io_container->tag( `Input`
          )->a( n = `value`
                v = client->_bind( value )
          )->a( n = `maxLength`
                v = |{ is_field-length }|
          )->a( n = `editable`
                b = lv_editable
          )->a( n = `required`
                b = is_field-is_mandatory ).
      add_value_state( io_container     = io_container
                       value_state      = value_state
                       value_state_text = value_state_text ).
      RETURN.
    ENDIF.

    io_container->tag( `Input`
        )->a( n = `value`
              v = client->_bind( value )
        )->a( n = `editable`
              b = lv_editable
        )->a( n = `required`
              b = is_field-is_mandatory ).
    add_value_state( io_container     = io_container
                     value_state      = value_state
                     value_state_text = value_state_text ).

  ENDMETHOD.


  METHOD open_value_help.

    FIELD-SYMBOLS <lv_value> TYPE any.
    DATA lt_filter TYPE ty_t_name_value.

    "additional bindings with usage FILTER (or no usage, which is both)
    "restrict the value help by what is already entered
    IF source IS SUPPLIED.
      LOOP AT is_field-value_help-additional_binding INTO DATA(ls_bind)
        WHERE local_element IS NOT INITIAL AND element IS NOT INITIAL.
        IF ls_bind-usage IS NOT INITIAL AND ls_bind-usage NS `FILTER`.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-local_element OF STRUCTURE source TO <lv_value>.
        IF sy-subrc = 0 AND <lv_value> IS NOT INITIAL.
          APPEND VALUE #( name = ls_bind-element value = |{ <lv_value> }| ) TO lt_filter.
        ENDIF.
      ENDLOOP.
    ENDIF.

    mv_vh_target = is_field-name.

    DATA(lo_vh) = NEW z2ui5_cl_rap_value_help(
      cds_view_name = is_field-value_help-entity_name
      element       = is_field-value_help-element
      title         = is_field-label
      multi_select  = multi_select
      filters       = lt_filter ).
    lo_vh->set_extension( mo_ext ).
    client->nav_app_call( lo_vh ).

  ENDMETHOD.


  METHOD get_value_help_result.

    "mv_vh_target says a value help was called - not check_app_prev_stack( ),
    "which answers whether THIS app has a caller: a floorplan that is the
    "root app (started directly, restored from a bookmark) has none, and its
    "value help results were dropped
    IF mv_vh_target IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_vh) = CAST z2ui5_cl_rap_value_help( client->get_app_prev( ) ).
        IF lo_vh->was_confirmed( ) = abap_true.
          result = lo_vh.
        ELSEIF lo_vh->load_error( ) IS NOT INITIAL.
          "the value help could not say it itself - a message queued before
          "nav_app_leave( ) does not reach the browser
          client->message_box_display( text = lo_vh->load_error( )
                                       type = `error` ).
        ENDIF.
      "a cast error, or a previous app the draft no longer has
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.


  METHOD apply_value_help.

    FIELD-SYMBOLS <lv_target> TYPE any.
    FIELD-SYMBOLS <lv_source> TYPE any.
    FIELD-SYMBOLS <ls_row> TYPE any.

    DATA(lo_vh) = get_value_help_result( client ).
    DATA(lv_field) = mv_vh_target.
    CLEAR mv_vh_target.
    IF lo_vh IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT lv_field OF STRUCTURE target TO <lv_target>.
    IF sy-subrc = 0.
      <lv_target> = lo_vh->result_value( ).
    ENDIF.

    "additional bindings with usage RESULT (or no usage, which is both)
    READ TABLE it_fields INTO DATA(ls_field) WITH KEY name = lv_field.
    DATA(lv_found) = xsdbool( sy-subrc = 0 ).
    DATA(lr_row) = lo_vh->result( ).
    IF lv_found = abap_true AND lr_row IS BOUND.
      ASSIGN lr_row->* TO <ls_row>.
      LOOP AT ls_field-value_help-additional_binding INTO DATA(ls_bind)
        WHERE local_element IS NOT INITIAL AND element IS NOT INITIAL.
        IF ls_bind-usage IS NOT INITIAL AND ls_bind-usage NS `RESULT`.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-element OF STRUCTURE <ls_row> TO <lv_source>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT ls_bind-local_element OF STRUCTURE target TO <lv_target>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        <lv_target> = <lv_source>.
      ENDLOOP.
    ENDIF.

    result = abap_true.

  ENDMETHOD.


  METHOD find_row_by_event_keys.

    DATA lt_values TYPE string_table.
    DO lines( key_fields ) TIMES.
      APPEND client->get_event_arg( arg_offset + sy-index ) TO lt_values.
    ENDDO.
    result = find_row_by_keys( data       = data
                               key_fields = key_fields
                               key_values = lt_values ).

  ENDMETHOD.


  METHOD find_row_by_keys.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_val> TYPE any.

    IF data IS NOT BOUND OR key_fields IS INITIAL OR lines( key_values ) < lines( key_fields ).
      RETURN.
    ENDIF.
    ASSIGN data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_match) = abap_true.
      LOOP AT key_fields INTO DATA(lv_key).
        DATA(lv_idx) = sy-tabix.
        ASSIGN COMPONENT lv_key OF STRUCTURE <ls_row> TO <lv_val>.
        IF sy-subrc <> 0
          OR normalize_key_value( |{ <lv_val> }| ) <> normalize_key_value( key_values[ lv_idx ] ).
          lv_match = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_match = abap_true.
        result = REF #( <ls_row> ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD create_entity_table.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( entity_name ) ).
        IF with_selection = abap_true.
          DATA(lt_comp) = lo_struct->get_components( ).
          IF NOT line_exists( lt_comp[ name = cv_select_column ] ).
            APPEND VALUE #( name = cv_select_column
                            type = CAST #( cl_abap_typedescr=>describe_by_name( `ABAP_BOOL` ) ) ) TO lt_comp.
          ENDIF.
          lo_struct = cl_abap_structdescr=>create( lt_comp ).
        ENDIF.
        DATA(lo_table) = cl_abap_tabledescr=>create( lo_struct ).
        CREATE DATA result TYPE HANDLE lo_table.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD navigate_to_intent.

    IF client->get( )-check_launchpad_active = abap_false.
      client->message_box_display( text = get_text( cs_text-no_launchpad ) ).
      RETURN.
    ENDIF.

    "two JSON objects - the frontend receives them as objects, not strings
    DATA lt_params TYPE string_table.
    LOOP AT params INTO DATA(ls_param).
      APPEND |"{ z2ui5_cl_rap_util=>json_escape( ls_param-name ) }":"{ z2ui5_cl_rap_util=>json_escape( ls_param-value ) }"|
        TO lt_params.
    ENDLOOP.
    DATA(lv_target) = |\{"semanticObject":"{ z2ui5_cl_rap_util=>json_escape( semantic_object ) }",| &&
                      |"action":"{ z2ui5_cl_rap_util=>json_escape( action ) }"\}|.
    DATA(lv_params) = |\{{ concat_lines_of( table = lt_params sep = `,` ) }\}|.
    client->follow_up_action( val   = client->cs_event-cross_app_nav_to_ext
                              t_arg = VALUE #( ( lv_target ) ( lv_params ) ) ).

  ENDMETHOD.


  METHOD read_association_target.

    DATA lt_values TYPE ty_t_name_value.
    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lv_value> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    READ TABLE is_entity-associations INTO DATA(ls_assoc) WITH KEY name = to_upper( association ).
    IF sy-subrc <> 0 OR ls_assoc-conditions IS INITIAL OR ls_assoc-target IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT ls_condition-local OF STRUCTURE row TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED.
        RETURN.
      ENDIF.
      APPEND VALUE #( name = ls_condition-target value = |{ <lv_value> }| ) TO lt_values.
      APPEND ls_condition-target TO lt_names.
    ENDLOOP.

    DATA(lr_rows) = select_rows( entity_name = ls_assoc-target
                                 where       = build_key_condition( lt_names )
                                 max_rows    = 1
                                 host        = create_host( entity_name = ls_assoc-target
                                                            values      = lt_values ) ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
    IF sy-subrc = 0.
      result = to_entity_row( entity_name = ls_assoc-target
                              row         = <ls_row> ).
    ENDIF.

  ENDMETHOD.


  METHOD to_entity_row.

    FIELD-SYMBOLS <ls_row> TYPE any.
    TRY.
        CREATE DATA result TYPE (entity_name).
        ASSIGN result->* TO <ls_row>.
        MOVE-CORRESPONDING row TO <ls_row>.
      CATCH cx_root.
        CREATE DATA result LIKE row.
        ASSIGN result->* TO <ls_row>.
        <ls_row> = row.
    ENDTRY.

  ENDMETHOD.


  METHOD get_selected_rows.

    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_result> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_selected> TYPE any.

    IF data IS NOT BOUND.
      RETURN.
    ENDIF.
    result = create_entity_table( entity_name ).
    IF result IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN result->* TO <lt_result>.
    ASSIGN data->* TO <lt_data>.

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT cv_select_column OF STRUCTURE <ls_row> TO <lv_selected>.
      IF sy-subrc <> 0 OR <lv_selected> = abap_false.
        CONTINUE.
      ENDIF.
      APPEND INITIAL LINE TO <lt_result> ASSIGNING FIELD-SYMBOL(<ls_result>).
      MOVE-CORRESPONDING <ls_row> TO <ls_result>.
    ENDLOOP.

  ENDMETHOD.


  METHOD write_row.

    DATA lv_cancel TYPE abap_bool.
    DATA lr_row TYPE REF TO data.
    FIELD-SYMBOLS <ls_row> TYPE any.

    "decided here, not by the buttons - an event can arrive without one
    DATA(ls_caps) = get_entity_capabilities( entity_name = entity_name
                                             context     = context ).
    DATA(lv_allowed) = SWITCH abap_bool( operation
      WHEN `CREATE` THEN ls_caps-can_create
      WHEN `UPDATE` THEN ls_caps-can_update
      WHEN `DELETE` THEN ls_caps-can_delete
      ELSE abap_false ).
    IF lv_allowed = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.

    "the record's own permissions, its read-only fields and - without a
    "draft - that nobody changed it meanwhile (since 2026-10, third round)
    IF ls_caps-is_rap_bo = abap_true AND ( operation = `UPDATE` OR operation = `DELETE` ).
      IF original IS SUPPLIED.
        result-messages = check_rap_write( entity_name = entity_name
                                           operation   = operation
                                           row         = row
                                           original    = original
                                           context     = context ).
      ELSE.
        result-messages = check_rap_write( entity_name = entity_name
                                           operation   = operation
                                           row         = row
                                           original    = row
                                           context     = context ).
      ENDIF.
      IF result-messages IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    CREATE DATA lr_row LIKE row.
    ASSIGN lr_row->* TO <ls_row>.
    <ls_row> = row.

    IF mo_ext IS BOUND.
      mo_ext->before_save( EXPORTING entity_name = entity_name
                                     operation   = operation
                                     data        = lr_row
                           CHANGING  messages    = result-messages
                                     cancel      = lv_cancel ).
      IF lv_cancel = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    IF ls_caps-is_rap_bo = abap_true.
      CASE operation.
        WHEN `CREATE`.
          result = z2ui5_cl_rap_eml=>create( entity_name = entity_name
                                             row         = <ls_row>
                                             context     = context ).
        WHEN `UPDATE`.
          result = z2ui5_cl_rap_eml=>update( entity_name = entity_name
                                             row         = <ls_row>
                                             original    = original
                                             context     = context ).
        WHEN `DELETE`.
          result = z2ui5_cl_rap_eml=>delete( entity_name = entity_name
                                             row         = <ls_row>
                                             context     = context ).
      ENDCASE.
    ELSEIF original IS SUPPLIED.
      result = write_table_row( entity_name = entity_name
                                operation   = operation
                                row         = <ls_row>
                                original    = original ).
    ELSE.
      result = write_table_row( entity_name = entity_name
                                operation   = operation
                                row         = <ls_row> ).
    ENDIF.

    IF result-success = abap_true AND mo_ext IS BOUND.
      mo_ext->after_save( entity_name = entity_name
                          operation   = operation
                          data        = lr_row ).
    ENDIF.

  ENDMETHOD.


  METHOD write_table_row.

    DATA lv_tabname TYPE c LENGTH 30.
    DATA lv_varkey TYPE c LENGTH 120.
    DATA lt_ddic TYPE ddfields.
    DATA lt_keys TYPE string_table.
    DATA lr_current TYPE REF TO data.
    DATA lr_seen TYPE REF TO data.
    "the host structure of the key condition (build_key_condition)
    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <ls_current> TYPE any.
    FIELD-SYMBOLS <ls_seen> TYPE any.
    FIELD-SYMBOLS <lv_from> TYPE any.
    FIELD-SYMBOLS <lv_to> TYPE any.

    lv_tabname = to_upper( entity_name ).

    "the authorization of table maintenance by table name - what SM30 and
    "SE16 ask before a change
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD lv_tabname.
    IF sy-subrc <> 0.
      APPEND |{ get_text( cs_text-no_authority ) }: { lv_tabname }| TO result-messages.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( lv_tabname ) ).
        lo_struct->get_ddic_field_list(
          RECEIVING
            p_field_list = lt_ddic
          EXCEPTIONS
            not_found    = 1
            no_ddic_type = 2
            OTHERS       = 3 ).
        IF sy-subrc <> 0.
          CLEAR lt_ddic.
        ENDIF.
      CATCH cx_root.
        CLEAR lt_ddic.
    ENDTRY.
    "the key without the client - ABAP SQL adds the client by itself
    LOOP AT lt_ddic INTO DATA(ls_ddic) WHERE keyflag = abap_true AND datatype <> `CLNT`.
      APPEND CONV string( ls_ddic-fieldname ) TO lt_keys.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      APPEND |{ get_text( cs_text-read_only ) }: { lv_tabname }| TO result-messages.
      RETURN.
    ENDIF.

    lv_varkey = get_table_varkey( row        = row
                                  key_fields = lt_ddic ).
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = lv_tabname
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc = 1.
      APPEND |{ get_text( cs_text-locked ) } ({ sy-msgv1 })| TO result-messages.
      RETURN.
    ELSEIF sy-subrc <> 0.
      APPEND get_text( cs_text-locked ) TO result-messages.
      RETURN.
    ENDIF.

    TRY.
        "still what the user saw? A change made meanwhile is reported, not
        "overwritten - and a row deleted meanwhile is not created again. An
        "update without the original can only check that the row is there
        IF operation <> `CREATE`.
          CREATE DATA lr_current TYPE (lv_tabname).
          ASSIGN lr_current->* TO <ls_current>.
          CREATE DATA lr_seen TYPE (lv_tabname).
          ASSIGN lr_seen->* TO <ls_seen>.
          IF operation = `UPDATE` AND original IS SUPPLIED.
            MOVE-CORRESPONDING original TO <ls_seen>.
          ELSE.
            MOVE-CORRESPONDING row TO <ls_seen>.
          ENDIF.
          ASSIGN row TO <ls_host>.
          DATA(lv_where) = build_key_condition( lt_keys ).
          SELECT SINGLE * FROM (lv_tabname)
            WHERE (lv_where)
            INTO @<ls_current>.
          IF sy-subrc <> 0.
            APPEND get_text( cs_text-changed ) TO result-messages.
          ELSE.
            "the client is the database's - not part of what was seen
            LOOP AT lt_ddic INTO ls_ddic WHERE datatype = `CLNT`.
              ASSIGN COMPONENT ls_ddic-fieldname OF STRUCTURE <ls_current> TO <lv_from>.
              ASSIGN COMPONENT ls_ddic-fieldname OF STRUCTURE <ls_seen> TO <lv_to>.
              IF <lv_from> IS ASSIGNED AND <lv_to> IS ASSIGNED.
                <lv_to> = <lv_from>.
              ENDIF.
              UNASSIGN: <lv_from>, <lv_to>.
            ENDLOOP.
            IF ( operation = `DELETE` OR original IS SUPPLIED ) AND <ls_seen> <> <ls_current>.
              APPEND get_text( cs_text-changed ) TO result-messages.
            ENDIF.
          ENDIF.
        ENDIF.

        IF result-messages IS INITIAL.
          CASE operation.
            WHEN `CREATE`.
              INSERT (lv_tabname) FROM @row.
            WHEN `UPDATE`.
              UPDATE (lv_tabname) FROM @row.
            WHEN `DELETE`.
              DELETE (lv_tabname) FROM @row.
          ENDCASE.
          "committed here: after main( ) the core rolls back the LUW of every
          "non-sticky app, so an uncommitted write showed "saved" and was gone
          IF sy-subrc = 0.
            COMMIT WORK.
            result-success = abap_true.
          ELSE.
            APPEND |{ operation } failed (sy-subrc { sy-subrc })| TO result-messages.
            ROLLBACK WORK.                               "#EC CI_ROLLBACK
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
        APPEND lx->get_text( ) TO result-messages.
    ENDTRY.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = lv_tabname
        varkey       = lv_varkey.

  ENDMETHOD.


  METHOD get_table_varkey.

    DATA lv_buffer TYPE c LENGTH 120.
    DATA lv_offset TYPE i.
    FIELD-SYMBOLS <lv_value> TYPE any.

    LOOP AT key_fields INTO DATA(ls_field) WHERE keyflag = abap_true.
      DATA(lv_length) = CONV i( ls_field-leng ).
      "only character-like keys have an internal form that is their text
      IF ls_field-inttype NA `CNDT` OR lv_offset + lv_length > 120.
        RETURN.
      ENDIF.
      IF ls_field-datatype = `CLNT`.
        lv_buffer+lv_offset(lv_length) = sy-mandt.
      ELSE.
        ASSIGN COMPONENT ls_field-fieldname OF STRUCTURE row TO <lv_value>.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        lv_buffer+lv_offset(lv_length) = <lv_value>.
      ENDIF.
      lv_offset = lv_offset + lv_length.
    ENDLOOP.
    result = lv_buffer.

  ENDMETHOD.


  METHOD get_entity_capabilities.

    DATA(ls_entity) = get_capabilities( entity_name = entity_name
                                        context     = context ).
    result = ls_entity.
    IF mo_ext IS BOUND.
      mo_ext->adjust_capabilities( EXPORTING floorplan   = mv_floorplan
                                             entity_name = to_upper( entity_name )
                                   CHANGING  caps        = result ).
    ENDIF.

    "the extension decides what is offered, not what the entity is: it may
    "withhold an operation of a business object and allow the writes of a
    "table, but it cannot give a business object an operation its BDEF
    "does not have, nor make a CDS view writable
    result-is_rap_bo = ls_entity-is_rap_bo.
    result-is_table = ls_entity-is_table.
    IF ls_entity-is_rap_bo = abap_true.
      result-can_create = xsdbool( result-can_create = abap_true AND ls_entity-can_create = abap_true ).
      result-can_update = xsdbool( result-can_update = abap_true AND ls_entity-can_update = abap_true ).
      result-can_delete = xsdbool( result-can_delete = abap_true AND ls_entity-can_delete = abap_true ).
    ELSEIF ls_entity-is_table = abap_false.
      CLEAR: result-can_create, result-can_update, result-can_delete.
    ENDIF.
    IF ls_entity-is_rap_bo = abap_false.
      RETURN.
    ENDIF.

    "nor what GET PERMISSIONS forbids (since 2026-10, third round): global
    "feature control and authorization, an internal operation - and a
    "create by association as the parent's association allows it
    IF context-association IS NOT INITIAL AND context-parent IS NOT INITIAL.
      DATA(lv_parent) = to_upper( context-parent ).
      DATA(lr_parent) = create_host( entity_name = lv_parent
                                     values      = context-parent_keys ).
      IF lr_parent IS BOUND.
        ASSIGN lr_parent->* TO FIELD-SYMBOL(<ls_parent>).
        DATA(ls_parent_perm) = get_row_permissions( entity_name = lv_parent
                                                    context     = VALUE #( bdef      = context-bdef
                                                                           root_keys = context-root_keys )
                                                    row         = <ls_parent> ).
        result-can_create = xsdbool( result-can_create = abap_true
          AND z2ui5_cl_rap_util=>is_permitted( ops  = ls_parent_perm-associations
                                               name = context-association ) = abap_true ).
      ENDIF.
    ELSE.
      DATA(ls_perm) = get_permissions( entity_name = entity_name
                                       context     = context ).
      IF ls_perm-answered = abap_true.
        result-can_create = xsdbool( result-can_create = abap_true AND ls_perm-global-can_create = abap_true ).
      ENDIF.
    ENDIF.
    ls_perm = get_permissions( entity_name = entity_name
                               context     = context ).
    IF ls_perm-answered = abap_true.
      result-can_update = xsdbool( result-can_update = abap_true AND ls_perm-global-can_update = abap_true ).
      result-can_delete = xsdbool( result-can_delete = abap_true AND ls_perm-global-can_delete = abap_true ).
    ENDIF.

  ENDMETHOD.


  METHOD build_key_condition.

    DATA lt_and TYPE string_table.
    LOOP AT names INTO DATA(lv_name).
      DATA(lv_field) = to_upper( lv_name ).
      APPEND |{ lv_field } = @{ cv_host }-{ lv_field }| TO lt_and.
    ENDLOOP.
    result = concat_lines_of( table = lt_and sep = ` AND ` ).

  ENDMETHOD.


  METHOD create_host.

    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE any.

    TRY.
        CREATE DATA result TYPE (entity_name).
      CATCH cx_root.
        CLEAR result.
        RETURN.
    ENDTRY.
    ASSIGN result->* TO <ls_host>.

    LOOP AT values INTO DATA(ls_value).
      DATA(lv_name) = to_upper( ls_value-name ).
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT lv_name OF STRUCTURE <ls_host> TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.
      DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( <lv_value> )->type_kind.
      TRY.
          "a date or time as the JSON model writes it (2024-01-15), a RAW
          "as hex digits - a UUID may come with its dashes
          IF lv_kind = cl_abap_typedescr=>typekind_date
            OR lv_kind = cl_abap_typedescr=>typekind_time
            OR lv_kind = cl_abap_typedescr=>typekind_hex.
            <lv_value> = z2ui5_cl_rap_util=>normalize_value( ls_value-value ).
          ELSE.
            <lv_value> = ls_value-value.
          ENDIF.
        CATCH cx_root.
          CLEAR <lv_value>.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD is_draft_enabled.
    IF eml_available( ) = abap_true AND bdef IS NOT INITIAL.
      result = z2ui5_cl_rap_eml=>is_draft_enabled( bdef ).
    ENDIF.
  ENDMETHOD.


  METHOD run_draft_action.
    IF is_draft_enabled( bdef ) = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.
    result = z2ui5_cl_rap_eml=>run_root_action( bdef     = bdef
                                                action   = action
                                                keys     = root_keys
                                                is_draft = is_draft ).
  ENDMETHOD.


  METHOD write_draft.

    DATA lv_cancel TYPE abap_bool.
    DATA lr_row TYPE REF TO data.
    FIELD-SYMBOLS <ls_row> TYPE any.

    IF get_entity_capabilities( entity_name = entity_name
                                context     = context )-can_update = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.

    CREATE DATA lr_row LIKE row.
    ASSIGN lr_row->* TO <ls_row>.
    <ls_row> = row.
    IF mo_ext IS BOUND.
      mo_ext->before_save( EXPORTING entity_name = entity_name
                                     operation   = `UPDATE`
                                     data        = lr_row
                           CHANGING  messages    = result-messages
                                     cancel      = lv_cancel ).
      IF lv_cancel = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    result = z2ui5_cl_rap_eml=>update_draft( entity_name = entity_name
                                             row         = <ls_row>
                                             original    = original
                                             context     = context ).

  ENDMETHOD.


  METHOD run_action.

    DATA lv_cancel TYPE abap_bool.
    DATA lv_static TYPE abap_bool.
    DATA lr_rows TYPE REF TO data.
    FIELD-SYMBOLS <lt_rows> TYPE ANY TABLE.

    IF eml_available( ) = abap_false
      OR get_entity_capabilities( entity_name = entity_name
                                  context     = context )-is_rap_bo = abap_false.
      APPEND get_text( cs_text-read_only ) TO result-messages.
      RETURN.
    ENDIF.

    "a static action runs without rows, an instance action needs them
    lv_static = is_static_action( entity_name = entity_name
                                  action      = action
                                  context     = context ).
    lr_rows = rows.
    IF lv_static = abap_true AND lr_rows IS NOT BOUND.
      lr_rows = create_entity_table( entity_name ).
    ENDIF.
    IF lr_rows IS NOT BOUND.
      APPEND get_text( cs_text-no_selection ) TO result-messages.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    IF <lt_rows> IS INITIAL AND lv_static = abap_false.
      APPEND get_text( cs_text-no_selection ) TO result-messages.
      RETURN.
    ENDIF.

    "an action the record's feature control or authorization disables
    "is refused, whoever asks (since 2026-10, third round)
    DATA(ls_perm) = get_permissions( entity_name = entity_name
                                     context     = context
                                     rows        = COND #( WHEN lv_static = abap_false THEN lr_rows ) ).
    IF ls_perm-answered = abap_true.
      IF z2ui5_cl_rap_util=>is_permitted( ops  = ls_perm-global-actions
                                          name = action ) = abap_false.
        APPEND |{ get_text( cs_text-not_allowed ) }: { action }| TO result-messages.
        RETURN.
      ENDIF.
      DATA(lv_refused) = 0.
      IF lv_static = abap_false.
        LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_action_row>).
          DATA(ls_row_perm) = z2ui5_cl_rap_util=>get_instance_permissions(
            is_permissions = ls_perm
            keys           = get_keys_of_row( entity_name = entity_name
                                              row         = <ls_action_row> ) ).
          IF z2ui5_cl_rap_util=>is_permitted( ops  = ls_row_perm-actions
                                              name = action ) = abap_false.
            lv_refused = lv_refused + 1.
          ENDIF.
        ENDLOOP.
      ENDIF.
      IF lv_refused > 0.
        APPEND |{ get_text( cs_text-not_allowed ) }: { action } ({ lv_refused })| TO result-messages.
        RETURN.
      ENDIF.
    ENDIF.

    IF mo_ext IS BOUND.
      mo_ext->before_save( EXPORTING entity_name = entity_name
                                     operation   = |ACTION:{ action }|
                                     data        = lr_rows
                           CHANGING  messages    = result-messages
                                     cancel      = lv_cancel ).
      IF lv_cancel = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    result = z2ui5_cl_rap_eml=>execute_action( entity_name = entity_name
                                               action      = action
                                               rows        = <lt_rows>
                                               param       = param
                                               context     = context
                                               is_static   = lv_static
                                               isolated    = xsdbool( to_upper( invocation_grouping ) CS `ISOLATED` ) ).

    IF result-success = abap_true AND mo_ext IS BOUND.
      mo_ext->after_save( entity_name = entity_name
                          operation   = |ACTION:{ action }|
                          data        = lr_rows ).
    ENDIF.

  ENDMETHOD.


  METHOD is_static_action.

    DATA lr_table TYPE REF TO data.
    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lt_table> TYPE STANDARD TABLE.

    IF eml_available( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_bdef) = COND string( WHEN context-bdef IS NOT INITIAL THEN to_upper( context-bdef ) ELSE lv_entity ).
    DATA(lv_type) = |\\BDEF={ lv_bdef }\\ENTITY={ lv_entity }\\ACTION={ to_upper( action ) }\\TYPE=IMPORTING|.
    TRY.
        CREATE DATA lr_table TYPE (lv_type).
        ASSIGN lr_table->* TO <lt_table>.
        APPEND INITIAL LINE TO <lt_table> ASSIGNING FIELD-SYMBOL(<ls_line>).
        DATA(lo_line) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( <ls_line> ) ).
        LOOP AT lo_line->components INTO DATA(ls_comp).
          APPEND CONV string( ls_comp-name ) TO lt_names.
        ENDLOOP.
        result = z2ui5_cl_rap_util=>is_static_action_line( lt_names ).
      CATCH cx_root.
        result = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD is_hidden_by_annotation.

    FIELD-SYMBOLS <lv_value> TYPE any.

    IF value IS INITIAL.
      RETURN.
    ENDIF.
    IF to_upper( value ) = `TRUE`.
      result = abap_true.
      RETURN.
    ENDIF.
    IF row IS NOT SUPPLIED.
      RETURN.
    ENDIF.
    "a path: the field of the record decides
    ASSIGN COMPONENT value OF STRUCTURE row TO <lv_value>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_text) = to_upper( condense( |{ <lv_value> }| ) ).
    result = xsdbool( lv_text = `X` OR lv_text = `TRUE` OR lv_text = `1` ).

  ENDMETHOD.


  METHOD get_action_button_type.

    FIELD-SYMBOLS <lv_value> TYPE any.

    DATA(lv_crit) = is_action-criticality.
    IF lv_crit IS INITIAL.
      result = `Default`.
      RETURN.
    ENDIF.
    "a field holds the criticality - only a record can tell
    IF lv_crit CN `0123456789` AND lv_crit <> `POSITIVE` AND lv_crit <> `NEGATIVE`
      AND lv_crit <> `CRITICAL` AND lv_crit <> `NEUTRAL`.
      CLEAR lv_crit.
      IF row IS SUPPLIED.
        ASSIGN COMPONENT is_action-criticality OF STRUCTURE row TO <lv_value>.
        IF sy-subrc = 0.
          lv_crit = |{ <lv_value> }|.
        ENDIF.
      ENDIF.
    ENDIF.
    result = z2ui5_cl_rap_util=>criticality_button_type( lv_crit ).

  ENDMETHOD.


  METHOD get_action_entries.

    "an action of a group sits in the group's menu, the others alone
    LOOP AT it_actions INTO DATA(ls_action).
      IF ls_action-group_id IS NOT INITIAL
        AND line_exists( it_groups[ id = ls_action-group_id source = ls_action-source ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( position = ls_action-position action = ls_action ) TO result.
    ENDLOOP.
    LOOP AT it_groups INTO DATA(ls_group).
      DATA(ls_entry) = VALUE ty_s_action_entry( position = ls_group-position group = ls_group ).
      LOOP AT it_actions INTO ls_action WHERE group_id = ls_group-id AND source = ls_group-source.
        APPEND ls_action TO ls_entry-items.
      ENDLOOP.
      IF ls_entry-items IS NOT INITIAL.
        APPEND ls_entry TO result.
      ENDIF.
    ENDLOOP.
    SORT result STABLE BY position.

  ENDMETHOD.


  METHOD create_action_parameter.

    DATA lr_table TYPE REF TO data.
    FIELD-SYMBOLS <lt_table> TYPE STANDARD TABLE.

    IF eml_available( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_entity) = to_upper( entity_name ).
    DATA(lv_bdef) = COND string( WHEN context-bdef IS NOT INITIAL THEN to_upper( context-bdef ) ELSE lv_entity ).
    DATA(lv_type) = |\\BDEF={ lv_bdef }\\ENTITY={ lv_entity }\\ACTION={ to_upper( action ) }\\TYPE=IMPORTING|.
    TRY.
        CREATE DATA lr_table TYPE (lv_type).
        ASSIGN lr_table->* TO <lt_table>.
        APPEND INITIAL LINE TO <lt_table> ASSIGNING FIELD-SYMBOL(<ls_line>).
        ASSIGN COMPONENT `%PARAM` OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<ls_param>).
        IF sy-subrc = 0.
          CREATE DATA result LIKE <ls_param>.
        ENDIF.
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD show_messages.

    IF messages IS INITIAL.
      RETURN.
    ENDIF.
    client->message_box_display( text = concat_lines_of( table = messages sep = cl_abap_char_utilities=>newline )
                                 type = type ).

  ENDMETHOD.


  METHOD normalize_key_value.
    result = z2ui5_cl_rap_util=>normalize_value( val ).
  ENDMETHOD.


  METHOD get_permissions.
    IF eml_available( ) = abap_false
      OR get_capabilities( entity_name = entity_name
                           context     = context )-is_rap_bo = abap_false.
      RETURN.
    ENDIF.
    result = z2ui5_cl_rap_eml=>get_permissions( entity_name = entity_name
                                                context     = context
                                                rows        = rows ).
  ENDMETHOD.


  METHOD get_row_permissions.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    DATA(lr_rows) = create_entity_table( entity_name ).
    IF lr_rows IS BOUND.
      ASSIGN lr_rows->* TO <lt_rows>.
      APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      MOVE-CORRESPONDING row TO <ls_row>.
    ENDIF.
    result = z2ui5_cl_rap_util=>get_instance_permissions(
      is_permissions = get_permissions( entity_name = entity_name
                                        context     = context
                                        rows        = lr_rows )
      keys           = get_keys_of_row( entity_name = entity_name
                                        row         = row ) ).

  ENDMETHOD.


  METHOD get_keys_of_row.

    FIELD-SYMBOLS <lv_key> TYPE any.
    LOOP AT z2ui5_cl_rap_util=>get_key_fields( entity_name ) INTO DATA(lv_key).
      UNASSIGN <lv_key>.
      ASSIGN COMPONENT lv_key OF STRUCTURE row TO <lv_key>.
      IF <lv_key> IS ASSIGNED.
        APPEND VALUE #( name = to_upper( lv_key ) value = |{ <lv_key> }| ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_drafts.
    IF eml_available( ) = abap_false OR rows IS NOT BOUND.
      RETURN.
    ENDIF.
    result = z2ui5_cl_rap_eml=>read_instances( entity_name = entity_name
                                               context     = context
                                               rows        = rows
                                               is_draft    = abap_true ).
  ENDMETHOD.


  METHOD get_etag_field.
    result = z2ui5_cl_rap_util=>get_etag_field( z2ui5_cl_rap_util=>read_entity( entity_name )-fields ).
  ENDMETHOD.


  METHOD check_etag.

    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lv_seen> TYPE any.
    FIELD-SYMBOLS <lv_now> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    result = abap_true.
    DATA(lv_field) = get_etag_field( entity_name ).
    IF lv_field IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT lv_field OF STRUCTURE row TO <lv_seen>.
    IF sy-subrc <> 0 OR <lv_seen> IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_keys) = get_keys_of_row( entity_name = entity_name
                                     row         = row ).
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_keys INTO DATA(ls_key).
      APPEND ls_key-name TO lt_names.
    ENDLOOP.

    DATA(lr_rows) = select_rows( entity_name = entity_name
                                 where       = build_key_condition( lt_names )
                                 max_rows    = 1
                                 host        = create_host( entity_name = entity_name
                                                            values      = lt_keys ) ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_now>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT lv_field OF STRUCTURE <ls_now> TO <lv_now>.
    IF sy-subrc = 0 AND <lv_now> <> <lv_seen>.
      result = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD check_rap_write.

    DATA lt_fields TYPE string_table.
    FIELD-SYMBOLS <lv_new> TYPE any.
    FIELD-SYMBOLS <lv_old> TYPE any.

    DATA(ls_perm) = get_row_permissions( entity_name = entity_name
                                         context     = context
                                         row         = original ).
    IF ( operation = `UPDATE` AND ls_perm-can_update = abap_false )
      OR ( operation = `DELETE` AND ls_perm-can_delete = abap_false ).
      APPEND get_text( cs_text-not_allowed ) TO result.
      RETURN.
    ENDIF.

    IF operation = `UPDATE`.
      "a field its field control makes read-only is not changed
      LOOP AT ls_perm-fields INTO DATA(ls_field)
        WHERE read_only = abap_true OR read_only_update = abap_true.
        UNASSIGN: <lv_new>, <lv_old>.
        ASSIGN COMPONENT ls_field-name OF STRUCTURE row TO <lv_new>.
        ASSIGN COMPONENT ls_field-name OF STRUCTURE original TO <lv_old>.
        IF <lv_new> IS ASSIGNED AND <lv_old> IS ASSIGNED AND <lv_new> <> <lv_old>.
          APPEND ls_field-name TO lt_fields.
        ENDIF.
      ENDLOOP.
      IF lt_fields IS NOT INITIAL.
        APPEND |{ get_text( cs_text-field_read_only ) }: { concat_lines_of( table = lt_fields sep = `, ` ) }| TO result.
        RETURN.
      ENDIF.
    ENDIF.

    "a draft keeps the record locked while it is edited - without one, the
    "record as the user saw it is compared with the stored one
    DATA(lv_bdef) = COND string( WHEN context-bdef IS NOT INITIAL THEN context-bdef ELSE entity_name ).
    IF is_draft_enabled( lv_bdef ) = abap_false
      AND check_etag( entity_name = entity_name
                      row         = original ) = abap_false.
      APPEND get_text( cs_text-changed ) TO result.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
