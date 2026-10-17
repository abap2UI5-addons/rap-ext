"! Object page for a single record of a CDS entity - header, status
"! attributes, sections and edit/save/delete all come from the
"! annotations (see README).
"!
"! Sections follow @UI.facet: #COLLECTION facets become sections with a
"! subsection per child facet, #FIELDGROUP_REFERENCE and
"! #IDENTIFICATION_REFERENCE become forms, #LINEITEM_REFERENCE becomes a
"! table of the associated entity. The annotations name the association,
"! not its target entity - get_association_target( ) asks the extension
"! (z2ui5_if_rap_ext~resolve_association) first, then the association as
"! the entity's DDL source declares it (since 2026-10), and a facet without
"! a target is left out. The rows of such a table are the ones the
"! association's ON condition selects.
"!
"! A record of a child entity carries its place in the business object
"! (context): it is written through the BDEF of the root, and a table of a
"! composition offers Create - a create by association under this record.
"!
"! A record of a draft-enabled business object is edited in a draft of its
"! own (since 2026-10): Edit creates it (committed), Save writes the changes
"! into it and activates it - a refused activation keeps the draft and the
"! page in edit mode - and Cancel or leaving the page discards it. A draft
"! that exists already is the business object's message - one of the
"! user's own can be discarded.
"!
"! Writing goes through z2ui5_cl_rap_floorplan->write_row( ): RAP (EML) for
"! a business object, ABAP SQL for a table. A CDS view that is neither is
"! read-only, and the page offers no Edit or Delete for it - up to 2026-09
"! it offered both and every save ended in an error.
"!
"! The escape hatch is plain inheritance: the class is deliberately not
"! FINAL and every rendering and event step is a protected method a
"! subclass can redefine with ordinary abap2UI5 view code. Events the
"! floorplan does not know are routed to on_event, so a subclass adds its
"! own actions the same way any abap2UI5 app handles them.
CLASS z2ui5_cl_rap_object_page DEFINITION
  PUBLIC
  INHERITING FROM z2ui5_cl_rap_floorplan
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    CONSTANTS:
      BEGIN OF cs_event,
        back       TYPE string VALUE `BACK`,
        edit       TYPE string VALUE `EDIT`,
        save       TYPE string VALUE `SAVE`,
        cancel     TYPE string VALUE `CANCEL`,
        delete     TYPE string VALUE `DELETE`,
        value_help TYPE string VALUE `VALUE_HELP`,
        action     TYPE string VALUE `ACTION`,
        child_row  TYPE string VALUE `CHILD_ROW`,
        "added 2026-10
        child_create   TYPE string VALUE `CHILD_CREATE`,
        draft_decision TYPE string VALUE `DRAFT_DECISION`,
        intent         TYPE string VALUE `INTENT`,
        copy_link      TYPE string VALUE `COPY_LINK`,
        "added 2026-10, third round: an action of a child table - args
        "the section's component and the action
        child_action   TYPE string VALUE `CHILD_ACTION`,
        "the answer to "keep or discard your draft?" when leaving the page
        leave_decision TYPE string VALUE `LEAVE_DECISION`,
        "added 2026-10, third round (object page): the MultiInput of a 1:n
        "child - a token typed (arg the component), deleted (the component,
        "the token's key), its value help (the component); a row of a child
        "table added (the component), deleted (the component, its keys), a
        "cell changed (the component); a field whose change updates the
        "draft at once (side effects)
        path_token_add    TYPE string VALUE `PATH_TOKEN_ADD`,
        path_token_delete TYPE string VALUE `PATH_TOKEN_DELETE`,
        path_value_help   TYPE string VALUE `PATH_VALUE_HELP`,
        child_row_add     TYPE string VALUE `CHILD_ROW_ADD`,
        child_row_delete  TYPE string VALUE `CHILD_ROW_DELETE`,
        child_cell_change TYPE string VALUE `CHILD_CELL_CHANGE`,
        side_effect       TYPE string VALUE `SIDE_EFFECT`,
      END OF cs_event.

    " the columns of a row of a child table beside the entity's own (added
    " 2026-10, third round): the row may be changed, deleted, and it is
    " new - not written yet, a record without draft writes it on Save.
    " Set on the server from the permissions - what the browser sends back
    " in them decides nothing
    CONSTANTS:
      BEGIN OF cs_row_flag,
        updatable TYPE string VALUE `ZZUPDKZ`,
        deletable TYPE string VALUE `ZZDELKZ`,
        new       TYPE string VALUE `ZZNEWKZ`,
      END OF cs_row_flag.

    " a token of the MultiInput of a 1:n child: key - the child's key
    " values joined by cv_key_separator, a token not written yet + and its
    " value - and text, the child's value
    TYPES:
      BEGIN OF ty_s_token,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_token.

    TYPES ty_t_token TYPE STANDARD TABLE OF ty_s_token WITH EMPTY KEY.

    " what the MultiInput of a 1:n child binds: the text typed and the
    " tokens (a component PATH_n of mr_child_rows)
    TYPES:
      BEGIN OF ty_s_path_value,
        input  TYPE string,
        tokens TYPE ty_t_token,
      END OF ty_s_path_value.

    CONSTANTS cv_key_separator TYPE string VALUE `|`.

    "! val: the record, any structure typed after the CDS entity. Or,
    "! instead of val, cds_view_name and keys: the page reads the record
    "! itself (and can then be opened from a link or a bookmark)
    METHODS constructor
      IMPORTING
        val           TYPE data OPTIONAL
        title         TYPE string OPTIONAL
        editable      TYPE abap_bool DEFAULT abap_false
        is_create     TYPE abap_bool DEFAULT abap_false
        cds_view_name TYPE clike OPTIONAL
        keys          TYPE ty_t_name_value OPTIONAL
        "the record's place in a RAP business object - set by the page of
        "its parent for a child entity (added 2026-10)
        context       TYPE ty_s_rap_context OPTIONAL
          PREFERRED PARAMETER val.

    "! Check if user saved (for caller to detect on return)
    METHODS was_saved
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Get the saved data reference
    METHODS result
      RETURNING
        VALUE(result) TYPE REF TO data.

    DATA ms_data TYPE REF TO data.
    DATA mv_editable TYPE abap_bool.

    "! the rows of the #LINEITEM_REFERENCE sections - one component per
    "! section (SECTION_1, ...), each a table of the associated entity with
    "! the columns of cs_row_flag; since 2026-10 (third round) also one
    "! component per MultiInput of a 1:n child (PATH_1, ...), a
    "! ty_s_path_value
    DATA mr_child_rows TYPE REF TO data.

  PROTECTED SECTION.
    DATA mv_title     TYPE string.
    DATA ms_entity    TYPE z2ui5_cl_rap_util=>ty_s_entity_info.
    DATA mv_is_create TYPE abap_bool.
    DATA mv_saved     TYPE abap_bool.

    TYPES:
      BEGIN OF ty_s_section,
        title       TYPE string,
        field_group TYPE string,
        "added 2026-09 - appended so the existing layout stays as it was
        "the facet id; parent_id is the #COLLECTION the section belongs to
        id          TYPE string,
        parent_id   TYPE string,
        "FIELDGROUP (also the default), IDENTIFICATION, LINEITEM, COLLECTION
        type        TYPE string,
        association TYPE string,
      END OF ty_s_section.

    TYPES ty_t_section TYPE STANDARD TABLE OF ty_s_section WITH DEFAULT KEY.

    " a #LINEITEM_REFERENCE section with its entity
    TYPES:
      BEGIN OF ty_s_child,
        section_id TYPE string,
        component  TYPE string,
        entity     TYPE z2ui5_cl_rap_util=>ty_s_entity_info,
        "added 2026-10: the association, and whether a row can be created
        "under this record (a create by association)
        association TYPE string,
        can_create  TYPE abap_bool,
        "added 2026-10, third round: the toolbar actions of the child's
        "@UI.lineItem - on the selected rows of the table
        actions     TYPE z2ui5_cl_rap_util=>ty_t_action,
        "the actions GET PERMISSIONS disables for the child entity
        disabled_actions TYPE string_table,
        "rows can be changed and deleted (the instance's own permission is
        "the row's cs_row_flag), and the table is read-only - the change
        "documents (added 2026-10, third round)
        can_update  TYPE abap_bool,
        can_delete  TYPE abap_bool,
        read_only   TYPE abap_bool,
      END OF ty_s_child.

    TYPES ty_t_child TYPE STANDARD TABLE OF ty_s_child WITH DEFAULT KEY.

    " the MultiInput of a 1:n child - an entry whose value is an
    " association path (added 2026-10, third round): its component in
    " mr_child_rows, the entry, the child entity and what may be done
    TYPES:
      BEGIN OF ty_s_path_child,
        component  TYPE string,
        field      TYPE z2ui5_cl_rap_util=>ty_s_path_field,
        entity     TYPE z2ui5_cl_rap_util=>ty_s_entity_info,
        can_create TYPE abap_bool,
        can_delete TYPE abap_bool,
      END OF ty_s_path_child.

    TYPES ty_t_path_child TYPE STANDARD TABLE OF ty_s_path_child WITH EMPTY KEY.

    " a write of a child held back until Save - a record without draft
    " (added 2026-10, third round): the component of the table or the
    " MultiInput, CREATE (of a token: value) or DELETE (keys)
    TYPES:
      BEGIN OF ty_s_pending,
        component TYPE string,
        operation TYPE string,
        keys      TYPE ty_t_name_value,
        value     TYPE string,
      END OF ty_s_pending.

    TYPES ty_t_pending TYPE STANDARD TABLE OF ty_s_pending WITH EMPTY KEY.

    " the ids of the sections the page adds itself: the change
    " information and the change documents
    CONSTANTS:
      BEGIN OF cs_section_id,
        change_info TYPE string VALUE `ZZCHANGEINFO`,
        change_docs TYPE string VALUE `ZZCHANGEDOCS`,
      END OF cs_section_id.

    DATA ms_data_backup TYPE REF TO data.
    DATA mv_entity_name TYPE string.
    DATA ms_caps TYPE ty_s_capabilities.
    DATA mt_child TYPE ty_t_child.
    DATA mt_keys TYPE ty_t_name_value.
    "! an action waiting for its parameter dialog to return
    DATA mv_pending_action TYPE string.
    "! the record's place in a RAP business object (see the constructor)
    DATA ms_context TYPE ty_s_rap_context.
    "! the messages of the last save - their fields are marked in edit mode
    DATA mt_messages TYPE ty_t_message.
    "! the page edits a draft of the business object (committed, kept
    "! between roundtrips)
    DATA mv_draft TYPE abap_bool.
    "! the child table (its component) of the action waiting for its
    "! parameter dialog - empty for an action of this record (added
    "! 2026-10, third round)
    DATA mv_pending_child TYPE string.
    "! the last action created a record and its object page was called -
    "! nothing else is rendered in this roundtrip
    DATA mv_opened_created TYPE abap_bool.
    "! the permissions of the record - global, static and its own feature
    "! control and authorization (load_permissions; added 2026-10, third
    "! round)
    DATA ms_perm TYPE ty_s_perm_set.
    "! the draft of the record: the user's own (the page edits it) or
    "! another user's, who holds the lock (read_draft_status)
    DATA ms_draft TYPE z2ui5_cl_rap_util=>ty_s_draft_status.
    "! the MultiInputs of 1:n children (load_child_rows; added 2026-10,
    "! third round)
    DATA mt_path TYPE ty_t_path_child.
    "! the writes of children held back until Save
    DATA mt_pending TYPE ty_t_pending.
    "! the MultiInput (its component) whose value help was called
    DATA mv_pending_path TYPE string.

    "! subclass hook - called for every event the floorplan itself does
    "! not handle, exactly like the event branch of a hand-written app
    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! page skeleton - delegates to render_header_title,
    "! render_header_content and render_sections
    METHODS render_page
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS render_header_title
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    "! Edit / Save / Cancel / Delete buttons and the actions
    METHODS render_actions
      IMPORTING
        io_actions TYPE REF TO z2ui5_cl_ui5_view_builder
        client     TYPE REF TO z2ui5_if_client.

    "! key attributes + data points
    METHODS render_header_content
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    METHODS render_sections
      IMPORTING
        io_op  TYPE REF TO z2ui5_cl_ui5_view_builder
        client TYPE REF TO z2ui5_if_client.

    METHODS get_sections
      RETURNING
        VALUE(result) TYPE ty_t_section.

    "! the form of the fields of one field group
    METHODS render_section_form
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_ui5_view_builder
        iv_group  TYPE string
        client    TYPE REF TO z2ui5_if_client.

    "! the content of one (sub)section, by its type
    METHODS render_section_content
      IMPORTING
        io_parent  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section TYPE ty_s_section
        client     TYPE REF TO z2ui5_if_client.

    "! a form of it_fields - inputs in edit mode, texts otherwise; it_paths
    "! the MultiInputs of 1:n children behind them (added 2026-10, third
    "! round)
    METHODS render_section_fields
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_ui5_view_builder
        it_fields TYPE z2ui5_cl_rap_util=>ty_t_field_info
        client    TYPE REF TO z2ui5_if_client
        it_paths  TYPE ty_t_path_child OPTIONAL.

    "! the table of a #LINEITEM_REFERENCE section
    METHODS render_section_table
      IMPORTING
        io_parent  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section TYPE ty_s_section
        client     TYPE REF TO z2ui5_if_client.

    "! the fields of @UI.identification, by position - qualifier (added
    "! 2026-10, third round) the entries of that qualifier, with their
    "! labels; the unqualified ones fall back to the first visible fields
    METHODS get_identification_fields
      IMPORTING
        qualifier     TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the actions of a section: a qualified @UI.identification's at its
    "! #IDENTIFICATION_REFERENCE, a field group's #FOR_ACTION entries at
    "! its #FIELDGROUP_REFERENCE - a toolbar above the content
    METHODS render_section_actions
      IMPORTING
        io_parent  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section TYPE ty_s_section
        client     TYPE REF TO z2ui5_if_client.

    "! the actions this page offers on its record: @UI.identification
    "! (unqualified: the header, qualified: a section) and @UI.fieldGroup
    METHODS get_record_actions
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_action.

    "! an action of a child table on its selected rows (cs_event-child_action)
    METHODS on_child_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! run the pending action of the child table mv_pending_child
    METHODS execute_child_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        param  TYPE REF TO data OPTIONAL.

    "! the buttons of it_actions, by position (get_action_entries): a
    "! button per action, its criticality its type, and a MenuButton per
    "! action group with its actions as items. The press is event with
    "! the arguments args_before and the action's name; row decides a
    "! criticality that names a field (added 2026-10, third round)
    METHODS render_action_buttons
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        it_actions   TYPE z2ui5_cl_rap_util=>ty_t_action
        it_groups    TYPE z2ui5_cl_rap_util=>ty_t_action_group OPTIONAL
        client       TYPE REF TO z2ui5_if_client
        event        TYPE string
        args_before  TYPE string_table OPTIONAL
        row          TYPE data OPTIONAL
        "the actions shown disabled (feature control) - added 2026-10,
        "third round
        disabled     TYPE string_table OPTIONAL.

    "! the object page of the record an action created (its MAPPED keys)
    METHODS open_created
      IMPORTING
        client      TYPE REF TO z2ui5_if_client
        entity_name TYPE string
        keys        TYPE ty_t_name_value
        context     TYPE ty_s_rap_context OPTIONAL.

    METHODS get_datapoint_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    METHODS get_criticality_state
      IMPORTING
        iv_crit_value TYPE i
      RETURNING
        VALUE(result) TYPE string.

    METHODS get_crit_value
      IMPORTING
        iv_field      TYPE string
      RETURNING
        VALUE(result) TYPE i.

    METHODS get_field_value
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    METHODS format_value
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    METHODS save_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS delete_data
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! read the record again by its keys - after a save, and when the page
    "! was opened with keys instead of a record
    METHODS reload_data.

    "! the CDS entity an association leads to - the extension answers it;
    "! redefine it to answer it in a subclass
    METHODS get_association_target
      IMPORTING
        association   TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! read the rows of every #LINEITEM_REFERENCE section into
    "! mr_child_rows
    METHODS load_child_rows.

    "! a RAP action of @UI.identification on this record
    METHODS on_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS execute_action
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        param  TYPE REF TO data OPTIONAL.

    "! a row of a #LINEITEM_REFERENCE table was pressed - its object page
    METHODS on_child_row
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the header content from the @UI.facet entries with purpose #HEADER:
    "! a #DATAPOINT_REFERENCE is a status, a #FIELDGROUP_REFERENCE a block of
    "! label/value pairs
    METHODS render_header_facets
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        client       TYPE REF TO z2ui5_if_client.

    "! the value of a field as the page displays it - with its text
    "! by @ObjectModel.text.element and @UI.textArrangement
    METHODS get_display_text
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE string.

    "! the labels of the mandatory fields that are still empty
    METHODS get_missing_fields
      RETURNING
        VALUE(result) TYPE string_table.

    "! a key field of the record is still initial
    METHODS has_initial_key
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the BDEF the record is written through - the root's for a child, the
    "! entity's own for the root of a business object, empty otherwise
    METHODS get_bdef
      RETURNING
        VALUE(result) TYPE string.

    "! the keys of the root instance of the business object
    METHODS get_root_keys
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! Edit of a draft business object: a draft of the root (committed) -
    "! abap_false when the business object refused it, which the user sees
    METHODS start_draft
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Save in draft mode: the changes into the draft, then Activate - when
    "! the activation is refused the draft keeps the changes and the page
    "! stays in edit mode
    METHODS save_draft
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the link to this record: through the start app the extension names
    "! (z2ui5_if_rap_ext~get_start_app) - a link that outlives the draft -
    "! else the link of the app's current state
    METHODS get_link
      IMPORTING
        client        TYPE REF TO z2ui5_if_client
      RETURNING
        VALUE(result) TYPE string.

    "! the key fields of the record with their values
    METHODS get_own_keys
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the context of a record of the association - the BDEF and root of
    "! this record, and this record as the parent of a create
    METHODS get_child_context
      IMPORTING
        association   TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_rap_context.

    "! the condition of the child rows of a #LINEITEM_REFERENCE section:
    "! the field pairs of the association's ON condition, else the keys of
    "! this record under the same names - et_values are the values of the
    "! child's fields
    METHODS get_child_filter
      IMPORTING
        is_child  TYPE ty_s_child
      EXPORTING
        et_values TYPE ty_t_name_value.

    "! the Create of a #LINEITEM_REFERENCE table - an object page in create
    "! mode for a new child of this record
    METHODS on_child_create
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a created record whose key the business object assigned only on save
    "! (late numbering): the newest record created by this user since
    "! since_ts / since_utc, found by its @Semantics.user.createdBy
    "! and @Semantics.systemDateTime.createdAt fields - abap_false when the
    "! entity has neither or nothing was found
    METHODS find_created_record
      IMPORTING
        since_ts      TYPE timestampl
        since_utc     TYPE utclong
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the permissions of the record into ms_perm - what GET PERMISSIONS
    "! answers for it (on create: the global ones). Added 2026-10, third
    "! round, like the methods below
    METHODS load_permissions.

    "! is_field as it is edited: read-only and mandatory by the annotations,
    "! the static and the instance field control (ms_perm) and whether the
    "! record is created - z2ui5_cl_rap_util=>get_field_control
    METHODS get_field_for_edit
      IMPORTING
        is_field      TYPE z2ui5_cl_rap_util=>ty_s_field_info
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_s_field_info.

    "! a record opened in edit mode (constructor editable, a link with
    "! mode=edit): the edit mode stays only where Edit would be allowed -
    "! not locked by another user's draft, updatable, not hidden by the
    "! annotation @UI.updateHidden - and a draft business object starts its draft
    "! (start_draft; an existing draft asks what to do with it). Else the
    "! record shows in display mode (added 2026-10, third round)
    METHODS apply_start_mode
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the draft of the record, read back (READ ENTITIES with %is_draft) -
    "! unbound when there is none or it cannot be read
    METHODS read_own_draft
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! whose draft the record has (ms_draft): the user's own, another
    "! user's (who changed it last, @Semantics.user.lastChangedBy), none
    METHODS read_draft_status.

    "! continue the user's own draft: its data on the page, edit mode -
    "! abap_false when there is no draft to read
    METHODS resume_draft
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! the strip above the header: the record is a draft, or locked by
    "! another user
    METHODS render_draft_info
      IMPORTING
        io_container TYPE REF TO z2ui5_cl_ui5_view_builder
        client       TYPE REF TO z2ui5_if_client.

    "! the actions of it_actions that ms_perm disables - their buttons are
    "! shown disabled
    METHODS get_disabled_actions
      IMPORTING
        it_actions    TYPE z2ui5_cl_rap_util=>ty_t_action
      RETURNING
        VALUE(result) TYPE string_table.

    "! the sections an extension adds, with their place
    "! (z2ui5_if_rap_ext~get_custom_sections) - redefine it to add them in
    "! a subclass (added 2026-10, third round, like the methods below)
    METHODS get_custom_sections
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_custom_section.

    "! one section of render_sections: an ObjectPageSection with one
    "! subsection, or with one per facet of a #COLLECTION (it_sections)
    METHODS render_section
      IMPORTING
        io_sections TYPE REF TO z2ui5_cl_ui5_view_builder
        is_section  TYPE ty_s_section
        it_sections TYPE ty_t_section
        client      TYPE REF TO z2ui5_if_client.

    "! a section of get_custom_sections: its content comes from
    "! z2ui5_if_rap_ext~extend_view at cs_spot-custom_section
    METHODS render_custom_section
      IMPORTING
        io_sections TYPE REF TO z2ui5_cl_ui5_view_builder
        is_custom   TYPE z2ui5_cl_rap_util=>ty_s_custom_section
        client      TYPE REF TO z2ui5_if_client.

    "! the fields whose change updates the draft at once (side effects):
    "! * (every field) for a business object with draft, else none - then
    "! the extension (z2ui5_if_rap_ext~get_side_effect_fields)
    METHODS get_side_effect_fields
      RETURNING
        VALUE(result) TYPE string_table.

    "! a field marked for get_side_effect_fields changed: its value into
    "! the draft, the draft read back - with what its determinations
    "! changed - and the page with the children shown again
    METHODS on_side_effect
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the fields of the change information (@Semantics.user.createdBy,
    "! ...): z2ui5_cl_rap_util=>get_admin_fields - none when one of them is
    "! in a field group or the identification already, or on create
    METHODS get_admin_fields
      RETURNING
        VALUE(result) TYPE z2ui5_cl_rap_util=>ty_t_field_info.

    "! the form of the change information - read-only
    METHODS render_admin_fields
      IMPORTING
        io_parent TYPE REF TO z2ui5_cl_ui5_view_builder
        client    TYPE REF TO z2ui5_if_client.

    "! the entity of the change documents and its filter
    "! (z2ui5_if_rap_ext~get_change_documents) - et_filter names its fields
    "! with the record's value
    METHODS get_change_documents
      EXPORTING
        ev_entity TYPE string
        et_filter TYPE ty_t_name_value.

    "! the MultiInputs of the entries of source and qualifier whose value
    "! is an association path
    METHODS get_path_children
      IMPORTING
        source        TYPE string
        qualifier     TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_path_child.

    "! label and MultiInput of a 1:n child in a form: its values as tokens,
    "! in edit mode a token typed or chosen in its value help creates a
    "! child, a token deleted deletes one
    METHODS render_path_input
      IMPORTING
        io_form  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_path  TYPE ty_s_path_child
        client   TYPE REF TO z2ui5_if_client.

    "! the MultiInput's text (or value) as a new child - created in the
    "! draft at once, held back until Save without one
    METHODS add_path_token
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        component TYPE string
        value     TYPE string OPTIONAL.

    "! a token deleted - its child deleted in the draft at once, held back
    "! until Save without one
    METHODS delete_path_token
      IMPORTING
        client    TYPE REF TO z2ui5_if_client
        component TYPE string
        key       TYPE string.

    "! the child of is_child or is_path as a table of its section - the
    "! one to read and write it through
    METHODS get_path_as_child
      IMPORTING
        is_path       TYPE ty_s_path_child
      RETURNING
        VALUE(result) TYPE ty_s_child.

    "! the key of a token: the values of keys joined by cv_key_separator
    METHODS get_token_key
      IMPORTING
        it_keys       TYPE string_table
        row           TYPE data
      RETURNING
        VALUE(result) TYPE string.

    "! the key values of a token's key, by the key fields it_keys
    METHODS get_token_keys
      IMPORTING
        it_keys       TYPE string_table
        key           TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    "! the rows of is_child below this record (it_values the child's fields
    "! that point at it): of the draft when the page edits one
    "! (read_draft_children), else read - a table of the entity with the
    "! selection column
    METHODS read_child_rows
      IMPORTING
        is_child      TYPE ty_s_child
        it_values     TYPE ty_t_name_value
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the table rows with the columns of cs_row_flag, set from the
    "! permissions of the child - GET PERMISSIONS per instance, the
    "! annotations @UI.updateHidden and @UI.deleteHidden per row - and the
    "! child's static field control into the read-only of its fields
    METHODS add_row_flags
      IMPORTING
        rows          TYPE REF TO data
      CHANGING
        cs_child      TYPE ty_s_child
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! the cell of a child table in edit mode - an input for a field the
    "! row may change (cs_row_flag), a key only on a new row
    METHODS render_child_cell
      IMPORTING
        io_cells  TYPE REF TO z2ui5_cl_ui5_view_builder
        is_field  TYPE z2ui5_cl_rap_util=>ty_s_field_info
        is_child  TYPE ty_s_child
        client    TYPE REF TO z2ui5_if_client.

    "! a row of a child table added: in the draft at once, without one a
    "! new row written on Save
    METHODS on_child_row_add
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! a row of a child table deleted: in the draft at once, without one
    "! held back until Save
    METHODS on_child_row_delete
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    "! the record of a child row as it is stored - the draft's when
    "! in_draft is set; unbound when there is none
    METHODS get_child_original
      IMPORTING
        is_child      TYPE ty_s_child
        row           TYPE data
        in_draft      TYPE abap_bool
      RETURNING
        VALUE(result) TYPE REF TO data.

    "! write the changes of the children: the held back writes, the new and
    "! changed rows of the child tables (in_draft: into the draft) -
    "! checked like every write, messages of all of them
    METHODS write_children
      IMPORTING
        in_draft      TYPE abap_bool
      RETURNING
        VALUE(result) TYPE ty_s_result.

  PRIVATE SECTION.

ENDCLASS.



CLASS z2ui5_cl_rap_object_page IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_floorplan = cs_floorplan-object_page.
    IF val IS SUPPLIED.
      CREATE DATA ms_data LIKE val.
      ms_data->* = val.
    ELSEIF cds_view_name IS NOT INITIAL.
      mv_entity_name = to_upper( cds_view_name ).
      CREATE DATA ms_data TYPE (mv_entity_name).
    ENDIF.
    IF cds_view_name IS NOT INITIAL.
      mv_entity_name = to_upper( cds_view_name ).
    ENDIF.
    mt_keys = keys.
    ms_context = context.
    mv_title = title.
    mv_editable = editable.
    mv_is_create = is_create.
  ENDMETHOD.


  METHOD was_saved.
    result = mv_saved.
  ENDMETHOD.


  METHOD result.
    result = ms_data.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).
      IF ms_data IS NOT BOUND.
        "why the read failed, where it is known (a query provider's error)
        client->message_box_display( text = COND #( WHEN mv_read_error IS INITIAL
                                                    THEN get_text( cs_text-load_error )
                                                    ELSE get_load_error( mv_entity_name ) )
                                     type = `error` ).
        client->nav_app_leave( ).
        RETURN.
      ENDIF.
      IF mv_entity_name IS INITIAL.
        DATA(lo_datadescr) = cl_abap_datadescr=>describe_by_data( ms_data->* ).
        mv_entity_name = lo_datadescr->get_relative_name( ).
      ENDIF.
      ms_entity = z2ui5_cl_rap_util=>read_entity( mv_entity_name ).
      adjust_entity( CHANGING cs_entity = ms_entity ).
      ms_caps = get_entity_capabilities( entity_name = mv_entity_name
                                         context     = ms_context ).

      "a record handed over without its files (a list does not carry them)
      "is read again with them (since 2026-10, third round)
      IF mt_keys IS NOT INITIAL
        OR ( mv_is_create = abap_false AND line_exists( ms_entity-fields[ is_large_object = abap_true ] ) ).
        reload_data( ).
      ENDIF.

      "a draft of the record: the user's own opens to be edited further,
      "another user's locks it (since 2026-10, third round)
      IF mv_is_create = abap_false AND mv_draft = abap_false AND is_draft_enabled( get_bdef( ) ) = abap_true.
        read_draft_status( ).
        IF ms_draft-state = z2ui5_cl_rap_util=>cs_editing_status-own_draft.
          resume_draft( ).
        ENDIF.
      ENDIF.
      load_permissions( ).

      "backup original data for cancel
      CREATE DATA ms_data_backup LIKE ms_data->*.
      ms_data_backup->* = ms_data->*.

      "opened in edit mode (editable, e.g. by a link with mode=edit): only
      "where the record may be changed, a draft business object in a draft
      "of its own (since 2026-10, third round)
      IF mv_editable = abap_true AND mv_is_create = abap_false AND mv_draft = abap_false.
        apply_start_mode( client ).
      ENDIF.

      IF mv_title IS INITIAL.
        IF ms_entity-header_info-type_name IS NOT INITIAL.
          mv_title = ms_entity-header_info-type_name.
        ELSE.
          mv_title = ms_entity-name.
        ENDIF.
      ENDIF.

      prepare_value_lists( ms_entity-fields ).
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF ext_on_event( client ) = abap_true.
      RETURN.
    ENDIF.

    "the suggestions of an input with a value help, while the user types
    IF client->check_on_event( cv_event_suggest ).
      load_suggestions( client    = client
                        it_fields = ms_entity-fields ).
      RETURN.
    ENDIF.

    "the file of a file field (@Semantics.largeObject; since 2026-10,
    "third round): taken into the record - written with the next Save -,
    "or downloaded
    IF client->check_on_event( cv_event_upload_open ).
      READ TABLE ms_entity-fields INTO DATA(ls_upload_field) WITH KEY name = to_upper( client->get_event_arg( ) ).
      IF sy-subrc = 0 AND mv_editable = abap_true AND ls_upload_field-is_large_object = abap_true.
        render_upload_popup( client   = client
                             is_field = get_field_for_edit( ls_upload_field ) ).
      ENDIF.
      RETURN.
    ENDIF.
    IF client->check_on_event( cv_event_upload_cancel ).
      client->popup_destroy( ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cv_event_upload ).
      client->popup_destroy( ).
      IF mv_editable = abap_true.
        DATA(lt_upload_fields) = ms_entity-fields.
        LOOP AT lt_upload_fields ASSIGNING FIELD-SYMBOL(<ls_upload_field>).
          <ls_upload_field> = get_field_for_edit( <ls_upload_field> ).
        ENDLOOP.
        DATA(lv_taken) = apply_upload( EXPORTING client    = client
                                                 it_fields = lt_upload_fields
                                       CHANGING  target    = ms_data->* ).
        IF lv_taken = abap_true.
          client->message_toast_display( get_text( cs_text-file_uploaded ) ).
        ENDIF.
      ENDIF.
      render_page( client ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cv_event_download ).
      download_file( client    = client
                     it_fields = ms_entity-fields
                     source    = ms_data->* ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-back ).
      "leaving a draft: keep it (the page reads it back next time) or
      "discard it - the user decides (since 2026-10, third round)
      IF mv_draft = abap_true.
        client->message_box_display(
          text    = get_text( cs_text-leave_draft )
          type    = `confirm`
          actions = VALUE #( ( get_text( cs_text-keep_draft ) )
                             ( get_text( cs_text-discard_draft ) )
                             ( get_text( cs_text-cancel ) ) )
          onclose = cs_event-leave_decision ).
        RETURN.
      ENDIF.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-leave_decision ).
      DATA(lv_leave) = client->get_event_arg( ).
      IF lv_leave = get_text( cs_text-discard_draft ).
        DATA(ls_leave_discard) = run_draft_action( bdef      = get_bdef( )
                                                   action    = `DISCARD`
                                                   root_keys = get_root_keys( )
                                                   is_draft  = abap_true ).
        IF ls_leave_discard-success = abap_false.
          show_messages( client   = client
                         messages = ls_leave_discard-messages
                         details  = ls_leave_discard-details
                         fields   = ms_entity-fields ).
          RETURN.
        ENDIF.
        mv_draft = abap_false.
      ELSEIF lv_leave <> get_text( cs_text-keep_draft ).
        RETURN.
      ENDIF.
      "a kept draft is committed already - the list shows it as a draft
      mv_saved = abap_true.
      client->nav_app_leave( ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-edit ).
      "another user's draft locks the record
      IF ms_draft-state = z2ui5_cl_rap_util=>cs_editing_status-locked.
        client->message_box_display( text = replace( val  = get_text( cs_text-locked_by )
                                                     sub  = `&1`
                                                     with = ms_draft-user )
                                     type = `error` ).
        RETURN.
      ENDIF.
      IF ms_caps-can_update = abap_false
        OR ms_perm-can_update = abap_false
        OR is_hidden_by_annotation( value = ms_entity-update_hidden
                                    row   = ms_data->* ) = abap_true.
        client->message_box_display( text = get_text( cs_text-read_only )
                                     type = `error` ).
        RETURN.
      ENDIF.
      "a draft business object is edited in a draft of its own
      IF is_draft_enabled( get_bdef( ) ) = abap_true AND start_draft( client ) = abap_false.
        RETURN.
      ENDIF.
      mv_editable = abap_true.
      CLEAR mt_pending.
      "the children as edit mode shows them - of the draft, with what may
      "be changed per row
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-draft_decision ).
      "the user's answer to "a draft exists": continue it (since 2026-10,
      "third round), or discard it and edit anew
      IF client->get_event_arg( ) = get_text( cs_text-resume_draft ).
        IF resume_draft( ) = abap_true.
          load_permissions( ).
          load_child_rows( ).
          render_page( client ).
        ELSE.
          client->message_box_display( text = get_text( cs_text-not_found )
                                       type = `error` ).
        ENDIF.
        RETURN.
      ENDIF.
      IF client->get_event_arg( ) = get_text( cs_text-discard_draft ).
        DATA(ls_discard) = run_draft_action( bdef      = get_bdef( )
                                             action    = `DISCARD`
                                             root_keys = get_root_keys( )
                                             is_draft  = abap_true ).
        IF ls_discard-success = abap_false.
          show_messages( client   = client
                         messages = ls_discard-messages
                         details  = ls_discard-details
                         fields   = ms_entity-fields ).
          RETURN.
        ENDIF.
        IF start_draft( client ) = abap_true.
          mv_editable = abap_true.
          load_child_rows( ).
          render_page( client ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-cancel ).
      IF mv_is_create = abap_true.
        client->nav_app_leave( ).
        RETURN.
      ENDIF.
      IF mv_draft = abap_true.
        DATA(ls_cancel) = run_draft_action( bdef      = get_bdef( )
                                            action    = `DISCARD`
                                            root_keys = get_root_keys( )
                                            is_draft  = abap_true ).
        IF ls_cancel-success = abap_false.
          show_messages( client   = client
                         messages = ls_cancel-messages
                         details  = ls_cancel-details
                         fields   = ms_entity-fields ).
          RETURN.
        ENDIF.
        mv_draft = abap_false.
        "the active record as it is - the draft had the changes
        reload_data( ).
        ms_data_backup->* = ms_data->*.
      ELSE.
        ms_data->* = ms_data_backup->*.
      ENDIF.
      mv_editable = abap_false.
      CLEAR: mt_messages, mt_pending.
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-save ).
      DATA(lt_missing) = get_missing_fields( ).
      IF lt_missing IS NOT INITIAL.
        client->message_box_display(
          text = |{ get_text( cs_text-required ) }: { concat_lines_of( table = lt_missing sep = `, ` ) }|
          type = `warning` ).
        RETURN.
      ENDIF.
      DATA(lv_was_create) = mv_is_create.
      "the time before the save - a record created by late numbering is
      "found again by it
      DATA lv_since_ts TYPE timestampl.
      GET TIME STAMP FIELD lv_since_ts.
      DATA(lv_since_utc) = utclong_current( ).
      DATA(lv_saved) = COND abap_bool( WHEN mv_draft = abap_true THEN save_draft( client )
                                       ELSE save_data( client ) ).
      IF lv_saved = abap_true.
        mv_saved = abap_true.
        mv_editable = abap_false.
        mv_is_create = abap_false.
        CLEAR mt_messages.
        "a created record whose key the business object assigns and did not
        "hand back (late numbering): found by who created it when, else it
        "cannot be read again - the list shows it
        IF lv_was_create = abap_true AND mt_keys IS INITIAL AND has_initial_key( ) = abap_true
          AND find_created_record( since_ts  = lv_since_ts
                                   since_utc = lv_since_utc ) = abap_false.
          client->nav_app_leave( ).
          RETURN.
        ENDIF.
        "what the business object determined on save
        reload_data( ).
        ms_data_backup->* = ms_data->*.
        CLEAR mt_pending.
        load_child_rows( ).
        render_page( client ).
        client->message_toast_display( get_text( cs_text-saved ) ).
      ELSEIF mt_messages IS NOT INITIAL.
        "the fields the messages are about are marked - built into the view
        render_page( client ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-delete ).
      IF ms_perm-can_delete = abap_false
        OR is_hidden_by_annotation( value = ms_entity-delete_hidden
                                    row   = ms_data->* ) = abap_true.
        RETURN.
      ENDIF.
      IF delete_data( client ).
        mv_saved = abap_true.
        client->message_toast_display( get_text( cs_text-deleted ) ).
        client->nav_app_leave( ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-value_help ).
      READ TABLE ms_entity-fields INTO DATA(ls_field) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0.
        open_value_help( client   = client
                         is_field = ls_field
                         source   = ms_data->* ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-action ).
      on_action( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-copy_link ).
      client->follow_up_action( val   = client->cs_event-clipboard_copy
                                t_arg = VALUE #( ( get_link( client ) ) ) ).
      client->message_toast_display( get_text( cs_text-link_copied ) ).
      RETURN.
    ENDIF.

    "a #FOR_INTENT_BASED_NAVIGATION of @UI.identification - with the keys
    IF client->check_on_event( cs_event-intent ).
      READ TABLE ms_entity-actions INTO DATA(ls_intent) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0 AND ls_intent-semantic_object IS NOT INITIAL.
        "semanticObjectBinding: the record's values, else its keys (since
        "2026-10, third round)
        DATA(lt_intent_params) = COND ty_t_name_value(
          WHEN ls_intent-sem_object_bindings IS NOT INITIAL
          THEN z2ui5_cl_rap_util=>get_navigation_params( row      = ms_data->*
                                                         bindings = ls_intent-sem_object_bindings )
          ELSE get_own_keys( ) ).
        navigate_to_intent( client          = client
                            semantic_object = ls_intent-semantic_object
                            action          = ls_intent-semantic_action
                            params          = lt_intent_params ).
        RETURN.
      ENDIF.
      "the link of a field with @Consumption.semanticObject: its value
      "(mapped by its bindings) and the record's keys
      READ TABLE ms_entity-fields INTO DATA(ls_link_field) WITH KEY name = client->get_event_arg( ).
      IF sy-subrc = 0 AND ls_link_field-semantic_object IS NOT INITIAL.
        DATA(lt_link_params) = z2ui5_cl_rap_util=>get_navigation_params( row      = ms_data->*
                                                                         field    = ls_link_field-name
                                                                         bindings = ls_link_field-sem_object_bindings ).
        LOOP AT get_own_keys( ) INTO DATA(ls_own_key).
          IF NOT line_exists( lt_link_params[ name = ls_own_key-name ] ).
            APPEND ls_own_key TO lt_link_params.
          ENDIF.
        ENDLOOP.
        navigate_to_intent( client          = client
                            semantic_object = ls_link_field-semantic_object
                            action          = `display`
                            params          = lt_link_params ).
      ENDIF.
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-child_row ).
      on_child_row( client ).
      RETURN.
    ENDIF.

    "the MultiInput of a 1:n child, the rows of a child table in edit mode
    "and the side effects (since 2026-10, third round)
    IF client->check_on_event( cs_event-path_token_add ).
      add_path_token( client    = client
                      component = client->get_event_arg( ) ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-path_token_delete ).
      delete_path_token( client    = client
                         component = client->get_event_arg( )
                         key       = client->get_event_arg( 2 ) ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-path_value_help ).
      READ TABLE mt_path INTO DATA(ls_vh_path) WITH KEY component = client->get_event_arg( ).
      IF sy-subrc = 0 AND mv_editable = abap_true.
        READ TABLE ls_vh_path-entity-fields INTO DATA(ls_vh_element) WITH KEY name = ls_vh_path-field-element.
        IF sy-subrc = 0 AND ls_vh_element-value_help-entity_name IS NOT INITIAL.
          mv_pending_path = ls_vh_path-component.
          open_value_help( client   = client
                           is_field = ls_vh_element ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-child_row_add ).
      on_child_row_add( client ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-child_row_delete ).
      on_child_row_delete( client ).
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-child_cell_change ).
      "a draft keeps the change at once - its determinations run - where
      "side effects are wanted; without draft the rows wait for Save
      IF mv_draft = abap_true AND mv_editable = abap_true AND get_side_effect_fields( ) IS NOT INITIAL.
        DATA(ls_cell_result) = write_children( abap_true ).
        IF ls_cell_result-success = abap_false.
          show_messages( client   = client
                         messages = ls_cell_result-messages
                         details  = ls_cell_result-details
                         fields   = ms_entity-fields ).
        ENDIF.
        load_child_rows( ).
        render_page( client ).
      ENDIF.
      RETURN.
    ENDIF.
    IF client->check_on_event( cs_event-side_effect ).
      on_side_effect( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-child_create ).
      on_child_create( client ).
      RETURN.
    ENDIF.

    IF client->check_on_event( cs_event-child_action ).
      on_child_action( client ).
      RETURN.
    ENDIF.

    "returning from a called app or a restored bookmark: check_on_init( ) is
    "false here and the browser still shows the OTHER app's view, so the view
    "has to be built again - a model push would reach nothing
    IF client->check_on_navigated( ).
      "the value help of a MultiInput: the value chosen is a new token
      "(since 2026-10, third round)
      IF mv_pending_path IS NOT INITIAL.
        DATA(lv_vh_component) = mv_pending_path.
        CLEAR mv_pending_path.
        DATA(lo_path_vh) = get_value_help_result( client ).
        CLEAR mv_vh_target.
        IF lo_path_vh IS BOUND.
          add_path_token( client    = client
                          component = lv_vh_component
                          value     = lo_path_vh->result_value( ) ).
        ELSE.
          render_page( client ).
        ENDIF.
        RETURN.
      ENDIF.
      apply_value_help( EXPORTING client    = client
                                  it_fields = ms_entity-fields
                        CHANGING  target    = ms_data->* ).
      "decided by what this page called - check_app_prev_stack( ) only says
      "whether the page has a caller itself
      IF mv_pending_action IS NOT INITIAL.
        TRY.
            DATA(lo_dialog) = CAST z2ui5_cl_rap_action_dialog( client->get_app_prev( ) ).
            IF lo_dialog->was_confirmed( ) AND mv_pending_child IS NOT INITIAL.
              execute_child_action( client = client
                                    param  = lo_dialog->result( ) ).
            ELSEIF lo_dialog->was_confirmed( ).
              execute_action( client = client
                              param  = lo_dialog->result( ) ).
            ENDIF.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
        CLEAR: mv_pending_action, mv_pending_child.
        "the action created a record - its object page is on its way
        IF mv_opened_created = abap_true.
          CLEAR mv_opened_created.
          RETURN.
        ENDIF.
      ENDIF.
      "a child record may have changed - in edit mode the rows on the
      "page hold the changes not written yet
      IF mv_editable = abap_false.
        load_child_rows( ).
      ENDIF.
      render_page( client ).
      RETURN.
    ENDIF.

    "unknown events land in the subclass hook - the escape hatch
    on_event( client ).

  ENDMETHOD.


  METHOD on_event ##NEEDED.
    "subclass hook - the floorplan itself has nothing to do here
  ENDMETHOD.


  METHOD get_missing_fields.
    FIELD-SYMBOLS <fld> TYPE any.
    "mandatory by the annotations and by the field control (ms_perm)
    LOOP AT ms_entity-fields INTO DATA(ls_any_field) WHERE is_hidden = abap_false.
      DATA(ls_field) = get_field_for_edit( ls_any_field ).
      IF ls_field-is_mandatory = abap_false.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT ls_field-name OF STRUCTURE ms_data->* TO <fld>.
      IF sy-subrc = 0 AND <fld> IS INITIAL.
        APPEND ls_field-label TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD save_data.

    DATA(ls_result) = write_row( entity_name = mv_entity_name
                                 operation   = COND #( WHEN mv_is_create = abap_true THEN `CREATE` ELSE `UPDATE` )
                                 row         = ms_data->*
                                 original    = ms_data_backup->*
                                 context     = ms_context ).
    result = ls_result-success.
    "the fields the messages are about are marked when the page shows again
    mt_messages = ls_result-details.
    "the keys RAP assigned on create - the record is read again by them
    IF result = abap_true AND ls_result-keys IS NOT INITIAL.
      mt_keys = ls_result-keys.
    ENDIF.
    IF result = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
      RETURN.
    ENDIF.

    "the children changed in edit mode - after the record, each its own
    "write (since 2026-10, third round). The record is saved: a child that
    "is refused keeps the page in edit mode with its message
    IF mv_is_create = abap_false.
      DATA(ls_children) = write_children( abap_false ).
      IF ls_children-success = abap_false.
        ms_data_backup->* = ms_data->*.
        mt_messages = ls_children-details.
        show_messages( client   = client
                       messages = ls_children-messages
                       details  = ls_children-details
                       fields   = ms_entity-fields ).
        result = abap_false.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD delete_data.

    DATA(ls_result) = write_row( entity_name = mv_entity_name
                                 operation   = `DELETE`
                                 row         = ms_data->*
                                 context     = ms_context ).
    result = ls_result-success.
    IF result = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
    ENDIF.

  ENDMETHOD.


  METHOD has_initial_key.
    FIELD-SYMBOLS <lv_key> TYPE any.
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
      IF sy-subrc = 0 AND <lv_key> IS INITIAL.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD reload_data.

    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lv_key> TYPE any.

    "the keys: those the page was opened with (or RAP assigned), else the
    "record's own - read each time, not kept, so an edited record is not
    "looked up by keys it no longer has
    DATA(lt_keys) = mt_keys.
    IF lt_keys IS INITIAL.
      LOOP AT ms_entity-keys INTO DATA(lv_key).
        ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
        IF sy-subrc = 0.
          APPEND VALUE #( name = lv_key value = |{ <lv_key> }| ) TO lt_keys.
        ENDIF.
      ENDLOOP.
    ENDIF.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    "compared with typed host variables, not literals - a RAW key (a UUID)
    "does not compare with a character literal
    LOOP AT lt_keys INTO DATA(ls_key).
      DATA(lv_name) = to_upper( ls_key-name ).
      IF NOT line_exists( ms_entity-fields[ name = lv_name ] ).
        RETURN.
      ENDIF.
      APPEND lv_name TO lt_names.
    ENDLOOP.

    DATA(lr_rows) = select_rows( entity_name = mv_entity_name
                                 where       = build_key_condition( lt_names )
                                 max_rows    = 1
                                 host        = create_host( entity_name = mv_entity_name
                                                            values      = lt_keys ) ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
    IF sy-subrc = 0.
      MOVE-CORRESPONDING <ls_row> TO ms_data->*.
      RETURN.
    ENDIF.

    "no active record by these keys: a draft that was never activated -
    "what a factory action of a draft business object creates (since
    "2026-10, third round). It opens to be edited
    IF is_draft_enabled( get_bdef( ) ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lr_host) = create_host( entity_name = mv_entity_name
                                 values      = lt_keys ).
    IF lr_host IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_host->* TO FIELD-SYMBOL(<ls_host_row>).
    MOVE-CORRESPONDING <ls_host_row> TO ms_data->*.
    IF resume_draft( ) = abap_false.
      CLEAR ms_data->*.
    ENDIF.

  ENDMETHOD.


  METHOD get_association_target.
    IF mo_ext IS BOUND.
      mo_ext->resolve_association( EXPORTING entity_name = mv_entity_name
                                             association = association
                                   CHANGING  target      = result ).
    ENDIF.
    "the extension decides first, the DDL source otherwise
    IF result IS INITIAL.
      READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = to_upper( association ).
      IF sy-subrc = 0.
        result = ls_assoc-target.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD load_child_rows.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_rows TYPE STANDARD TABLE OF REF TO data WITH DEFAULT KEY.
    DATA ls_path_value TYPE ty_s_path_value.
    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_target> TYPE any.
    FIELD-SYMBOLS <lt_source> TYPE any.
    FIELD-SYMBOLS <lt_children> TYPE STANDARD TABLE.

    CLEAR: mr_child_rows, mt_child, mt_path.
    IF mv_is_create = abap_true.
      RETURN.
    ENDIF.

    LOOP AT get_sections( ) INTO DATA(ls_section) WHERE type = `LINEITEM`.
      DATA(lv_target) = to_upper( get_association_target( ls_section-association ) ).
      IF lv_target IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_child) = VALUE ty_s_child(
        section_id  = ls_section-id
        component   = |SECTION_{ lines( mt_child ) + 1 }|
        association = to_upper( ls_section-association )
        entity      = z2ui5_cl_rap_util=>read_entity( lv_target ) ).
      adjust_entity( CHANGING cs_entity = ls_child-entity ).

      "the child rows of this record - compared with typed host variables
      get_child_filter( EXPORTING is_child  = ls_child
                        IMPORTING et_values = DATA(lt_values) ).
      IF lt_values IS INITIAL.
        CONTINUE.
      ENDIF.

      "what may be done to a row: create under this record (the record's
      "feature control of the association included), change and delete
      "it, and the toolbar actions of the child's @UI.lineItem on the
      "selected rows
      DATA(ls_child_caps) = get_entity_capabilities(
        entity_name = lv_target
        context     = get_child_context( ls_child-association ) ).
      ls_child-can_create = xsdbool( ls_child_caps-can_create = abap_true
                                     AND z2ui5_cl_rap_util=>is_permitted( ops  = ms_perm-associations
                                                                          name = ls_child-association ) = abap_true ).
      ls_child-can_update = ls_child_caps-can_update.
      ls_child-can_delete = ls_child_caps-can_delete.
      IF is_hidden_by_annotation( value = ls_child-entity-create_hidden
                                  row   = ms_data->* ) = abap_true.
        ls_child-can_create = abap_false.
      ENDIF.
      IF ls_child_caps-is_rap_bo = abap_true.
        LOOP AT ls_child-entity-actions INTO DATA(ls_child_action)
          WHERE source = `LINEITEM` AND inline = abap_false AND semantic_object IS INITIAL.
          APPEND ls_child_action TO ls_child-actions.
        ENDLOOP.
        "what the child entity's global feature control and authorization
        "disable - an instance's own is checked when the action runs
        IF ls_child-actions IS NOT INITIAL.
          DATA(ls_child_perm) = get_permissions( entity_name = lv_target
                                                 context     = get_child_context( ls_child-association ) ).
          LOOP AT ls_child-actions INTO ls_child_action.
            IF z2ui5_cl_rap_util=>is_permitted( ops  = ls_child_perm-global-actions
                                                name = ls_child_action-name ) = abap_false.
              APPEND ls_child_action-name TO ls_child-disabled_actions.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.

      DATA(lr_rows) = add_row_flags( EXPORTING rows     = read_child_rows( is_child  = ls_child
                                                                         it_values = lt_values )
                                     CHANGING  cs_child = ls_child ).
      IF lr_rows IS NOT BOUND.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( name = ls_child-component
                      type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_rows ) ) ) TO lt_comp.
      APPEND lr_rows TO lt_rows.
      APPEND ls_child TO mt_child.
    ENDLOOP.

    "the change documents an extension names - a read-only table (since
    "2026-10, third round)
    get_change_documents( IMPORTING ev_entity = DATA(lv_docs_entity)
                                    et_filter = DATA(lt_docs_filter) ).
    IF lv_docs_entity IS NOT INITIAL.
      DATA(ls_docs) = VALUE ty_s_child(
        section_id = cs_section_id-change_docs
        component  = |SECTION_{ lines( mt_child ) + 1 }|
        read_only  = abap_true
        entity     = z2ui5_cl_rap_util=>read_entity( lv_docs_entity ) ).
      adjust_entity( CHANGING cs_entity = ls_docs-entity ).
      DATA lt_docs_values TYPE ty_t_name_value.
      DATA lt_docs_names TYPE string_table.
      FIELD-SYMBOLS <lv_docs_value> TYPE any.
      CLEAR: lt_docs_values, lt_docs_names.
      LOOP AT lt_docs_filter INTO DATA(ls_docs_filter).
        DATA(lv_docs_local) = to_upper( ls_docs_filter-value ).
        DATA(lv_docs_field) = to_upper( ls_docs_filter-name ).
        UNASSIGN <lv_docs_value>.
        ASSIGN COMPONENT lv_docs_local OF STRUCTURE ms_data->* TO <lv_docs_value>.
        IF <lv_docs_value> IS NOT ASSIGNED
          OR NOT line_exists( ls_docs-entity-fields[ name = lv_docs_field ] ).
          CLEAR lt_docs_values.
          EXIT.
        ENDIF.
        APPEND VALUE #( name = lv_docs_field value = |{ <lv_docs_value> }| ) TO lt_docs_values.
        APPEND lv_docs_field TO lt_docs_names.
      ENDLOOP.
      IF lt_docs_values IS NOT INITIAL.
        DATA(lr_docs) = select_rows( entity_name = ls_docs-entity-name
                                     where       = build_key_condition( lt_docs_names )
                                     host        = create_host( entity_name = ls_docs-entity-name
                                                                values      = lt_docs_values ) ).
        IF lr_docs IS BOUND.
          APPEND VALUE #( name = ls_docs-component
                          type = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data_ref( lr_docs ) ) ) TO lt_comp.
          APPEND lr_docs TO lt_rows.
          APPEND ls_docs TO mt_child.
        ENDIF.
      ENDIF.
    ENDIF.

    "the MultiInputs of 1:n children - an entry whose value is an
    "association path (since 2026-10, third round)
    DATA(lo_path_type) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data( ls_path_value ) ).
    LOOP AT ms_entity-path_fields INTO DATA(ls_path_field) WHERE source <> `LINEITEM`.
      DATA(lv_path_target) = to_upper( get_association_target( ls_path_field-association ) ).
      IF lv_path_target IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_path) = VALUE ty_s_path_child(
        component = |PATH_{ lines( mt_path ) + 1 }|
        field     = ls_path_field
        entity    = z2ui5_cl_rap_util=>read_entity( lv_path_target ) ).
      adjust_entity( CHANGING cs_entity = ls_path-entity ).
      IF NOT line_exists( ls_path-entity-fields[ name = ls_path_field-element ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_path_as_child) = get_path_as_child( ls_path ).
      get_child_filter( EXPORTING is_child  = ls_path_as_child
                        IMPORTING et_values = DATA(lt_path_values) ).
      IF lt_path_values IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_path_caps) = get_entity_capabilities(
        entity_name = lv_path_target
        context     = get_child_context( ls_path_field-association ) ).
      ls_path-can_create = xsdbool( ls_path_caps-can_create = abap_true
                                    AND z2ui5_cl_rap_util=>is_permitted( ops  = ms_perm-associations
                                                                         name = ls_path_field-association ) = abap_true
                                    AND is_hidden_by_annotation( value = ls_path-entity-create_hidden
                                                                 row   = ms_data->* ) = abap_false ).
      ls_path-can_delete = ls_path_caps-can_delete.

      CLEAR ls_path_value.
      DATA(lr_path_rows) = read_child_rows( is_child  = get_path_as_child( ls_path )
                                            it_values = lt_path_values ).
      IF lr_path_rows IS BOUND.
        ASSIGN lr_path_rows->* TO <lt_children>.
        LOOP AT <lt_children> ASSIGNING FIELD-SYMBOL(<ls_path_row>).
          ASSIGN COMPONENT ls_path_field-element OF STRUCTURE <ls_path_row> TO FIELD-SYMBOL(<lv_path_text>).
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          APPEND VALUE #( key  = get_token_key( it_keys = ls_path-entity-keys
                                                row     = <ls_path_row> )
                          text = |{ <lv_path_text> }| ) TO ls_path_value-tokens.
        ENDLOOP.
      ENDIF.
      DATA lr_path_value TYPE REF TO ty_s_path_value.
      CREATE DATA lr_path_value.
      lr_path_value->* = ls_path_value.
      APPEND VALUE #( name = ls_path-component
                      type = lo_path_type ) TO lt_comp.
      APPEND lr_path_value TO lt_rows.
      APPEND ls_path TO mt_path.
    ENDLOOP.

    IF lt_comp IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_struct) = cl_abap_structdescr=>create( lt_comp ).
    CREATE DATA mr_child_rows TYPE HANDLE lo_struct.
    ASSIGN mr_child_rows->* TO <ls_all>.
    LOOP AT lt_rows INTO DATA(lr_list).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE <ls_all> TO <lt_target>.
      ASSIGN lr_list->* TO <lt_source>.
      <lt_target> = <lt_source>.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_child_filter.

    FIELD-SYMBOLS <lv_value> TYPE any.
    CLEAR et_values.

    "the association's ON condition, when each of its fields is there
    READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = is_child-association.
    IF sy-subrc = 0 AND ls_assoc-conditions IS NOT INITIAL.
      LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
        UNASSIGN <lv_value>.
        ASSIGN COMPONENT ls_condition-local OF STRUCTURE ms_data->* TO <lv_value>.
        IF <lv_value> IS NOT ASSIGNED OR NOT line_exists( is_child-entity-fields[ name = ls_condition-target ] ).
          CLEAR et_values.
          EXIT.
        ENDIF.
        APPEND VALUE #( name = ls_condition-target value = |{ <lv_value> }| ) TO et_values.
      ENDLOOP.
      IF et_values IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    "else the keys of this record, which a composition child carries under
    "the same names
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      UNASSIGN <lv_value>.
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_value>.
      IF <lv_value> IS NOT ASSIGNED OR NOT line_exists( is_child-entity-fields[ name = lv_key ] ).
        CLEAR et_values.
        RETURN.
      ENDIF.
      APPEND VALUE #( name = lv_key value = |{ <lv_value> }| ) TO et_values.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_link.

    DATA(lv_start_app) = ``.
    IF mo_ext IS BOUND.
      mo_ext->get_start_app( EXPORTING floorplan   = mv_floorplan
                                       entity_name = mv_entity_name
                             CHANGING  start_app   = lv_start_app ).
    ENDIF.
    IF lv_start_app IS INITIAL.
      result = client->app_state_get_href( ).
      RETURN.
    ENDIF.
    result = z2ui5_cl_rap_start=>get_link( client      = client
                                           start_class = lv_start_app
                                           floorplan   = mv_floorplan
                                           entity_name = mv_entity_name
                                           keys        = get_own_keys( ) ).

  ENDMETHOD.


  METHOD get_bdef.
    IF ms_context-bdef IS NOT INITIAL.
      result = ms_context-bdef.
    ELSEIF ms_caps-is_rap_bo = abap_true.
      result = mv_entity_name.
    ENDIF.
  ENDMETHOD.


  METHOD get_root_keys.
    result = COND #( WHEN ms_context-bdef IS NOT INITIAL THEN ms_context-root_keys
                     ELSE get_own_keys( ) ).
  ENDMETHOD.


  METHOD apply_start_mode.

    IF ms_draft-state = z2ui5_cl_rap_util=>cs_editing_status-locked
      OR ms_caps-can_update = abap_false
      OR ms_perm-can_update = abap_false
      OR is_hidden_by_annotation( value = ms_entity-update_hidden
                                  row   = ms_data->* ) = abap_true.
      mv_editable = abap_false.
      RETURN.
    ENDIF.
    "the decision about an existing draft comes back as draft_decision
    IF is_draft_enabled( get_bdef( ) ) = abap_true AND start_draft( client ) = abap_false.
      mv_editable = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD start_draft.

    DATA(ls_result) = run_draft_action( bdef      = get_bdef( )
                                        action    = `EDIT`
                                        root_keys = get_root_keys( ) ).
    IF ls_result-success = abap_true.
      mv_draft = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    "a draft exists already - another user's lock, which the business
    "object names, or one of this user's that can be discarded
    client->message_box_display(
      text    = concat_lines_of( table = ls_result-messages sep = cl_abap_char_utilities=>newline )
      type    = `warning`
      actions = VALUE #( ( get_text( cs_text-resume_draft ) )
                         ( get_text( cs_text-discard_draft ) )
                         ( get_text( cs_text-cancel ) ) )
      onclose = cs_event-draft_decision ).

  ENDMETHOD.


  METHOD save_draft.

    DATA(ls_result) = write_draft( entity_name = mv_entity_name
                                   row         = ms_data->*
                                   original    = ms_data_backup->*
                                   context     = ms_context ).
    mt_messages = ls_result-details.
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
      RETURN.
    ENDIF.
    "the draft has the changes now - the next change is compared with it
    ms_data_backup->* = ms_data->*.

    "the changed rows of the child tables into the draft as well (since
    "2026-10, third round)
    ls_result = write_children( abap_true ).
    IF ls_result-success = abap_false.
      mt_messages = ls_result-details.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
      RETURN.
    ENDIF.

    ls_result = run_draft_action( bdef      = get_bdef( )
                                  action    = `ACTIVATE`
                                  root_keys = get_root_keys( )
                                  is_draft  = abap_true ).
    mt_messages = ls_result-details.
    IF ls_result-success = abap_false.
      "the draft keeps the changes, the page stays in edit mode
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
      RETURN.
    ENDIF.

    mv_draft = abap_false.
    IF mo_ext IS BOUND.
      mo_ext->after_save( entity_name = mv_entity_name
                          operation   = `UPDATE`
                          data        = ms_data ).
    ENDIF.
    result = abap_true.

  ENDMETHOD.


  METHOD get_own_keys.

    FIELD-SYMBOLS <lv_key> TYPE any.
    LOOP AT ms_entity-keys INTO DATA(lv_key).
      UNASSIGN <lv_key>.
      ASSIGN COMPONENT lv_key OF STRUCTURE ms_data->* TO <lv_key>.
      IF <lv_key> IS ASSIGNED.
        APPEND VALUE #( name = lv_key value = |{ <lv_key> }| ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_child_context.

    "only a composition the DDL source declares: any other association -
    "and one the source does not show, e.g. resolved by the extension -
    "leads to an entity of its own, written, if at all, as its own business
    "object
    READ TABLE ms_entity-associations INTO DATA(ls_assoc) WITH KEY name = to_upper( association ).
    IF sy-subrc <> 0 OR ls_assoc-is_composition = abap_false.
      RETURN.
    ENDIF.

    "a child is written through the BDEF of the root - this record's root
    IF ms_context-bdef IS NOT INITIAL.
      result-bdef = ms_context-bdef.
      result-root_keys = ms_context-root_keys.
    ELSEIF ms_caps-is_rap_bo = abap_true.
      result-bdef = mv_entity_name.
      result-root_keys = get_own_keys( ).
    ELSE.
      RETURN.
    ENDIF.
    result-parent = mv_entity_name.
    result-parent_keys = get_own_keys( ).
    result-association = to_upper( association ).
    "the child's fields that point at this record - the composition fills them
    LOOP AT ls_assoc-conditions INTO DATA(ls_condition).
      APPEND ls_condition-target TO result-parent_fields.
    ENDLOOP.

  ENDMETHOD.


  METHOD on_child_create.

    FIELD-SYMBOLS <ls_row> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR ls_child-can_create = abap_false.
      RETURN.
    ENDIF.

    "the fields that point at this record are filled - shown on the page
    get_child_filter( EXPORTING is_child  = ls_child
                      IMPORTING et_values = DATA(lt_values) ).
    DATA(lr_row) = create_host( entity_name = ls_child-entity-name
                                values      = lt_values ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO <ls_row>.

    DATA(lv_type) = COND string( WHEN ls_child-entity-header_info-type_name IS NOT INITIAL
                                 THEN ls_child-entity-header_info-type_name
                                 ELSE ls_child-entity-name ).
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page(
      val       = <ls_row>
      title     = |{ get_text( cs_text-create_title ) } { lv_type }|
      editable  = abap_true
      is_create = abap_true
      context   = get_child_context( ls_child-association ) ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD find_created_record.

    FIELD-SYMBOLS <ls_host> TYPE any.
    FIELD-SYMBOLS <lv_at> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    READ TABLE ms_entity-fields INTO DATA(ls_by) WITH KEY admin_field = `CREATED_BY`.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ms_entity-fields INTO DATA(ls_at) WITH KEY admin_field = `CREATED_AT`.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lr_host) = create_host( entity_name = mv_entity_name
                                 values      = VALUE #( ( name = ls_by-name value = sy-uname ) ) ).
    IF lr_host IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_host->* TO <ls_host>.
    ASSIGN COMPONENT ls_at-name OF STRUCTURE <ls_host> TO <lv_at>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "a little before the save - a time stamp in seconds is rounded
    TRY.
        DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( <lv_at> )->type_kind.
        IF lv_kind = cl_abap_typedescr=>typekind_utclong.
          <lv_at> = utclong_add( val     = since_utc
                                 seconds = -2 ).
        ELSEIF lv_kind = cl_abap_typedescr=>typekind_packed.
          <lv_at> = cl_abap_tstmp=>add( tstmp = since_ts
                                        secs  = -2 ).
        ELSEIF lv_kind = cl_abap_typedescr=>typekind_date.
          <lv_at> = sy-datum.
        ELSE.
          RETURN.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(lr_rows) = select_rows(
      entity_name = mv_entity_name
      where       = |{ ls_by-name } = @{ cv_host }-{ ls_by-name } AND { ls_at-name } >= @{ cv_host }-{ ls_at-name }|
      max_rows    = 1
      order_by    = |{ ls_at-name } DESCENDING|
      host        = lr_host ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    READ TABLE <lt_rows> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_row>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    MOVE-CORRESPONDING <ls_row> TO ms_data->*.
    mt_keys = get_own_keys( ).
    result = abap_true.

  ENDMETHOD.


  METHOD on_child_row.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    "arg 1 the section's component, args 2... the keys of the child row
    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lr_row) = find_row_by_event_keys( data       = REF #( <lt_rows> )
                                           key_fields = ls_child-entity-keys
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO FIELD-SYMBOL(<ls_row>).
    DATA(lr_entity_row) = to_entity_row( entity_name = ls_child-entity-name
                                         row         = <ls_row> ).
    ASSIGN lr_entity_row->* TO <ls_row>.
    "the child is changed in the business object of this record - no
    "create by association here
    DATA(ls_context) = get_child_context( ls_child-association ).
    CLEAR: ls_context-association, ls_context-parent_fields.
    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( val     = <ls_row>
                                                context = ls_context ).
    lo_op->set_extension( mo_ext ).
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD on_action.

    FIELD-SYMBOLS <lt_record> TYPE STANDARD TABLE.

    "only an action this page offers, whatever the event names
    mv_pending_action = client->get_event_arg( ).
    CLEAR mv_pending_child.
    DATA(lt_actions) = get_record_actions( ).
    READ TABLE lt_actions INTO DATA(ls_action) WITH KEY name = mv_pending_action.
    IF sy-subrc <> 0.
      CLEAR mv_pending_action.
      RETURN.
    ENDIF.
    DATA(lr_param) = create_action_parameter( entity_name = mv_entity_name
                                              action      = mv_pending_action
                                              context     = ms_context ).
    IF lr_param IS BOUND.
      "the parameter first - the action runs on the return; its default
      "function fills it for this record (since 2026-10, third round)
      ASSIGN lr_param->* TO FIELD-SYMBOL(<ls_param>).
      DATA(lr_record) = create_entity_table( mv_entity_name ).
      IF lr_record IS BOUND.
        ASSIGN lr_record->* TO <lt_record>.
        APPEND INITIAL LINE TO <lt_record> ASSIGNING FIELD-SYMBOL(<ls_record>).
        MOVE-CORRESPONDING ms_data->* TO <ls_record>.
      ENDIF.
      apply_action_defaults( EXPORTING entity_name = mv_entity_name
                                       action      = mv_pending_action
                                       rows        = lr_record
                                       context     = ms_context
                                       is_draft    = mv_draft
                             CHANGING  param       = <ls_param> ).
      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog( val   = <ls_param>
                                                        title = ls_action-label ).
      lo_dialog->set_extension( mo_ext ).
      client->nav_app_call( lo_dialog ).
      RETURN.
    ENDIF.

    execute_action( client ).
    CLEAR mv_pending_action.
    IF mv_opened_created = abap_true.
      CLEAR mv_opened_created.
      RETURN.
    ENDIF.
    render_page( client ).

  ENDMETHOD.


  METHOD get_record_actions.

    IF ms_caps-is_rap_bo = abap_false.
      RETURN.
    ENDIF.
    LOOP AT ms_entity-actions INTO DATA(ls_action)
      WHERE ( source = `IDENTIFICATION` OR source = `FIELDGROUP` ) AND semantic_object IS INITIAL.
      APPEND ls_action TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD execute_action.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    DATA(lr_rows) = create_entity_table( mv_entity_name ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
    MOVE-CORRESPONDING ms_data->* TO <ls_row>.

    DATA(lt_actions) = get_record_actions( ).
    READ TABLE lt_actions INTO DATA(ls_action) WITH KEY name = mv_pending_action.
    DATA(ls_result) = run_action( entity_name         = mv_entity_name
                                  action              = mv_pending_action
                                  rows                = lr_rows
                                  param               = param
                                  context             = ms_context
                                  invocation_grouping = ls_action-invocation_grouping ).
    IF ls_result-success = abap_true.
      mv_saved = abap_true.
      reload_data( ).
      ms_data_backup->* = ms_data->*.
      "an action may change the children too
      load_child_rows( ).
      "a factory action: the record it created
      IF ls_result-keys IS NOT INITIAL.
        open_created( client      = client
                      entity_name = mv_entity_name
                      keys        = ls_result-keys
                      context     = ms_context ).
        RETURN.
      ENDIF.
      IF ls_result-messages IS INITIAL.
        client->message_toast_display( get_text( cs_text-action_done ) ).
      ELSE.
        show_messages( client   = client
                       messages = ls_result-messages
                       details  = ls_result-details
                       fields   = ms_entity-fields
                       type     = `success` ).
      ENDIF.
    ELSE.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
    ENDIF.

  ENDMETHOD.


  METHOD on_child_action.

    FIELD-SYMBOLS <ls_children> TYPE any.
    FIELD-SYMBOLS <lt_children> TYPE any.

    "arg 1 the section's component, arg 2 the action - one the table offers
    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ls_child-actions INTO DATA(ls_action) WITH KEY name = client->get_event_arg( 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    mv_pending_action = ls_action-name.
    mv_pending_child = ls_child-component.

    DATA(ls_context) = get_child_context( ls_child-association ).
    CLEAR: ls_context-association, ls_context-parent_fields.
    DATA(lr_param) = create_action_parameter( entity_name = ls_child-entity-name
                                              action      = mv_pending_action
                                              context     = ls_context ).
    IF lr_param IS BOUND.
      "the parameter first - the action runs on the return; its default
      "function fills it for the first selected row (since 2026-10, third
      "round)
      ASSIGN lr_param->* TO FIELD-SYMBOL(<ls_param>).
      DATA lr_child_rows TYPE REF TO data.
      IF mr_child_rows IS BOUND.
        ASSIGN mr_child_rows->* TO <ls_children>.
        ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_children> TO <lt_children>.
        IF sy-subrc = 0.
          lr_child_rows = REF #( <lt_children> ).
          lr_child_rows = get_selected_rows( entity_name = ls_child-entity-name
                                             data        = lr_child_rows ).
        ENDIF.
      ENDIF.
      apply_action_defaults( EXPORTING entity_name = ls_child-entity-name
                                       action      = mv_pending_action
                                       rows        = lr_child_rows
                                       context     = ls_context
                                       is_draft    = mv_draft
                             CHANGING  param       = <ls_param> ).
      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog( val   = <ls_param>
                                                        title = ls_action-label ).
      lo_dialog->set_extension( mo_ext ).
      client->nav_app_call( lo_dialog ).
      RETURN.
    ENDIF.

    execute_child_action( client ).
    CLEAR: mv_pending_action, mv_pending_child.
    IF mv_opened_created = abap_true.
      CLEAR mv_opened_created.
      RETURN.
    ENDIF.
    render_page( client ).

  ENDMETHOD.


  METHOD execute_child_action.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = mv_pending_child.
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ls_child-actions INTO DATA(ls_action) WITH KEY name = mv_pending_action.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "the child is changed in the business object of this record
    DATA(ls_context) = get_child_context( ls_child-association ).
    CLEAR: ls_context-association, ls_context-parent_fields.
    DATA(ls_result) = run_action( entity_name         = ls_child-entity-name
                                  action              = ls_action-name
                                  rows                = get_selected_rows( entity_name = ls_child-entity-name
                                                                           data        = REF #( <lt_rows> ) )
                                  param               = param
                                  context             = ls_context
                                  invocation_grouping = ls_action-invocation_grouping ).
    "#ISOLATED: some rows may have changed even when others failed
    reload_data( ).
    ms_data_backup->* = ms_data->*.
    load_child_rows( ).
    IF ls_result-success = abap_true.
      mv_saved = abap_true.
      IF ls_result-keys IS NOT INITIAL.
        open_created( client      = client
                      entity_name = ls_child-entity-name
                      keys        = ls_result-keys
                      context     = ls_context ).
        RETURN.
      ENDIF.
      IF ls_result-messages IS INITIAL.
        client->message_toast_display( get_text( cs_text-action_done ) ).
      ELSE.
        show_messages( client   = client
                       messages = ls_result-messages
                       details  = ls_result-details
                       fields   = ms_entity-fields
                       type     = `success` ).
      ENDIF.
    ELSE.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
    ENDIF.

  ENDMETHOD.


  METHOD render_action_buttons.

    DATA lt_arg TYPE string_table.
    DATA ls_crit TYPE z2ui5_cl_rap_util=>ty_s_action.

    LOOP AT get_action_entries( it_actions = it_actions
                                it_groups  = it_groups ) INTO DATA(ls_entry).

      IF ls_entry-group-id IS NOT INITIAL.
        DATA(lo_menu) = io_container->ele( `MenuButton`
            )->a( n = `text`
                  t = ls_entry-group-label
            )->ele( `menu`
                )->ele( `Menu` ).
        LOOP AT ls_entry-items INTO DATA(ls_item).
          lt_arg = args_before.
          APPEND ls_item-name TO lt_arg.
          lo_menu->tag( `MenuItem`
              )->a( n = `text`
                    t = ls_item-label
              )->a( n = `enabled`
                    b = xsdbool( NOT line_exists( disabled[ table_line = ls_item-name ] ) )
              )->a( n = `press`
                    v = client->_event( val   = event
                                        t_arg = lt_arg ) ).
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "the criticality as the button's type - written as a literal of
      "sap.m.ButtonType, so the view gate can check it
      ls_crit = ls_entry-action.
      DATA(lv_button_type) = `Default`.
      IF row IS SUPPLIED.
        CASE get_action_button_type( is_action = ls_crit
                                     row       = row ).
          WHEN `Accept`.
            lv_button_type = `Accept`.
          WHEN `Reject`.
            lv_button_type = `Reject`.
          WHEN `Emphasized`.
            lv_button_type = `Emphasized`.
        ENDCASE.
      ELSE.
        CASE get_action_button_type( ls_crit ).
          WHEN `Accept`.
            lv_button_type = `Accept`.
          WHEN `Reject`.
            lv_button_type = `Reject`.
          WHEN `Emphasized`.
            lv_button_type = `Emphasized`.
        ENDCASE.
      ENDIF.
      lt_arg = args_before.
      APPEND ls_entry-action-name TO lt_arg.
      io_container->tag( `Button`
          )->a( n = `text`
                t = ls_entry-action-label
          )->a( n = `type`
                v = lv_button_type
          )->a( n = `enabled`
                b = xsdbool( NOT line_exists( disabled[ table_line = ls_entry-action-name ] ) )
          )->a( n = `press`
                v = client->_event( val   = event
                                    t_arg = lt_arg ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD open_created.

    DATA(lo_op) = NEW z2ui5_cl_rap_object_page( cds_view_name = entity_name
                                                keys          = keys
                                                context       = context ).
    lo_op->set_extension( mo_ext ).
    mv_opened_created = abap_true.
    client->nav_app_call( lo_op ).

  ENDMETHOD.


  METHOD get_sections.

    "facet-driven - the header facets are the header's business
    DATA lt_facets TYPE z2ui5_cl_rap_util=>ty_t_facet.
    LOOP AT ms_entity-facets INTO DATA(ls_facet) WHERE purpose NS `HEADER`.
      APPEND ls_facet TO lt_facets.
    ENDLOOP.
    SORT lt_facets BY position.

    LOOP AT lt_facets INTO ls_facet.
      DATA(ls_section) = VALUE ty_s_section(
        id          = ls_facet-id
        title       = ls_facet-label
        field_group = ls_facet-target_qualifier
        association = ls_facet-target_element ).
      "a child facet whose collection is not among the facets stands alone
      IF ls_facet-parent_id IS NOT INITIAL AND line_exists( lt_facets[ id = ls_facet-parent_id ] ).
        ls_section-parent_id = ls_facet-parent_id.
      ENDIF.

      IF ls_facet-type CS `COLLECTION`.
        ls_section-type = `COLLECTION`.
      ELSEIF ls_facet-type CS `IDENTIFICATION`.
        "the entries of the facet's targetQualifier - unqualified as before
        ls_section-type = `IDENTIFICATION`.
        "a MultiInput of a 1:n child is content too (since 2026-10, third
        "round)
        IF get_identification_fields( ls_facet-target_qualifier ) IS INITIAL
          AND NOT line_exists( ms_entity-path_fields[ source    = `IDENTIFICATION`
                                                      qualifier = ls_facet-target_qualifier ] ).
          CONTINUE.
        ENDIF.
      ELSEIF ls_facet-type CS `LINEITEM`.
        ls_section-type = `LINEITEM`.
        IF ls_section-association IS INITIAL.
          CONTINUE.
        ENDIF.
      ELSEIF ( ls_facet-type IS INITIAL OR ls_facet-type CS `FIELDGROUP` )
        AND ls_facet-target_qualifier IS NOT INITIAL.
        ls_section-type = `FIELDGROUP`.
        IF NOT line_exists( ms_entity-fields[ field_group = ls_facet-target_qualifier ] ).
          "the field may sit in the group as its second entry
          DATA(lv_found) = abap_false.
          LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
            IF line_exists( ls_field-field_groups[ qualifier = ls_facet-target_qualifier ] ).
              lv_found = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
          IF lv_found = abap_false AND NOT line_exists( ms_entity-path_fields[ source    = `FIELDGROUP`
                                                                               qualifier = ls_facet-target_qualifier ] ).
            CONTINUE.
          ENDIF.
        ENDIF.
      ELSE.
        CONTINUE.
      ENDIF.

      IF ls_section-title IS INITIAL.
        ls_section-title = COND #( WHEN ls_section-field_group IS NOT INITIAL THEN ls_section-field_group
                                   WHEN ls_section-association IS NOT INITIAL THEN ls_section-association
                                   ELSE ls_section-id ).
      ENDIF.
      APPEND ls_section TO result.
    ENDLOOP.

    "a collection without any content left is no section
    LOOP AT result INTO ls_section WHERE type = `COLLECTION`.
      IF NOT line_exists( result[ parent_id = ls_section-id ] ).
        DELETE result WHERE id = ls_section-id.
      ENDIF.
    ENDLOOP.

    "field groups not covered by facets, in order of appearance
    LOOP AT ms_entity-fields INTO ls_field WHERE is_hidden = abap_false.
      LOOP AT ls_field-field_groups INTO DATA(ls_group).
        IF NOT line_exists( result[ field_group = ls_group-qualifier ] ).
          APPEND VALUE ty_s_section(
            id          = ls_group-qualifier
            title       = COND #( WHEN ls_group-group_label IS NOT INITIAL THEN ls_group-group_label ELSE ls_group-qualifier )
            field_group = ls_group-qualifier
            type        = `FIELDGROUP` ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    "no field groups at all -> single section with all visible fields
    IF NOT line_exists( result[ type = `FIELDGROUP` ] ) AND NOT line_exists( result[ type = `IDENTIFICATION` ] ).
      INSERT VALUE ty_s_section( id    = `GENERAL`
                                 title = get_text( cs_text-general )
                                 type  = `FIELDGROUP` ) INTO result INDEX 1.
    ENDIF.

    "the change information and the change documents an extension names,
    "at the end (since 2026-10, third round)
    IF get_admin_fields( ) IS NOT INITIAL.
      APPEND VALUE ty_s_section( id    = cs_section_id-change_info
                                 title = get_text( cs_text-change_info )
                                 type  = `ADMIN` ) TO result.
    ENDIF.
    get_change_documents( IMPORTING ev_entity = DATA(lv_docs_entity) ).
    IF lv_docs_entity IS NOT INITIAL.
      APPEND VALUE ty_s_section( id    = cs_section_id-change_docs
                                 title = get_text( cs_text-change_docs )
                                 type  = `CHANGE_DOCUMENTS` ) TO result.
    ENDIF.

  ENDMETHOD.


  METHOD get_identification_fields.

    "fields annotated with @UI.identification of the qualifier, by position -
    "the unqualified ones as is_identification says (an extension may
    "change it), the qualified ones by their entry
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
      READ TABLE ls_field-identifications INTO DATA(ls_ident) WITH KEY qualifier = qualifier.
      DATA(lv_found) = xsdbool( sy-subrc = 0 ).
      IF ( qualifier IS INITIAL AND ls_field-is_identification = abap_false )
        OR ( qualifier IS NOT INITIAL AND lv_found = abap_false ).
        CONTINUE.
      ENDIF.
      IF lv_found = abap_true AND qualifier IS NOT INITIAL.
        ls_field-identification_pos = ls_ident-position.
      ENDIF.
      IF lv_found = abap_true AND ls_ident-label IS NOT INITIAL.
        ls_field-label = ls_ident-label.
      ENDIF.
      "the entry's criticality, importance and hidden (since 2026-10, third
      "round) - a field of the record hides it for this record
      IF lv_found = abap_true.
        ls_field-entry_criticality = ls_ident-criticality.
        ls_field-entry_crit_repr = ls_ident-crit_representation.
        ls_field-entry_importance = ls_ident-importance.
        ls_field-entry_hidden = ls_ident-hidden.
      ENDIF.
      IF ms_data IS BOUND AND is_hidden_by_annotation( value = ls_field-entry_hidden
                                                       row   = ms_data->* ) = abap_true.
        CONTINUE.
      ENDIF.
      APPEND ls_field TO result.
    ENDLOOP.
    SORT result STABLE BY identification_pos.

    "fallback: first 3 visible fields (dataPoints are rendered separately) -
    "a qualifier with no field is no section
    IF result IS INITIAL AND qualifier IS INITIAL.
      LOOP AT ms_entity-fields INTO ls_field
        WHERE is_hidden = abap_false AND datapoint_qualifier IS INITIAL.
        APPEND ls_field TO result.
        IF lines( result ) >= 3.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD get_datapoint_fields.
    LOOP AT ms_entity-fields INTO DATA(ls_field)
      WHERE datapoint_qualifier IS NOT INITIAL AND is_hidden = abap_false.
      APPEND ls_field TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_criticality_state.
    result = criticality_state( iv_crit_value ).
  ENDMETHOD.


  METHOD get_crit_value.
    FIELD-SYMBOLS <lv_crit> TYPE any.
    ASSIGN COMPONENT iv_field OF STRUCTURE ms_data->* TO <lv_crit>.
    IF sy-subrc = 0.
      TRY.
          result = <lv_crit>.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD get_field_value.
    FIELD-SYMBOLS <lv_val> TYPE any.
    ASSIGN COMPONENT is_field-name OF STRUCTURE ms_data->* TO <lv_val>.
    IF sy-subrc = 0.
      result = format_value( is_field = is_field
                             val      = <lv_val> ).
    ENDIF.
  ENDMETHOD.


  METHOD format_value.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    IF is_field-is_boolean = abap_true.
      result = COND #( WHEN val = abap_true THEN get_text( cs_text-yes ) ELSE get_text( cs_text-no ) ).
      RETURN.
    ENDIF.

    TRY.
        CASE is_field-type_kind.
          WHEN `DATS`.
            lv_date = val.
            IF lv_date IS NOT INITIAL.
              result = |{ lv_date DATE = USER }|.
            ENDIF.
          WHEN `TIMS`.
            lv_time = val.
            IF lv_time IS NOT INITIAL.
              result = |{ lv_time TIME = USER }|.
            ENDIF.
          WHEN OTHERS.
            result = |{ val }|.
        ENDCASE.
      CATCH cx_root.
        result = |{ val }|.
    ENDTRY.

  ENDMETHOD.


  METHOD render_page.

    DATA(lo_view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(lo_op) = lo_view->ele( n  = `View`
                                 ns = `mvc`
        )->a( n = `xmlns`
              v = `sap.m`
        )->a( n = `xmlns:mvc`
              v = `sap.ui.core.mvc`
        )->a( n = `xmlns:uxap`
              v = `sap.uxap`
        )->a( n = `xmlns:form`
              v = `sap.ui.layout.form`
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
                      v = client->_event( cs_event-back )

                )->ele( n  = `ObjectPageLayout`
                         ns = `uxap`
                    )->a( n = `upperCaseAnchorBar`
                          v = `false` ).

    render_header_title( io_op  = lo_op
                         client = client ).

    render_header_content( io_op  = lo_op
                           client = client ).

    render_sections( io_op  = lo_op
                     client = client ).

    client->view_display( lo_view->stringify( ) ).

  ENDMETHOD.


  METHOD render_header_title.

    DATA(lo_ht) = io_op->ele( n  = `headerTitle`
                               ns = `uxap`
        )->ele( n  = `ObjectPageDynamicHeaderTitle`
                 ns = `uxap` ).

    "expanded heading - show title
    DATA(lv_title_text) = mv_title.
    IF ms_entity-header_info-title_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_t> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-title_field OF STRUCTURE ms_data->* TO <lv_t>.
      IF sy-subrc = 0 AND <lv_t> IS NOT INITIAL.
        lv_title_text = <lv_t>.
      ENDIF.
    ENDIF.
    lo_ht->ele( n  = `expandedHeading`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    "snapped heading
    lo_ht->ele( n  = `snappedHeading`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    "snapped title on mobile
    lo_ht->ele( n  = `snappedTitleOnMobile`
                 ns = `uxap`
        )->tag( `Title`
            )->a( n = `text`
                  t = lv_title_text ).

    DATA(lo_actions) = lo_ht->ele( n  = `actions`
                                    ns = `uxap` ).
    render_actions( io_actions = lo_actions
                    client     = client ).

    "expanded content - show subtitle/description
    IF ms_entity-header_info-description_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_d> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-description_field OF STRUCTURE ms_data->* TO <lv_d>.
      IF sy-subrc = 0 AND <lv_d> IS NOT INITIAL.
        lo_ht->ele( n  = `expandedContent`
                     ns = `uxap`
            )->tag( `Label`
                )->a( n = `text`
                      t = CONV #( <lv_d> ) ).
        lo_ht->ele( n  = `snappedContent`
                     ns = `uxap`
            )->tag( `Label`
                )->a( n = `text`
                      t = CONV #( <lv_d> ) ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD render_actions.

    IF mv_editable = abap_false.
      render_extension( spot         = cs_spot-header_actions
                        io_container = io_actions
                        client       = client ).
      "@UI.identification actions of type #FOR_ACTION - the unqualified
      "ones, a qualified one sits at its section; by position, an action
      "group as a menu, the criticality as the button's type
      IF ms_caps-is_rap_bo = abap_true.
        DATA lt_header_actions TYPE z2ui5_cl_rap_util=>ty_t_action.
        DATA lt_header_groups TYPE z2ui5_cl_rap_util=>ty_t_action_group.
        CLEAR: lt_header_actions, lt_header_groups.
        LOOP AT ms_entity-actions INTO DATA(ls_action)
          WHERE source = `IDENTIFICATION` AND semantic_object IS INITIAL AND qualifier IS INITIAL.
          APPEND ls_action TO lt_header_actions.
        ENDLOOP.
        LOOP AT ms_entity-action_groups INTO DATA(ls_group)
          WHERE source = `IDENTIFICATION` AND qualifier IS INITIAL.
          APPEND ls_group TO lt_header_groups.
        ENDLOOP.
        render_action_buttons( io_container = io_actions
                               it_actions   = lt_header_actions
                               it_groups    = lt_header_groups
                               client       = client
                               event        = cs_event-action
                               row          = ms_data->*
                               disabled     = get_disabled_actions( lt_header_actions ) ).
      ENDIF.
      "and of type #FOR_INTENT_BASED_NAVIGATION - to another app
      LOOP AT ms_entity-actions INTO DATA(ls_intent)
        WHERE source = `IDENTIFICATION` AND semantic_object IS NOT INITIAL.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = ls_intent-label
            )->a( n = `press`
                  v = client->_event( val = cs_event-intent
                                      arg = ls_intent-name ) ).
      ENDLOOP.
      "a link to this record - a saved one only
      IF mv_is_create = abap_false.
        io_actions->tag( `Button`
            )->a( n = `icon`
                  v = `sap-icon://chain-link`
            )->a( n = `tooltip`
                  t = get_text( cs_text-copy_link )
            )->a( n = `press`
                  v = client->_event( cs_event-copy_link ) ).
      ENDIF.
      "@UI.updateHidden / .deleteHidden - true, or a field of the record;
      "the record's feature control, another user's draft
      IF ms_caps-can_update = abap_true
        AND ms_perm-can_update = abap_true
        AND ms_draft-state <> z2ui5_cl_rap_util=>cs_editing_status-locked
        AND is_hidden_by_annotation( value = ms_entity-update_hidden
                                     row   = ms_data->* ) = abap_false.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-edit )
            )->a( n = `press`
                  v = client->_event( cs_event-edit )
            )->a( n = `type`
                  v = `Emphasized`
            )->a( n = `icon`
                  v = `sap-icon://edit` ).
      ENDIF.
      IF ms_caps-can_delete = abap_true
        AND ms_perm-can_delete = abap_true
        AND ms_draft-state <> z2ui5_cl_rap_util=>cs_editing_status-locked
        AND is_hidden_by_annotation( value = ms_entity-delete_hidden
                                     row   = ms_data->* ) = abap_false.
        io_actions->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-delete )
            )->a( n = `press`
                  v = client->_event( cs_event-delete )
            )->a( n = `type`
                  v = `Reject`
            )->a( n = `icon`
                  v = `sap-icon://delete` ).
      ENDIF.
    ELSE.
      io_actions->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-save )
          )->a( n = `press`
                v = client->_event( cs_event-save )
          )->a( n = `type`
                v = `Emphasized`
          )->a( n = `icon`
                v = `sap-icon://save` ).
      io_actions->tag( `Button`
          )->a( n = `text`
                t = get_text( cs_text-cancel )
          )->a( n = `press`
                v = client->_event( cs_event-cancel )
          )->a( n = `icon`
                v = `sap-icon://decline` ).
    ENDIF.

  ENDMETHOD.


  METHOD render_header_facets.

    DATA lt_facets TYPE z2ui5_cl_rap_util=>ty_t_facet.
    LOOP AT ms_entity-facets INTO DATA(ls_facet) WHERE purpose CS `HEADER`.
      APPEND ls_facet TO lt_facets.
    ENDLOOP.
    SORT lt_facets BY position.

    LOOP AT lt_facets INTO ls_facet.

      "a data point facet names its data point - without a qualifier it
      "would match the first field that has none
      IF ls_facet-type CS `DATAPOINT` AND ls_facet-target_qualifier IS NOT INITIAL.
        "the target qualifier names the data point
        LOOP AT ms_entity-fields INTO DATA(ls_dp)
          WHERE datapoint_qualifier = ls_facet-target_qualifier AND is_hidden = abap_false.
          DATA(lv_state) = `None`.
          IF ls_dp-datapoint_crit_field IS NOT INITIAL.
            lv_state = get_criticality_state( get_crit_value( ls_dp-datapoint_crit_field ) ).
          ENDIF.
          io_container->ele( `VBox`
              )->a( n = `class`
                    v = `sapUiMediumMarginEnd sapUiSmallMarginBottom`
              )->tag( `Label`
                  )->a( n = `text`
                        t = COND #( WHEN ls_facet-label IS NOT INITIAL THEN ls_facet-label ELSE ls_dp-label )
              )->tag( `ObjectStatus`
                  )->a( n = `text`
                        t = get_display_text( ls_dp )
                  )->a( n = `state`
                        t = lv_state
                  )->a( n = `class`
                        v = `sapMObjectStatusLarge` ).
          EXIT.
        ENDLOOP.

      ELSEIF ls_facet-type CS `FIELDGROUP` AND ls_facet-target_qualifier IS NOT INITIAL.
        DATA(lo_block) = io_container->ele( `VBox`
            )->a( n = `class`
                  v = `sapUiMediumMarginEnd sapUiSmallMarginBottom` ).
        IF ls_facet-label IS NOT INITIAL.
          lo_block->tag( `Title`
              )->a( n = `text`
                    t = ls_facet-label
              )->a( n = `level`
                    v = `H5` ).
        ENDIF.
        DATA lt_group TYPE z2ui5_cl_rap_util=>ty_t_field_info.
        CLEAR lt_group.
        LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
          READ TABLE ls_field-field_groups INTO DATA(ls_group) WITH KEY qualifier = ls_facet-target_qualifier.
          IF sy-subrc = 0.
            ls_field-field_group_pos = ls_group-position.
            APPEND ls_field TO lt_group.
          ENDIF.
        ENDLOOP.
        SORT lt_group BY field_group_pos.
        LOOP AT lt_group INTO ls_field.
          lo_block->ele( `HBox`
              )->tag( `Label`
                  )->a( n = `text`
                        t = |{ ls_field-label }:|
                  )->a( n = `class`
                        v = `sapUiTinyMarginEnd`
              )->tag( `Text`
                  )->a( n = `text`
                        t = get_display_text( ls_field ) ).
        ENDLOOP.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_display_text.

    FIELD-SYMBOLS <lv_text> TYPE any.

    DATA lr_one TYPE REF TO data.
    DATA lv_text TYPE string.
    FIELD-SYMBOLS <ls_record> TYPE any.
    FIELD-SYMBOLS <lt_one> TYPE STANDARD TABLE.

    result = get_field_value( is_field ).
    IF is_field-text_element IS INITIAL AND is_field-text_association IS NOT INITIAL AND result IS NOT INITIAL.
      "@ObjectModel.text.association: the text of the association's
      "target (since 2026-10, third round)
      ASSIGN ms_data->* TO <ls_record>.
      CREATE DATA lr_one LIKE STANDARD TABLE OF <ls_record>.
      ASSIGN lr_one->* TO <lt_one>.
      APPEND <ls_record> TO <lt_one>.
      DATA(lt_texts) = read_association_texts( is_entity = ms_entity
                                               is_field  = is_field
                                               data      = lr_one ).
      IF lt_texts IS INITIAL OR lt_texts[ 1 ]-value IS INITIAL.
        RETURN.
      ENDIF.
      lv_text = lt_texts[ 1 ]-value.
    ELSE.
      IF is_field-text_element IS INITIAL.
        RETURN.
      ENDIF.
      ASSIGN COMPONENT is_field-text_element OF STRUCTURE ms_data->* TO <lv_text>.
      IF sy-subrc <> 0 OR <lv_text> IS INITIAL.
        RETURN.
      ENDIF.
      lv_text = |{ <lv_text> }|.
    ENDIF.
    result = SWITCH #( is_field-text_arrangement
      WHEN `TEXT_LAST`     THEN |{ result } ({ lv_text })|
      WHEN `TEXT_ONLY`     THEN lv_text
      WHEN `TEXT_SEPARATE` THEN result
      ELSE |{ lv_text } ({ result })| ).

  ENDMETHOD.


  METHOD render_header_content.

    DATA(lo_hc) = io_op->ele( n  = `headerContent`
                               ns = `uxap` ).
    render_draft_info( io_container = lo_hc
                       client       = client ).
    DATA(lo_hbox) = lo_hc->ele( `FlexBox`
        )->a( n = `wrap`
              v = `Wrap`
        )->a( n = `fitContainer`
              v = `true` ).

    "@UI.headerInfo.imageUrl - the record's image, else typeImageUrl
    DATA(lv_image) = ``.
    IF ms_entity-header_info-image_field IS NOT INITIAL.
      FIELD-SYMBOLS <lv_image> TYPE any.
      ASSIGN COMPONENT ms_entity-header_info-image_field OF STRUCTURE ms_data->* TO <lv_image>.
      IF sy-subrc = 0.
        lv_image = condense( |{ <lv_image> }| ).
      ENDIF.
    ENDIF.
    IF lv_image IS INITIAL.
      lv_image = ms_entity-header_info-type_image_url.
    ENDIF.
    IF lv_image IS NOT INITIAL.
      lo_hbox->tag( `Avatar`
          )->a( n = `src`
                t = lv_image
          )->a( n = `displaySize`
                v = `L`
          )->a( n = `displayShape`
                v = `Square`
          )->a( n = `class`
                v = `sapUiMediumMarginEnd sapUiSmallMarginBottom` ).
    ENDIF.

    "@UI.facet with purpose #HEADER decides the header when there is one
    IF line_exists( ms_entity-facets[ purpose = `#HEADER` ] ) OR line_exists( ms_entity-facets[ purpose = `HEADER` ] ).
      render_header_facets( io_container = lo_hbox
                            client       = client ).
      "the extension's header facets behind them (since 2026-10, third
      "round)
      render_extension( spot         = cs_spot-header_content
                        io_container = lo_hbox
                        client       = client ).
      RETURN.
    ENDIF.

    "identification fields as header attributes - with the entry's
    "criticality and importance (since 2026-10, third round)
    LOOP AT get_identification_fields( ) INTO DATA(ls_id).
      DATA(lv_val_str) = get_field_value( ls_id ).
      IF lv_val_str IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_header_class) = |sapUiSmallMarginEnd sapUiSmallMarginBottom{ SWITCH string( ls_id-entry_importance
        WHEN `LOW`    THEN ` sapUiHideOnPhone sapUiHideOnTablet`
        WHEN `MEDIUM` THEN ` sapUiHideOnPhone` ) }|.
      DATA(lo_attribute) = lo_hbox->ele( `VBox`
          )->a( n = `class`
                t = lv_header_class
          )->tag( `Label`
              )->a( n = `text`
                    t = ls_id-label ).
      IF ls_id-entry_criticality IS NOT INITIAL.
        DATA(lv_header_level) = COND string( WHEN ls_id-entry_criticality CO `0123456789`
                                             THEN ls_id-entry_criticality
                                             ELSE |{ get_crit_value( ls_id-entry_criticality ) }| ).
        lo_attribute->tag( `ObjectStatus`
            )->a( n = `text`
                  t = get_display_text( ls_id )
            )->a( n = `state`
                  t = z2ui5_cl_rap_util=>criticality_binding( lv_header_level ) ).
        DATA(lv_header_icon) = z2ui5_cl_rap_util=>criticality_binding( criticality = lv_header_level
                                                                      kind        = `ICON` ).
        IF ls_id-entry_crit_repr <> `WITHOUT_ICON` AND lv_header_icon IS NOT INITIAL.
          lo_attribute->a( n = `icon`
                           v = lv_header_icon ).
        ENDIF.
      ELSE.
        lo_attribute->tag( `Text`
            )->a( n = `text`
                  t = get_display_text( ls_id ) ).
      ENDIF.
    ENDLOOP.

    "@UI.dataPoint fields as status attributes with criticality
    LOOP AT get_datapoint_fields( ) INTO DATA(ls_dp).
      lv_val_str = get_field_value( ls_dp ).
      IF lv_val_str IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_state) = `None`.
      IF ls_dp-datapoint_crit_field IS NOT INITIAL.
        lv_state = get_criticality_state( get_crit_value( ls_dp-datapoint_crit_field ) ).
      ENDIF.
      lo_hbox->ele( `VBox`
          )->a( n = `class`
                v = `sapUiSmallMarginEnd sapUiSmallMarginBottom`
          )->tag( `Label`
              )->a( n = `text`
                    t = ls_dp-label
          )->tag( `ObjectStatus`
              )->a( n = `text`
                    t = lv_val_str
              )->a( n = `state`
                    t = lv_state ).
    ENDLOOP.

    "the extension's header facets (since 2026-10, third round)
    render_extension( spot         = cs_spot-header_content
                      io_container = lo_hbox
                      client       = client ).

  ENDMETHOD.


  METHOD render_sections.

    DATA lt_ids TYPE string_table.

    DATA(lo_sections) = io_op->ele( n  = `sections`
                                     ns = `uxap` ).

    DATA(lt_sections) = get_sections( ).
    LOOP AT lt_sections INTO DATA(ls_top) WHERE parent_id IS INITIAL.
      APPEND ls_top-id TO lt_ids.
    ENDLOOP.

    "the sections of the facets, and the extension's before or after the
    "facet they name (since 2026-10, third round)
    DATA(lt_custom) = get_custom_sections( ).
    LOOP AT z2ui5_cl_rap_util=>order_sections( ids    = lt_ids
                                               custom = lt_custom ) INTO DATA(ls_slot).
      IF ls_slot-custom = abap_true.
        READ TABLE lt_custom INTO DATA(ls_custom) WITH KEY id = ls_slot-id.
        IF sy-subrc = 0.
          render_custom_section( io_sections = lo_sections
                                 is_custom   = ls_custom
                                 client      = client ).
        ENDIF.
        CONTINUE.
      ENDIF.
      READ TABLE lt_sections INTO DATA(ls_section) WITH KEY id = ls_slot-id parent_id = ``.
      IF sy-subrc = 0.
        render_section( io_sections = lo_sections
                        is_section  = ls_section
                        it_sections = lt_sections
                        client      = client ).
      ENDIF.
    ENDLOOP.

    render_extension( spot         = cs_spot-sections
                      io_container = lo_sections
                      client       = client ).

  ENDMETHOD.


  METHOD render_section.

    "a table section whose target no one resolved has nothing to show
    IF ( is_section-type = `LINEITEM` OR is_section-type = `CHANGE_DOCUMENTS` )
      AND NOT line_exists( mt_child[ section_id = is_section-id ] ).
      RETURN.
    ENDIF.

    DATA(lo_section) = io_sections->ele( n  = `ObjectPageSection`
                                          ns = `uxap`
        )->a( n = `titleUppercase`
              v = `false`
        )->a( n = `title`
              t = is_section-title ).

    DATA(lo_sub_sections) = lo_section->ele( n  = `subSections`
                                              ns = `uxap` ).

    IF is_section-type = `COLLECTION`.
      "one subsection per facet of the collection, each with its title
      LOOP AT it_sections INTO DATA(ls_sub) WHERE parent_id = is_section-id.
        IF ls_sub-type = `LINEITEM` AND NOT line_exists( mt_child[ section_id = ls_sub-id ] ).
          CONTINUE.
        ENDIF.
        DATA(lo_sub_blocks) = lo_sub_sections->ele( n  = `ObjectPageSubSection`
                                                     ns = `uxap`
            )->a( n = `title`
                  t = ls_sub-title
            )->ele( n  = `blocks`
                    ns = `uxap` ).
        render_section_content( io_parent  = lo_sub_blocks
                                is_section = ls_sub
                                client     = client ).
      ENDLOOP.
      RETURN.
    ENDIF.

    "showTitle is @since 1.77 - the repo's UI5 floor (abap2ui5lint.jsonc)
    "is set accordingly
    DATA(lo_blocks) = lo_sub_sections->ele( n  = `ObjectPageSubSection`
                                             ns = `uxap`
        )->a( n = `title`
              t = is_section-title
        )->a( n = `showTitle`
              v = `false`
        )->ele( n  = `blocks`
                 ns = `uxap` ).

    render_section_content( io_parent  = lo_blocks
                            is_section = is_section
                            client     = client ).

  ENDMETHOD.


  METHOD render_custom_section.

    DATA(lo_custom_blocks) = io_sections->ele( n  = `ObjectPageSection`
                                                ns = `uxap`
        )->a( n = `titleUppercase`
              v = `false`
        )->a( n = `title`
              t = is_custom-title
        )->ele( n  = `subSections`
                ns = `uxap`
            )->ele( n  = `ObjectPageSubSection`
                    ns = `uxap`
                )->a( n = `title`
                      t = is_custom-title
                )->a( n = `showTitle`
                      v = `false`
                )->ele( n  = `blocks`
                        ns = `uxap` ).

    render_extension( spot         = cs_spot-custom_section
                      io_container = lo_custom_blocks
                      client       = client
                      section_id   = is_custom-id ).

  ENDMETHOD.


  METHOD get_custom_sections.
    IF mo_ext IS BOUND.
      mo_ext->get_custom_sections( EXPORTING floorplan   = mv_floorplan
                                             entity_name = mv_entity_name
                                   CHANGING  sections    = result ).
    ENDIF.
  ENDMETHOD.


  METHOD render_section_content.

    render_section_actions( io_parent  = io_parent
                            is_section = is_section
                            client     = client ).

    CASE is_section-type.
      WHEN `IDENTIFICATION`.
        "the entries of the facet's targetQualifier (field_group), and the
        "MultiInputs of its entries with an association path
        render_section_fields( io_parent = io_parent
                               it_fields = get_identification_fields( is_section-field_group )
                               client    = client
                               it_paths  = get_path_children( source    = `IDENTIFICATION`
                                                              qualifier = is_section-field_group ) ).
      WHEN `LINEITEM` OR `CHANGE_DOCUMENTS`.
        render_section_table( io_parent  = io_parent
                              is_section = is_section
                              client     = client ).
      WHEN `ADMIN`.
        render_admin_fields( io_parent = io_parent
                             client    = client ).
      WHEN OTHERS.
        render_section_form( io_parent = io_parent
                             iv_group  = is_section-field_group
                             client    = client ).
    ENDCASE.

  ENDMETHOD.


  METHOD render_section_actions.

    DATA lt_actions TYPE z2ui5_cl_rap_util=>ty_t_action.
    DATA lt_groups TYPE z2ui5_cl_rap_util=>ty_t_action_group.

    IF mv_editable = abap_true OR ms_caps-is_rap_bo = abap_false OR is_section-field_group IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_source) = SWITCH string( is_section-type
      WHEN `IDENTIFICATION` THEN `IDENTIFICATION`
      WHEN `FIELDGROUP`     THEN `FIELDGROUP` ).
    IF lv_source IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT ms_entity-actions INTO DATA(ls_action)
      WHERE source = lv_source AND qualifier = is_section-field_group AND semantic_object IS INITIAL.
      APPEND ls_action TO lt_actions.
    ENDLOOP.
    IF lt_actions IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT ms_entity-action_groups INTO DATA(ls_group)
      WHERE source = lv_source AND qualifier = is_section-field_group.
      APPEND ls_group TO lt_groups.
    ENDLOOP.

    DATA(lo_section_bar) = io_parent->ele( `OverflowToolbar`
        )->a( n = `style`
              v = `Clear` ).
    lo_section_bar->tag( `ToolbarSpacer` ).
    render_action_buttons( io_container = lo_section_bar
                           it_actions   = lt_actions
                           it_groups    = lt_groups
                           client       = client
                           event        = cs_event-action
                           row          = ms_data->*
                           disabled     = get_disabled_actions( lt_actions ) ).

  ENDMETHOD.


  METHOD render_section_form.

    "collect and sort fields for this group
    "(empty group = fields without any fieldGroup annotation)
    DATA lt_sorted TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    LOOP AT ms_entity-fields INTO DATA(ls_field) WHERE is_hidden = abap_false.
      IF iv_group IS INITIAL.
        IF ls_field-field_groups IS INITIAL AND ls_field-field_group IS INITIAL.
          APPEND ls_field TO lt_sorted.
        ENDIF.
        CONTINUE.
      ENDIF.
      READ TABLE ls_field-field_groups INTO DATA(ls_group) WITH KEY qualifier = iv_group.
      IF sy-subrc = 0.
        "the position within THIS group - and the entry's criticality,
        "importance and hidden (since 2026-10, third round)
        ls_field-field_group_pos = ls_group-position.
        ls_field-entry_criticality = ls_group-criticality.
        ls_field-entry_crit_repr = ls_group-crit_representation.
        ls_field-entry_importance = ls_group-importance.
        ls_field-entry_hidden = ls_group-hidden.
        IF is_hidden_by_annotation( value = ls_field-entry_hidden
                                    row   = ms_data->* ) = abap_true.
          CONTINUE.
        ENDIF.
        IF ls_group-label IS NOT INITIAL.
          ls_field-label = ls_group-label.
        ENDIF.
        APPEND ls_field TO lt_sorted.
      ELSEIF ls_field-field_group = iv_group.
        APPEND ls_field TO lt_sorted.
      ENDIF.
    ENDLOOP.
    SORT lt_sorted BY field_group_pos.

    "the MultiInputs of the group's entries with an association path - in
    "the general section those of the unqualified identification, which
    "has no section of its own then (since 2026-10, third round)
    DATA(lt_group_paths) = get_path_children( source    = `FIELDGROUP`
                                              qualifier = iv_group ).
    DATA(lt_form_sections) = get_sections( ).
    IF iv_group IS INITIAL AND NOT line_exists( lt_form_sections[ type = `IDENTIFICATION` field_group = `` ] ).
      APPEND LINES OF get_path_children( source    = `IDENTIFICATION`
                                         qualifier = `` ) TO lt_group_paths.
    ENDIF.

    render_section_fields( io_parent = io_parent
                           it_fields = lt_sorted
                           client    = client
                           it_paths  = lt_group_paths ).

  ENDMETHOD.


  METHOD render_section_fields.

    DATA(lo_form) = io_parent->ele( n  = `SimpleForm`
                                     ns = `form`
        )->a( n = `class`
              v = `sapUxAPObjectPageSubSectionAlignContent`
        )->a( n = `editable`
              b = mv_editable
        )->a( n = `layout`
              v = `ColumnLayout`
        )->a( n = `columnsM`
              v = `2`
        )->a( n = `columnsL`
              v = `3`
        )->a( n = `columnsXL`
              v = `4` ).

    DATA(lt_side_effects) = COND string_table( WHEN mv_draft = abap_true AND mv_editable = abap_true
                                               THEN get_side_effect_fields( ) ).

    LOOP AT it_fields INTO DATA(ls_form_field).
      FIELD-SYMBOLS <field> TYPE any.
      ASSIGN COMPONENT ls_form_field-name OF STRUCTURE ms_data->* TO <field>.
      CHECK sy-subrc = 0.
      "read-only and mandatory by the field control in edit mode (since
      "2026-10, third round)
      DATA(ls_field) = ls_form_field.
      IF mv_editable = abap_true.
        ls_field = get_field_for_edit( ls_form_field ).
      ENDIF.

      lo_form->tag( `Label`
          )->a( n = `text`
                t = ls_field-label
          )->a( n = `tooltip`
                t = ls_field-tooltip
          )->a( n = `required`
                b = xsdbool( mv_editable = abap_true AND ls_field-is_mandatory = abap_true ) ).
      "the entry's importance: a LOW one is left out on a phone and a
      "tablet, a MEDIUM one on a phone (since 2026-10, third round)
      DATA(lv_importance_class) = SWITCH string( ls_field-entry_importance
        WHEN `LOW`    THEN `sapUiHideOnPhone sapUiHideOnTablet`
        WHEN `MEDIUM` THEN `sapUiHideOnPhone` ).
      IF lv_importance_class IS NOT INITIAL.
        lo_form->a( n = `class`
                    t = lv_importance_class ).
      ENDIF.

      "=== EDIT MODE: render input controls ===
      IF mv_editable = abap_true.

        "the message of the last save about this field, if there is one
        DATA(lv_value_state) = ``.
        DATA(lv_value_state_text) = ``.
        LOOP AT mt_messages INTO DATA(ls_message).
          IF line_exists( ls_message-fields[ table_line = ls_field-name ] ).
            lv_value_state = SWITCH #( ls_message-type
              WHEN `error`   THEN `Error`
              WHEN `warning` THEN `Warning`
              WHEN `success` THEN `Success`
              ELSE `Information` ).
            lv_value_state_text = ls_message-text.
            EXIT.
          ENDIF.
        ENDLOOP.

        "a key is set once - on create, never on change (get_field_for_edit)
        render_field_input( io_container     = lo_form
                            is_field         = ls_field
                            client           = client
                            value            = <field>
                            editable         = abap_true
                            vh_event         = cs_event-value_help
                            value_state      = lv_value_state
                            value_state_text = lv_value_state_text
                            record           = ms_data->* ).

        "side effects: a change goes into the draft at once - on change,
        "not per keystroke, so one roundtrip per value (since 2026-10,
        "third round). The input is the form's last child here
        IF mv_draft = abap_true AND ls_field-is_readonly = abap_false AND ls_field-is_large_object = abap_false
          AND z2ui5_cl_rap_util=>is_side_effect_field( fields = lt_side_effects
                                                       field  = ls_field-name ) = abap_true.
          DATA(lv_live_event) = COND string( WHEN ls_field-is_boolean = abap_true THEN `select` ELSE `change` ).
          lo_form->a( n = lv_live_event
                      v = client->_event( val = cs_event-side_effect
                                          arg = ls_field-name ) ).
        ENDIF.

      "=== DISPLAY MODE: render read-only controls ===
      ELSE.

        DATA(lv_display_val) = format_value( is_field = ls_field
                                             val      = <field> ).

        "a file (@Semantics.largeObject) -> a link that downloads it
        IF ls_field-is_large_object = abap_true.
          render_file_field( io_container = lo_form
                             is_field     = ls_field
                             client       = client
                             value        = <field>
                             record       = ms_data->*
                             editable     = abap_false ).

        "the criticality of the @UI.fieldGroup / @UI.identification entry
        "-> ObjectStatus with its icon unless #WITHOUT_ICON (since 2026-10,
        "third round)
        ELSEIF ls_field-entry_criticality IS NOT INITIAL.
          DATA(lv_entry_level) = COND string( WHEN ls_field-entry_criticality CO `0123456789`
                                              THEN ls_field-entry_criticality
                                              ELSE |{ get_crit_value( ls_field-entry_criticality ) }| ).
          lo_form->tag( `ObjectStatus`
              )->a( n = `text`
                    t = get_display_text( ls_field )
              )->a( n = `state`
                    t = z2ui5_cl_rap_util=>criticality_binding( lv_entry_level ) ).
          DATA(lv_entry_icon) = z2ui5_cl_rap_util=>criticality_binding( criticality = lv_entry_level
                                                                       kind        = `ICON` ).
          IF ls_field-entry_crit_repr <> `WITHOUT_ICON` AND lv_entry_icon IS NOT INITIAL.
            lo_form->a( n = `icon`
                        v = lv_entry_icon ).
          ENDIF.

        "criticality -> ObjectStatus
        ELSEIF ls_field-datapoint_crit_field IS NOT INITIAL.
          lo_form->tag( `ObjectStatus`
              )->a( n = `text`
                    t = lv_display_val
              )->a( n = `state`
                    v = get_criticality_state( get_crit_value( ls_field-datapoint_crit_field ) ) ).

        "@Semantics.imageUrl -> the image
        ELSEIF ls_field-is_image_url = abap_true AND lv_display_val IS NOT INITIAL.
          lo_form->tag( `Avatar`
              )->a( n = `src`
                    t = lv_display_val
              )->a( n = `displaySize`
                    v = `S`
              )->a( n = `displayShape`
                    v = `Square` ).

        "@Consumption.semanticObject -> a link to the semantic object
        ELSEIF ls_field-semantic_object IS NOT INITIAL AND lv_display_val IS NOT INITIAL.
          lo_form->tag( `Link`
              )->a( n = `text`
                    t = get_display_text( ls_field )
              )->a( n = `press`
                    v = client->_event( val = cs_event-intent
                                        arg = ls_field-name ) ).

        "amount + currency -> ObjectNumber
        ELSEIF ls_field-is_amount_field = abap_true
          AND ls_field-semantics_currency_code IS NOT INITIAL.
          DATA(ls_currency) = VALUE z2ui5_cl_rap_util=>ty_s_field_info(
            name = ls_field-semantics_currency_code ).
          lo_form->tag( `ObjectNumber`
              )->a( n = `number`
                    t = lv_display_val
              )->a( n = `unit`
                    t = get_field_value( ls_currency )
              )->a( n = `emphasized`
                    v = `false` ).

        "quantity + unit -> ObjectNumber
        ELSEIF ls_field-is_quantity_field = abap_true
          AND ls_field-semantics_unit_of_measure IS NOT INITIAL.
          DATA(ls_unit) = VALUE z2ui5_cl_rap_util=>ty_s_field_info(
            name = ls_field-semantics_unit_of_measure ).
          lo_form->tag( `ObjectNumber`
              )->a( n = `number`
                    t = lv_display_val
              )->a( n = `unit`
                    t = get_field_value( ls_unit )
              )->a( n = `emphasized`
                    v = `false` ).

        ELSE.
          lo_form->tag( `Text`
              )->a( n = `text`
                    t = get_display_text( ls_field ) ).
        ENDIF.

      ENDIF.

      IF lv_importance_class IS NOT INITIAL AND ls_field-is_large_object = abap_false.
        lo_form->a( n = `class`
                    t = lv_importance_class ).
      ENDIF.

    ENDLOOP.

    "the MultiInputs of 1:n children (since 2026-10, third round)
    LOOP AT it_paths INTO DATA(ls_form_path).
      render_path_input( io_form  = lo_form
                         is_path  = ls_form_path
                         client   = client ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_section_table.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_rows> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY section_id = is_section-id.
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    "the columns of the child's @UI.lineItem, else its first visible fields
    DATA lt_columns TYPE z2ui5_cl_rap_util=>ty_t_field_info.
    LOOP AT ls_child-entity-fields INTO DATA(ls_field)
      WHERE line_item_pos > 0 AND is_hidden = abap_false.
      APPEND ls_field TO lt_columns.
    ENDLOOP.
    SORT lt_columns BY line_item_pos.
    IF lt_columns IS INITIAL.
      LOOP AT ls_child-entity-fields INTO ls_field WHERE is_hidden = abap_false.
        APPEND ls_field TO lt_columns.
        IF lines( lt_columns ) >= 6.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    "edit mode: the cells of the rows that may be changed are inputs, rows
    "are added and deleted (since 2026-10, third round) - not in a
    "read-only table (the change documents)
    DATA(lv_child_edit) = xsdbool( mv_editable = abap_true AND ls_child-read_only = abap_false ).
    DATA(lv_child_create) = xsdbool( ls_child-can_create = abap_true AND ls_child-read_only = abap_false ).
    DATA(lv_child_delete) = xsdbool( lv_child_edit = abap_true AND ls_child-can_delete = abap_true ).
    DATA(lv_create_event) = COND string( WHEN mv_editable = abap_true THEN cs_event-child_row_add
                                         ELSE cs_event-child_create ).

    "the rows are selectable when the table has actions to run on them
    DATA(lv_child_actions) = xsdbool( ls_child-actions IS NOT INITIAL AND mv_editable = abap_false ).
    DATA(lv_child_mode) = `None`.
    IF lv_child_actions = abap_true.
      lv_child_mode = `MultiSelect`.
    ENDIF.
    DATA(lo_table) = io_parent->ele( `Table`
        )->a( n = `items`
              v = `{path:'` && client->_bind( val  = <lt_rows>
                                              path = abap_true ) && `'}`
        )->a( n = `growing`
              v = `true`
        )->a( n = `mode`
              v = lv_child_mode ).

    "the actions of the child's @UI.lineItem, and a new child of this
    "record - a create by association
    IF lv_child_create = abap_true OR lv_child_actions = abap_true.
      DATA(lo_toolbar) = lo_table->ele( `headerToolbar`
          )->ele( `OverflowToolbar` ).
      lo_toolbar->tag( `ToolbarSpacer` ).
      IF lv_child_actions = abap_true.
        render_action_buttons( io_container = lo_toolbar
                               it_actions   = ls_child-actions
                               it_groups    = ls_child-entity-action_groups
                               client       = client
                               event        = cs_event-child_action
                               args_before  = VALUE #( ( ls_child-component ) )
                               disabled     = ls_child-disabled_actions ).
      ENDIF.
      "display mode: the object page of a new child; edit mode: a new row
      IF lv_child_create = abap_true.
        lo_toolbar->tag( `Button`
            )->a( n = `text`
                  t = get_text( cs_text-create )
            )->a( n = `icon`
                  v = `sap-icon://add`
            )->a( n = `press`
                  v = client->_event( val = lv_create_event
                                      arg = ls_child-component ) ).
      ENDIF.
    ENDIF.

    DATA(lo_columns) = lo_table->ele( `columns` ).
    LOOP AT lt_columns INTO ls_field.
      lo_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text`
                    t = COND #( WHEN ls_field-line_item_label IS NOT INITIAL THEN ls_field-line_item_label
                                ELSE ls_field-label )
              )->a( n = `tooltip`
                    t = ls_field-tooltip ).
    ENDLOOP.
    "the delete button of a row
    IF lv_child_delete = abap_true.
      lo_columns->ele( `Column`
          )->a( n = `width`
                v = `4rem` ).
    ENDIF.

    DATA(lt_arg) = VALUE string_table( ( ls_child-component ) ).
    LOOP AT ls_child-entity-keys INTO DATA(lv_key).
      APPEND `${` && lv_key && `}` TO lt_arg.
    ENDLOOP.

    DATA(lo_item) = lo_table->ele( `items`
        )->ele( `ColumnListItem` ).
    "the child row's criticality (since 2026-10, third round)
    IF ls_child-entity-row_criticality IS NOT INITIAL
      AND line_exists( ls_child-entity-fields[ name = ls_child-entity-row_criticality ] ).
      lo_item->a( n = `highlight`
                  v = criticality_expression( crit_field = ls_child-entity-row_criticality
                                              kind       = `HIGHLIGHT` ) ).
    ENDIF.
    IF lv_child_actions = abap_true.
      lo_item->a( n = `selected`
                  v = |\{{ cv_select_column }\}| ).
    ENDIF.
    "a row opens its own object page - which needs the child's keys; not
    "while the rows are edited, nor a change document
    IF ls_child-entity-keys IS NOT INITIAL AND lv_child_edit = abap_false AND ls_child-read_only = abap_false.
      lo_item->a( n = `type`
                  v = `Navigation`
          )->a( n = `press`
                v = client->_event( val   = cs_event-child_row
                                    t_arg = lt_arg ) ).
    ENDIF.
    DATA(lo_cells) = lo_item->ele( `cells` ).

    LOOP AT lt_columns INTO ls_field.
      IF lv_child_edit = abap_true.
        render_child_cell( io_cells  = lo_cells
                           is_field  = ls_field
                           is_child  = ls_child
                           client    = client ).
      ELSEIF ls_field-datapoint_crit_field IS NOT INITIAL OR ls_field-line_item_crit_field IS NOT INITIAL.
        DATA(lv_child_crit) = COND string( WHEN ls_field-line_item_crit_field IS NOT INITIAL
                                           THEN ls_field-line_item_crit_field
                                           ELSE ls_field-datapoint_crit_field ).
        lo_cells->tag( `ObjectStatus`
            )->a( n = `text`
                  v = |\{{ ls_field-name }\}|
            )->a( n = `state`
                  v = criticality_expression( lv_child_crit ) ).
        "its icon unless #WITHOUT_ICON (since 2026-10, third round)
        IF ls_field-line_item_crit_repr <> `WITHOUT_ICON`.
          lo_cells->a( n = `icon`
                       v = criticality_expression( crit_field = lv_child_crit
                                                   kind       = `ICON` ) ).
        ENDIF.
      ELSE.
        lo_cells->tag( `Text`
            )->a( n = `text`
                  v = |\{{ ls_field-name }\}| ).
      ENDIF.
    ENDLOOP.
    IF lv_child_delete = abap_true.
      lo_cells->tag( `Button`
          )->a( n = `icon`
                v = `sap-icon://delete`
          )->a( n = `type`
                v = `Transparent`
          )->a( n = `tooltip`
                t = get_text( cs_text-delete )
          )->a( n = `enabled`
                v = |\{{ cs_row_flag-deletable }\}|
          )->a( n = `press`
                v = client->_event( val   = cs_event-child_row_delete
                                    t_arg = lt_arg ) ).
    ENDIF.

  ENDMETHOD.


  METHOD load_permissions.

    CLEAR ms_perm.
    IF mv_is_create = abap_true.
      ms_perm = z2ui5_cl_rap_util=>get_instance_permissions(
                  get_permissions( entity_name = mv_entity_name
                                   context     = ms_context ) ).
    ELSE.
      ms_perm = get_row_permissions( entity_name = mv_entity_name
                                     context     = ms_context
                                     row         = ms_data->* ).
    ENDIF.

  ENDMETHOD.


  METHOD get_field_for_edit.

    result = is_field.
    DATA(ls_control) = z2ui5_cl_rap_util=>get_field_control( is_field       = is_field
                                                             it_perm_fields = ms_perm-fields
                                                             is_create      = mv_is_create ).
    result-is_readonly = ls_control-read_only.
    result-is_mandatory = ls_control-mandatory.

  ENDMETHOD.


  METHOD read_own_draft.

    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_drafts> TYPE STANDARD TABLE.

    DATA(lr_rows) = create_entity_table( mv_entity_name ).
    IF lr_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_rows->* TO <lt_rows>.
    APPEND INITIAL LINE TO <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
    MOVE-CORRESPONDING ms_data->* TO <ls_row>.

    DATA(lr_drafts) = read_drafts( entity_name = mv_entity_name
                                   context     = ms_context
                                   rows        = lr_rows ).
    IF lr_drafts IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_drafts->* TO <lt_drafts>.
    READ TABLE <lt_drafts> INDEX 1 REFERENCE INTO result.

  ENDMETHOD.


  METHOD read_draft_status.

    FIELD-SYMBOLS <lv_owner> TYPE any.

    CLEAR ms_draft.
    DATA(lr_draft) = read_own_draft( ).
    IF lr_draft IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_draft->* TO FIELD-SYMBOL(<ls_draft>).
    DATA(lv_owner) = ``.
    READ TABLE ms_entity-fields INTO DATA(ls_by) WITH KEY admin_field = `LAST_CHANGED_BY`.
    IF sy-subrc = 0.
      ASSIGN COMPONENT ls_by-name OF STRUCTURE <ls_draft> TO <lv_owner>.
      IF sy-subrc = 0.
        lv_owner = |{ <lv_owner> }|.
      ENDIF.
    ENDIF.
    ms_draft = z2ui5_cl_rap_util=>get_draft_status( has_draft = abap_true
                                                    owner     = lv_owner
                                                    user      = CONV #( sy-uname ) ).

  ENDMETHOD.


  METHOD resume_draft.

    DATA(lr_draft) = read_own_draft( ).
    IF lr_draft IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_draft->* TO FIELD-SYMBOL(<ls_draft>).
    MOVE-CORRESPONDING <ls_draft> TO ms_data->*.
    IF ms_data_backup IS BOUND.
      ms_data_backup->* = ms_data->*.
    ENDIF.
    mv_draft = abap_true.
    mv_editable = abap_true.
    ms_draft = VALUE #( state = z2ui5_cl_rap_util=>cs_editing_status-own_draft
                        user  = sy-uname ).
    result = abap_true.

  ENDMETHOD.


  METHOD render_draft_info.

    DATA(lv_draft_text) = ``.
    DATA(lv_strip_type) = `Information`.
    IF ms_draft-state = z2ui5_cl_rap_util=>cs_editing_status-locked.
      lv_draft_text = replace( val  = get_text( cs_text-locked_by )
                               sub  = `&1`
                               with = ms_draft-user ).
      lv_strip_type = `Warning`.
    ELSEIF mv_draft = abap_true.
      lv_draft_text = get_text( cs_text-own_draft ).
    ENDIF.
    IF lv_draft_text IS INITIAL.
      RETURN.
    ENDIF.
    io_container->tag( `MessageStrip`
        )->a( n = `text`
              t = lv_draft_text
        )->a( n = `type`
              v = lv_strip_type
        )->a( n = `showIcon`
              v = `true`
        )->a( n = `class`
              v = `sapUiSmallMarginBottom` ).

  ENDMETHOD.


  METHOD get_disabled_actions.
    LOOP AT it_actions INTO DATA(ls_action).
      IF z2ui5_cl_rap_util=>is_permitted( ops  = ms_perm-actions
                                          name = ls_action-name ) = abap_false.
        APPEND ls_action-name TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_side_effect_fields.
    "a business object with draft runs its determinations on every change
    "of the draft - every field may change others, so every field updates
    "it at once; without draft nothing reaches the business object before
    "Save
    IF is_draft_enabled( get_bdef( ) ) = abap_true.
      result = VALUE #( ( `*` ) ).
    ENDIF.
    IF mo_ext IS BOUND.
      mo_ext->get_side_effect_fields( EXPORTING floorplan   = mv_floorplan
                                                entity_name = mv_entity_name
                                      CHANGING  fields      = result ).
    ENDIF.
  ENDMETHOD.


  METHOD on_side_effect.

    IF mv_draft = abap_false OR mv_editable = abap_false.
      RETURN.
    ENDIF.
    "nothing changed - nothing to update (a change event without a change)
    IF z2ui5_cl_rap_util=>get_changed_fields( row      = ms_data->*
                                              original = ms_data_backup->* ) IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_result) = write_draft( entity_name = mv_entity_name
                                   row         = ms_data->*
                                   original    = ms_data_backup->*
                                   context     = ms_context ).
    mt_messages = ls_result-details.
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ms_entity-fields ).
      render_page( client ).
      RETURN.
    ENDIF.
    ms_data_backup->* = ms_data->*.

    "what the determinations changed: the draft read back, its field
    "control and its children
    DATA(lr_side_draft) = read_own_draft( ).
    IF lr_side_draft IS BOUND.
      ASSIGN lr_side_draft->* TO FIELD-SYMBOL(<ls_side_draft>).
      MOVE-CORRESPONDING <ls_side_draft> TO ms_data->*.
      ms_data_backup->* = ms_data->*.
    ENDIF.
    load_permissions( ).
    load_child_rows( ).
    render_page( client ).

  ENDMETHOD.


  METHOD get_admin_fields.

    IF mv_is_create = abap_true.
      RETURN.
    ENDIF.
    LOOP AT z2ui5_cl_rap_util=>get_admin_fields( ms_entity-fields ) INTO DATA(ls_admin).
      "shown in a section of the facets already - no second place
      IF ls_admin-field_groups IS NOT INITIAL OR ls_admin-identifications IS NOT INITIAL.
        CLEAR result.
        RETURN.
      ENDIF.
      IF ls_admin-is_consumption_hidden = abap_true.
        CONTINUE.
      ENDIF.
      APPEND ls_admin TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_admin_fields.

    DATA lv_admin_ts TYPE timestampl.
    FIELD-SYMBOLS <lv_admin_value> TYPE any.

    DATA(lo_admin_form) = io_parent->ele( n  = `SimpleForm`
                                           ns = `form`
        )->a( n = `class`
              v = `sapUxAPObjectPageSubSectionAlignContent`
        )->a( n = `editable`
              v = `false`
        )->a( n = `layout`
              v = `ColumnLayout`
        )->a( n = `columnsM`
              v = `2`
        )->a( n = `columnsL`
              v = `3`
        )->a( n = `columnsXL`
              v = `4` ).

    LOOP AT get_admin_fields( ) INTO DATA(ls_admin).
      ASSIGN COMPONENT ls_admin-name OF STRUCTURE ms_data->* TO <lv_admin_value>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      "a time stamp (DEC) in the user's format and time zone
      DATA(lv_admin_text) = get_display_text( ls_admin ).
      IF ls_admin-type_kind = `DEC` AND <lv_admin_value> IS NOT INITIAL.
        TRY.
            lv_admin_ts = <lv_admin_value>.
            lv_admin_text = |{ lv_admin_ts TIMESTAMP = USER TIMEZONE = sy-zonlo }|.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
      ENDIF.
      lo_admin_form->tag( `Label`
          )->a( n = `text`
                t = ls_admin-label ).
      lo_admin_form->tag( `Text`
          )->a( n = `text`
                t = lv_admin_text ).
    ENDLOOP.

  ENDMETHOD.


  METHOD get_change_documents.

    DATA lt_filter TYPE z2ui5_cl_rap_util=>ty_t_name_value.
    CLEAR: ev_entity, et_filter.
    IF mo_ext IS NOT BOUND OR mv_is_create = abap_true.
      RETURN.
    ENDIF.
    mo_ext->get_change_documents( EXPORTING floorplan   = mv_floorplan
                                            entity_name = mv_entity_name
                                  CHANGING  entity      = ev_entity
                                            filter      = lt_filter ).
    ev_entity = to_upper( ev_entity ).
    IF ev_entity IS INITIAL.
      RETURN.
    ENDIF.
    et_filter = lt_filter.
    "the record's keys under their own names
    IF et_filter IS INITIAL.
      LOOP AT ms_entity-keys INTO DATA(lv_docs_key).
        APPEND VALUE #( name = lv_docs_key value = lv_docs_key ) TO et_filter.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD get_path_children.
    LOOP AT mt_path INTO DATA(ls_path) WHERE field-source = source AND field-qualifier = qualifier.
      APPEND ls_path TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_path_as_child.
    result = VALUE #( component   = is_path-component
                      association = is_path-field-association
                      entity      = is_path-entity
                      can_create  = is_path-can_create
                      can_delete  = is_path-can_delete ).
  ENDMETHOD.


  METHOD get_token_key.

    DATA lt_values TYPE string_table.
    FIELD-SYMBOLS <lv_token_key> TYPE any.
    LOOP AT it_keys INTO DATA(lv_key).
      UNASSIGN <lv_token_key>.
      ASSIGN COMPONENT lv_key OF STRUCTURE row TO <lv_token_key>.
      IF <lv_token_key> IS NOT ASSIGNED.
        APPEND `` TO lt_values.
        CONTINUE.
      ENDIF.
      APPEND condense( |{ <lv_token_key> }| ) TO lt_values.
    ENDLOOP.
    result = concat_lines_of( table = lt_values
                              sep   = cv_key_separator ).

  ENDMETHOD.


  METHOD get_token_keys.

    SPLIT key AT cv_key_separator INTO TABLE DATA(lt_values).
    LOOP AT it_keys INTO DATA(lv_key).
      DATA(lv_value) = VALUE string( ).
      READ TABLE lt_values INDEX sy-tabix INTO lv_value.
      APPEND VALUE #( name = lv_key value = lv_value ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_path_input.

    FIELD-SYMBOLS <ls_all_paths> TYPE any.
    FIELD-SYMBOLS <ls_path_value> TYPE any.
    FIELD-SYMBOLS <lv_path_input> TYPE any.
    FIELD-SYMBOLS <lt_path_tokens> TYPE any.

    IF mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all_paths>.
    ASSIGN COMPONENT is_path-component OF STRUCTURE <ls_all_paths> TO <ls_path_value>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT `INPUT` OF STRUCTURE <ls_path_value> TO <lv_path_input>.
    ASSIGN COMPONENT `TOKENS` OF STRUCTURE <ls_path_value> TO <lt_path_tokens>.
    IF <lv_path_input> IS NOT ASSIGNED OR <lt_path_tokens> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    READ TABLE is_path-entity-fields INTO DATA(ls_path_element) WITH KEY name = is_path-field-element.
    DATA(lv_path_label) = COND string( WHEN is_path-field-label IS NOT INITIAL THEN is_path-field-label
                                       ELSE ls_path_element-label ).
    "what edit mode allows: a new token where a child may be created, its
    "value help, deleting a token where a child may be deleted
    DATA(lv_path_edit) = xsdbool( mv_editable = abap_true
                                  AND ( is_path-can_create = abap_true OR is_path-can_delete = abap_true ) ).
    DATA(lv_path_vh) = xsdbool( mv_editable = abap_true AND is_path-can_create = abap_true
                                AND ls_path_element-value_help-entity_name IS NOT INITIAL ).
    DATA(lv_token_delete) = xsdbool( mv_editable = abap_true AND is_path-can_delete = abap_true ).

    io_form->tag( `Label`
        )->a( n = `text`
              t = lv_path_label ).
    io_form->ele( `MultiInput`
        )->a( n = `value`
              v = client->_bind( <lv_path_input> )
        )->a( n = `tokens`
              v = client->_bind( <lt_path_tokens> )
        )->a( n = `editable`
              b = lv_path_edit
        )->a( n = `showValueHelp`
              b = lv_path_vh
        )->a( n = `valueHelpRequest`
              v = client->_event( val = cs_event-path_value_help
                                  arg = is_path-component )
        )->a( n = `submit`
              v = client->_event( val = cs_event-path_token_add
                                  arg = is_path-component )
        )->a( n = `width`
              v = `100%`
        )->ele( `tokens`
            )->tag( `Token`
                )->a( n = `key`
                      v = `{KEY}`
                )->a( n = `text`
                      v = `{TEXT}`
                )->a( n = `editable`
                      b = lv_token_delete
                )->a( n = `delete`
                      v = client->_event( val   = cs_event-path_token_delete
                                          t_arg = VALUE #( ( is_path-component ) ( `${KEY}` ) ) ) ).

  ENDMETHOD.


  METHOD add_path_token.

    FIELD-SYMBOLS <ls_all_paths> TYPE any.
    FIELD-SYMBOLS <ls_path_value> TYPE any.
    FIELD-SYMBOLS <lv_path_input> TYPE any.
    FIELD-SYMBOLS <lt_path_tokens> TYPE ty_t_token.

    READ TABLE mt_path INTO DATA(ls_path) WITH KEY component = component.
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all_paths>.
    ASSIGN COMPONENT component OF STRUCTURE <ls_all_paths> TO <ls_path_value>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT `INPUT` OF STRUCTURE <ls_path_value> TO <lv_path_input>.
    ASSIGN COMPONENT `TOKENS` OF STRUCTURE <ls_path_value> TO <lt_path_tokens>.
    IF <lv_path_input> IS NOT ASSIGNED OR <lt_path_tokens> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    DATA(lv_value) = condense( COND string( WHEN value IS SUPPLIED THEN value ELSE <lv_path_input> ) ).
    CLEAR <lv_path_input>.
    "decided here, whatever the browser sends: edit mode, and a child may be
    "created under this record
    IF lv_value IS INITIAL OR line_exists( <lt_path_tokens>[ text = lv_value ] ).
      render_page( client ).
      RETURN.
    ENDIF.
    IF mv_editable = abap_false OR ls_path-can_create = abap_false.
      client->message_box_display( text = get_text( cs_text-not_allowed )
                                   type = `error` ).
      RETURN.
    ENDIF.

    "the value, and the fields that point at this record
    get_child_filter( EXPORTING is_child  = get_path_as_child( ls_path )
                      IMPORTING et_values = DATA(lt_values) ).
    APPEND VALUE #( name = ls_path-field-element value = lv_value ) TO lt_values.

    "without draft: written on Save
    IF mv_draft = abap_false.
      APPEND VALUE #( component = component
                      operation = `CREATE`
                      value     = lv_value ) TO mt_pending.
      APPEND VALUE #( key  = |+{ lv_value }|
                      text = lv_value ) TO <lt_path_tokens>.
      render_page( client ).
      RETURN.
    ENDIF.

    "in the draft at once - a create by association under this record
    DATA(lr_new) = create_host( entity_name = ls_path-entity-name
                                values      = lt_values ).
    IF lr_new IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_new->* TO FIELD-SYMBOL(<ls_new>).
    DATA(ls_result) = write_row( entity_name = ls_path-entity-name
                                 operation   = `CREATE`
                                 row         = <ls_new>
                                 context     = get_child_context( ls_path-field-association )
                                 in_draft    = abap_true ).
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ls_path-entity-fields ).
      RETURN.
    ENDIF.
    load_child_rows( ).
    render_page( client ).

  ENDMETHOD.


  METHOD delete_path_token.

    FIELD-SYMBOLS <ls_all_paths> TYPE any.
    FIELD-SYMBOLS <ls_path_value> TYPE any.
    FIELD-SYMBOLS <lt_path_tokens> TYPE ty_t_token.

    READ TABLE mt_path INTO DATA(ls_path) WITH KEY component = component.
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND
      OR mv_editable = abap_false OR ls_path-can_delete = abap_false.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all_paths>.
    ASSIGN COMPONENT component OF STRUCTURE <ls_all_paths> TO <ls_path_value>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT `TOKENS` OF STRUCTURE <ls_path_value> TO <lt_path_tokens>.
    IF sy-subrc <> 0 OR NOT line_exists( <lt_path_tokens>[ key = key ] ).
      RETURN.
    ENDIF.

    "a token not written yet - forgotten
    IF strlen( key ) > 1 AND key(1) = `+`.
      DATA(lv_pending_value) = substring( val = key off = 1 ).
      DELETE mt_pending WHERE component = component AND operation = `CREATE` AND value = lv_pending_value.
      DELETE <lt_path_tokens> WHERE key = key.
      render_page( client ).
      RETURN.
    ENDIF.

    DATA(lt_keys) = get_token_keys( it_keys = ls_path-entity-keys
                                    key     = key ).
    "without draft: deleted on Save
    IF mv_draft = abap_false.
      APPEND VALUE #( component = component
                      operation = `DELETE`
                      keys      = lt_keys ) TO mt_pending.
      DELETE <lt_path_tokens> WHERE key = key.
      render_page( client ).
      RETURN.
    ENDIF.

    DATA(lr_old) = create_host( entity_name = ls_path-entity-name
                                values      = lt_keys ).
    IF lr_old IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_old->* TO FIELD-SYMBOL(<ls_old>).
    DATA(ls_context) = get_child_context( ls_path-field-association ).
    CLEAR: ls_context-association, ls_context-parent_fields.
    DATA(ls_result) = write_row( entity_name = ls_path-entity-name
                                 operation   = `DELETE`
                                 row         = <ls_old>
                                 context     = ls_context
                                 in_draft    = abap_true ).
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ls_path-entity-fields ).
      RETURN.
    ENDIF.
    load_child_rows( ).
    render_page( client ).

  ENDMETHOD.


  METHOD read_child_rows.

    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lt_parent> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_draft_children> TYPE ANY TABLE.
    FIELD-SYMBOLS <lt_result> TYPE ANY TABLE.

    "the children of the draft the page edits - READ ENTITIES BY its
    "association, the database does not have them
    IF mv_draft = abap_true AND is_child-read_only = abap_false AND is_child-association IS NOT INITIAL.
      DATA(lr_parent) = create_entity_table( mv_entity_name ).
      IF lr_parent IS BOUND.
        ASSIGN lr_parent->* TO <lt_parent>.
        APPEND INITIAL LINE TO <lt_parent> ASSIGNING FIELD-SYMBOL(<ls_parent>).
        MOVE-CORRESPONDING ms_data->* TO <ls_parent>.
        DATA(lr_draft_children) = read_draft_children( entity_name = mv_entity_name
                                                       association = is_child-association
                                                       context     = ms_context
                                                       rows        = lr_parent ).
        IF lr_draft_children IS BOUND.
          result = create_entity_table( entity_name    = is_child-entity-name
                                        with_selection = abap_true ).
          IF result IS BOUND.
            ASSIGN lr_draft_children->* TO <lt_draft_children>.
            ASSIGN result->* TO <lt_result>.
            MOVE-CORRESPONDING <lt_draft_children> TO <lt_result>.
            RETURN.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT it_values INTO DATA(ls_value).
      APPEND ls_value-name TO lt_names.
    ENDLOOP.
    result = select_rows( entity_name    = is_child-entity-name
                          where          = build_key_condition( lt_names )
                          host           = create_host( entity_name = is_child-entity-name
                                                        values      = it_values )
                          with_selection = abap_true ).

  ENDMETHOD.


  METHOD add_row_flags.

    DATA lt_comp TYPE cl_abap_structdescr=>component_table.
    DATA lt_flags TYPE string_table.
    DATA lt_row_keys TYPE ty_t_name_value.
    DATA lv_flag TYPE abap_bool.
    FIELD-SYMBOLS <lt_in> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_out> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_row_key> TYPE any.
    FIELD-SYMBOLS <lv_row_flag> TYPE any.

    IF rows IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lo_table) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( rows ) ).
    DATA(lo_line) = CAST cl_abap_structdescr( lo_table->get_table_line_type( ) ).
    lt_comp = lo_line->get_components( ).
    DATA(lo_flag) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data( lv_flag ) ).
    lt_flags = VALUE #( ( cs_row_flag-updatable ) ( cs_row_flag-deletable ) ( cs_row_flag-new ) ).
    LOOP AT lt_flags INTO DATA(lv_flag_name).
      IF NOT line_exists( lt_comp[ name = lv_flag_name ] ).
        APPEND VALUE #( name = lv_flag_name
                        type = lo_flag ) TO lt_comp.
      ENDIF.
    ENDLOOP.
    DATA(lo_out_line) = cl_abap_structdescr=>create( lt_comp ).
    DATA(lo_out_table) = cl_abap_tabledescr=>create( p_line_type = lo_out_line ).
    CREATE DATA result TYPE HANDLE lo_out_table.
    ASSIGN rows->* TO <lt_in>.
    ASSIGN result->* TO <lt_out>.
    MOVE-CORRESPONDING <lt_in> TO <lt_out>.

    "what GET PERMISSIONS answers: the static field control of the child
    "(its read-only fields), and per instance whether it may be changed or
    "deleted - asked only where edit mode needs it
    IF mv_editable = abap_false OR cs_child-read_only = abap_true
      OR ( cs_child-can_update = abap_false AND cs_child-can_delete = abap_false ).
      RETURN.
    ENDIF.
    DATA(ls_child_perms) = get_permissions( entity_name = cs_child-entity-name
                                            context     = get_child_context( cs_child-association )
                                            rows        = rows ).
    IF ls_child_perms-answered = abap_true.
      LOOP AT ls_child_perms-global-fields INTO DATA(ls_static)
        WHERE read_only = abap_true OR read_only_update = abap_true.
        READ TABLE cs_child-entity-fields ASSIGNING FIELD-SYMBOL(<ls_static_field>) WITH KEY name = ls_static-name.
        IF sy-subrc = 0.
          <ls_static_field>-is_readonly = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.

    LOOP AT <lt_out> ASSIGNING FIELD-SYMBOL(<ls_out>).
      CLEAR lt_row_keys.
      LOOP AT cs_child-entity-keys INTO DATA(lv_row_key_name).
        UNASSIGN <lv_row_key>.
        ASSIGN COMPONENT lv_row_key_name OF STRUCTURE <ls_out> TO <lv_row_key>.
        IF <lv_row_key> IS ASSIGNED.
          APPEND VALUE #( name = lv_row_key_name value = |{ <lv_row_key> }| ) TO lt_row_keys.
        ENDIF.
      ENDLOOP.
      DATA(ls_instance) = z2ui5_cl_rap_util=>get_instance_permissions( is_permissions = ls_child_perms
                                                                      keys           = lt_row_keys ).
      ASSIGN COMPONENT cs_row_flag-updatable OF STRUCTURE <ls_out> TO <lv_row_flag>.
      <lv_row_flag> = xsdbool( cs_child-can_update = abap_true AND ls_instance-can_update = abap_true
                               AND is_hidden_by_annotation( value = cs_child-entity-update_hidden
                                                            row   = <ls_out> ) = abap_false ).
      ASSIGN COMPONENT cs_row_flag-deletable OF STRUCTURE <ls_out> TO <lv_row_flag>.
      <lv_row_flag> = xsdbool( cs_child-can_delete = abap_true AND ls_instance-can_delete = abap_true
                               AND is_hidden_by_annotation( value = cs_child-entity-delete_hidden
                                                            row   = <ls_out> ) = abap_false ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_child_cell.

    DATA(lv_cell_path) = |\{{ is_field-name }\}|.
    "the fields the composition fills point at this record - not changed
    DATA(lt_cell_parent) = get_child_context( is_child-association )-parent_fields.
    DATA(lv_cell_editable) = COND string(
      WHEN is_field-is_key = abap_true
      THEN |\{{ cs_row_flag-new }\}|
      WHEN is_child-can_update = abap_false OR is_field-is_readonly = abap_true
        OR is_field-is_large_object = abap_true OR is_field-is_virtual = abap_true
        OR line_exists( lt_cell_parent[ table_line = is_field-name ] )
      THEN ``
      ELSE |\{{ cs_row_flag-updatable }\}| ).
    IF lv_cell_editable IS INITIAL.
      io_cells->tag( `Text`
          )->a( n = `text`
                v = lv_cell_path ).
      RETURN.
    ENDIF.

    "a change goes into the draft at once where the page edits one
    "(cs_event-child_cell_change decides) - on change, not per keystroke
    IF is_field-is_boolean = abap_true.
      io_cells->tag( `CheckBox`
          )->a( n = `selected`
                v = lv_cell_path
          )->a( n = `editable`
                v = lv_cell_editable
          )->a( n = `select`
                v = client->_event( val = cs_event-child_cell_change
                                    arg = is_child-component ) ).
    ELSEIF is_field-type_kind = `DATS`.
      io_cells->tag( `DatePicker`
          )->a( n = `value`
                v = lv_cell_path
          )->a( n = `valueFormat`
                v = `yyyy-MM-dd`
          )->a( n = `editable`
                v = lv_cell_editable
          )->a( n = `change`
                v = client->_event( val = cs_event-child_cell_change
                                    arg = is_child-component ) ).
    ELSEIF is_field-type_kind = `TIMS`.
      io_cells->tag( `TimePicker`
          )->a( n = `value`
                v = lv_cell_path
          )->a( n = `valueFormat`
                v = `HH:mm:ss`
          )->a( n = `editable`
                v = lv_cell_editable
          )->a( n = `change`
                v = client->_event( val = cs_event-child_cell_change
                                    arg = is_child-component ) ).
    ELSE.
      DATA(lv_cell_length) = COND string( WHEN is_field-type_kind = `CHAR` AND is_field-length > 0
                                          THEN |{ is_field-length }|
                                          ELSE `0` ).
      io_cells->tag( `Input`
          )->a( n = `value`
                v = lv_cell_path
          )->a( n = `maxLength`
                t = lv_cell_length
          )->a( n = `editable`
                v = lv_cell_editable
          )->a( n = `change`
                v = client->_event( val = cs_event-child_cell_change
                                    arg = is_child-component ) ).
    ENDIF.

  ENDMETHOD.


  METHOD on_child_row_add.

    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_add_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_add_flag> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND OR mv_editable = abap_false
      OR ls_child-read_only = abap_true OR ls_child-can_create = abap_false.
      RETURN.
    ENDIF.
    get_child_filter( EXPORTING is_child  = ls_child
                      IMPORTING et_values = DATA(lt_values) ).
    DATA(lr_new) = create_host( entity_name = ls_child-entity-name
                                values      = lt_values ).
    IF lr_new IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_new->* TO FIELD-SYMBOL(<ls_new>).

    "without draft: a new row, created on Save
    IF mv_draft = abap_false.
      ASSIGN mr_child_rows->* TO <ls_all>.
      ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_add_rows>.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      APPEND INITIAL LINE TO <lt_add_rows> ASSIGNING FIELD-SYMBOL(<ls_added>).
      MOVE-CORRESPONDING <ls_new> TO <ls_added>.
      ASSIGN COMPONENT cs_row_flag-new OF STRUCTURE <ls_added> TO <lv_add_flag>.
      <lv_add_flag> = abap_true.
      ASSIGN COMPONENT cs_row_flag-updatable OF STRUCTURE <ls_added> TO <lv_add_flag>.
      <lv_add_flag> = abap_true.
      ASSIGN COMPONENT cs_row_flag-deletable OF STRUCTURE <ls_added> TO <lv_add_flag>.
      <lv_add_flag> = abap_true.
      render_page( client ).
      RETURN.
    ENDIF.

    "in the draft at once - its determinations fill what they fill
    DATA(ls_result) = write_row( entity_name = ls_child-entity-name
                                 operation   = `CREATE`
                                 row         = <ls_new>
                                 context     = get_child_context( ls_child-association )
                                 in_draft    = abap_true ).
    IF ls_result-success = abap_false.
      show_messages( client   = client
                     messages = ls_result-messages
                     details  = ls_result-details
                     fields   = ls_child-entity-fields ).
      RETURN.
    ENDIF.
    load_child_rows( ).
    render_page( client ).

  ENDMETHOD.


  METHOD on_child_row_delete.

    DATA lr_any TYPE REF TO data.
    DATA lv_index TYPE i.
    DATA lt_keys TYPE ty_t_name_value.
    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_del_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_del_flag> TYPE any.
    FIELD-SYMBOLS <lv_del_key> TYPE any.

    READ TABLE mt_child INTO DATA(ls_child) WITH KEY component = client->get_event_arg( ).
    IF sy-subrc <> 0 OR mr_child_rows IS NOT BOUND OR mv_editable = abap_false
      OR ls_child-read_only = abap_true OR ls_child-can_delete = abap_false.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    ASSIGN COMPONENT ls_child-component OF STRUCTURE <ls_all> TO <lt_del_rows>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lr_row) = find_row_by_event_keys( data       = REF #( <lt_del_rows> )
                                           key_fields = ls_child-entity-keys
                                           client     = client
                                           arg_offset = 1 ).
    IF lr_row IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_row->* TO FIELD-SYMBOL(<ls_del>).
    ASSIGN COMPONENT cs_row_flag-new OF STRUCTURE <ls_del> TO <lv_del_flag>.
    DATA(lv_is_new) = xsdbool( sy-subrc = 0 AND <lv_del_flag> = abap_true ).

    IF mv_draft = abap_true AND lv_is_new = abap_false.
      DATA(lr_entity_row) = to_entity_row( entity_name = ls_child-entity-name
                                           row         = <ls_del> ).
      ASSIGN lr_entity_row->* TO FIELD-SYMBOL(<ls_del_entity>).
      DATA(ls_context) = get_child_context( ls_child-association ).
      CLEAR: ls_context-association, ls_context-parent_fields.
      DATA(ls_result) = write_row( entity_name = ls_child-entity-name
                                   operation   = `DELETE`
                                   row         = <ls_del_entity>
                                   context     = ls_context
                                   in_draft    = abap_true ).
      IF ls_result-success = abap_false.
        show_messages( client   = client
                       messages = ls_result-messages
                       details  = ls_result-details
                       fields   = ls_child-entity-fields ).
        RETURN.
      ENDIF.
      load_child_rows( ).
      render_page( client ).
      RETURN.
    ENDIF.

    "without draft: deleted on Save - a new row is simply gone
    IF lv_is_new = abap_false.
      LOOP AT ls_child-entity-keys INTO DATA(lv_key).
        UNASSIGN <lv_del_key>.
        ASSIGN COMPONENT lv_key OF STRUCTURE <ls_del> TO <lv_del_key>.
        IF <lv_del_key> IS ASSIGNED.
          APPEND VALUE #( name = lv_key value = |{ <lv_del_key> }| ) TO lt_keys.
        ENDIF.
      ENDLOOP.
      APPEND VALUE #( component = ls_child-component
                      operation = `DELETE`
                      keys      = lt_keys ) TO mt_pending.
    ENDIF.
    LOOP AT <lt_del_rows> ASSIGNING FIELD-SYMBOL(<ls_any>).
      lr_any = REF #( <ls_any> ).
      IF lr_any = lr_row.
        lv_index = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lv_index > 0.
      DELETE <lt_del_rows> INDEX lv_index.
    ENDIF.
    render_page( client ).

  ENDMETHOD.


  METHOD get_child_original.

    DATA lt_values TYPE ty_t_name_value.
    DATA lt_names TYPE string_table.
    FIELD-SYMBOLS <lt_one> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_found> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_original_key> TYPE any.

    LOOP AT is_child-entity-keys INTO DATA(lv_key).
      UNASSIGN <lv_original_key>.
      ASSIGN COMPONENT lv_key OF STRUCTURE row TO <lv_original_key>.
      IF <lv_original_key> IS NOT ASSIGNED.
        RETURN.
      ENDIF.
      APPEND VALUE #( name = lv_key value = |{ <lv_original_key> }| ) TO lt_values.
      APPEND lv_key TO lt_names.
    ENDLOOP.
    IF lt_values IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_found TYPE REF TO data.
    IF in_draft = abap_true.
      DATA(lr_one) = create_entity_table( is_child-entity-name ).
      IF lr_one IS NOT BOUND.
        RETURN.
      ENDIF.
      ASSIGN lr_one->* TO <lt_one>.
      APPEND INITIAL LINE TO <lt_one> ASSIGNING FIELD-SYMBOL(<ls_one>).
      MOVE-CORRESPONDING row TO <ls_one>.
      DATA(ls_context) = get_child_context( is_child-association ).
      CLEAR: ls_context-association, ls_context-parent_fields.
      lr_found = read_drafts( entity_name = is_child-entity-name
                              context     = ls_context
                              rows        = lr_one ).
    ELSE.
      lr_found = select_rows( entity_name = is_child-entity-name
                              where       = build_key_condition( lt_names )
                              max_rows    = 1
                              host        = create_host( entity_name = is_child-entity-name
                                                         values      = lt_values ) ).
    ENDIF.
    IF lr_found IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN lr_found->* TO <lt_found>.
    READ TABLE <lt_found> INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_found>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    result = create_host( entity_name = is_child-entity-name
                          values      = VALUE #( ) ).
    IF result IS BOUND.
      ASSIGN result->* TO FIELD-SYMBOL(<ls_original>).
      MOVE-CORRESPONDING <ls_found> TO <ls_original>.
    ENDIF.

  ENDMETHOD.


  METHOD write_children.

    DATA lt_failed TYPE ty_t_pending.
    DATA ls_one TYPE ty_s_result.
    DATA lr_pending_row TYPE REF TO data.
    DATA ls_write_child TYPE ty_s_child.
    FIELD-SYMBOLS <ls_all> TYPE any.
    FIELD-SYMBOLS <lt_write_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_write_flag> TYPE any.

    result-success = abap_true.

    "the writes held back until Save - a token created or deleted, a row
    "deleted
    LOOP AT mt_pending INTO DATA(ls_pending).
      CLEAR ls_one.
      READ TABLE mt_path INTO DATA(ls_pending_path) WITH KEY component = ls_pending-component.
      IF sy-subrc = 0.
        ls_write_child = get_path_as_child( ls_pending_path ).
      ELSE.
        READ TABLE mt_child INTO ls_write_child WITH KEY component = ls_pending-component.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.
      DATA(ls_pending_context) = get_child_context( ls_write_child-association ).
      IF ls_pending-operation = `CREATE`.
        get_child_filter( EXPORTING is_child  = ls_write_child
                          IMPORTING et_values = DATA(lt_pending_values) ).
        APPEND VALUE #( name = ls_pending_path-field-element value = ls_pending-value ) TO lt_pending_values.
        lr_pending_row = create_host( entity_name = ls_write_child-entity-name
                                      values      = lt_pending_values ).
      ELSE.
        CLEAR: ls_pending_context-association, ls_pending_context-parent_fields.
        lr_pending_row = create_host( entity_name = ls_write_child-entity-name
                                      values      = ls_pending-keys ).
      ENDIF.
      IF lr_pending_row IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN lr_pending_row->* TO FIELD-SYMBOL(<ls_pending_row>).
      ls_one = write_row( entity_name = ls_write_child-entity-name
                          operation   = ls_pending-operation
                          row         = <ls_pending_row>
                          context     = ls_pending_context ).
      IF ls_one-success = abap_false.
        result-success = abap_false.
        APPEND LINES OF ls_one-messages TO result-messages.
        APPEND LINES OF ls_one-details TO result-details.
        APPEND ls_pending TO lt_failed.
      ENDIF.
    ENDLOOP.
    mt_pending = lt_failed.

    "the rows of the child tables: new ones created (without draft - in a
    "draft they are there already), changed ones updated
    IF mr_child_rows IS NOT BOUND.
      RETURN.
    ENDIF.
    ASSIGN mr_child_rows->* TO <ls_all>.
    LOOP AT mt_child INTO ls_write_child WHERE read_only = abap_false.
      ASSIGN COMPONENT ls_write_child-component OF STRUCTURE <ls_all> TO <lt_write_rows>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(ls_row_context) = get_child_context( ls_write_child-association ).
      DATA(ls_update_context) = ls_row_context.
      CLEAR: ls_update_context-association, ls_update_context-parent_fields.
      LOOP AT <lt_write_rows> ASSIGNING FIELD-SYMBOL(<ls_write_row>).
        CLEAR ls_one.
        DATA(lr_write_entity) = to_entity_row( entity_name = ls_write_child-entity-name
                                               row         = <ls_write_row> ).
        IF lr_write_entity IS NOT BOUND.
          CONTINUE.
        ENDIF.
        ASSIGN lr_write_entity->* TO FIELD-SYMBOL(<ls_write_entity>).
        UNASSIGN <lv_write_flag>.
        ASSIGN COMPONENT cs_row_flag-new OF STRUCTURE <ls_write_row> TO <lv_write_flag>.
        IF <lv_write_flag> IS ASSIGNED AND <lv_write_flag> = abap_true.
          IF in_draft = abap_true.
            CONTINUE.
          ENDIF.
          ls_one = write_row( entity_name = ls_write_child-entity-name
                              operation   = `CREATE`
                              row         = <ls_write_entity>
                              context     = ls_row_context ).
          IF ls_one-success = abap_true.
            <lv_write_flag> = abap_false.
          ENDIF.
        ELSE.
          DATA(lr_original) = get_child_original( is_child = ls_write_child
                                                  row      = <ls_write_entity>
                                                  in_draft = in_draft ).
          IF lr_original IS NOT BOUND.
            CONTINUE.
          ENDIF.
          ASSIGN lr_original->* TO FIELD-SYMBOL(<ls_original>).
          IF z2ui5_cl_rap_util=>get_changed_fields( row      = <ls_write_entity>
                                                    original = <ls_original> ) IS INITIAL.
            CONTINUE.
          ENDIF.
          "checked like every write: the instance's permission, its
          "read-only fields - what the cells sent decides nothing
          IF in_draft = abap_true.
            ls_one = write_draft( entity_name = ls_write_child-entity-name
                                  row         = <ls_write_entity>
                                  original    = <ls_original>
                                  context     = ls_update_context
                                  check       = abap_true ).
          ELSE.
            ls_one = write_row( entity_name = ls_write_child-entity-name
                                operation   = `UPDATE`
                                row         = <ls_write_entity>
                                original    = <ls_original>
                                context     = ls_update_context ).
          ENDIF.
        ENDIF.
        IF ls_one-success = abap_false.
          result-success = abap_false.
          APPEND LINES OF ls_one-messages TO result-messages.
          APPEND LINES OF ls_one-details TO result-details.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
