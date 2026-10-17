"! Extension points of the floorplans, for changing one without writing a
"! subclass of it. Hand an implementation to any floorplan with
"! set_extension( ); every method is DEFAULT IGNORE, so an implementation
"! redefines only what it needs.
"!
"! floorplan is one of the z2ui5_cl_rap_floorplan=>cs_floorplan values, so
"! one implementation can serve several floorplans.
"!
"! The extension object travels with the app through the abap2UI5 draft -
"! that is why this interface includes if_serializable_object. Keep its
"! attributes serializable (no references to non-serializable objects).
"!
"! Subclassing a floorplan is the other escape hatch (README, "The Escape
"! Hatch") - a changed rendering belongs there; this interface changes
"! data, metadata, texts and events, and adds controls at fixed places
"! (extend_view).
INTERFACE z2ui5_if_rap_ext
  PUBLIC.

  INTERFACES if_serializable_object.

  "! change the metadata before anything is rendered from it - labels,
  "! hidden fields, positions, field groups, value helps, actions
  METHODS adjust_entity DEFAULT IGNORE
    IMPORTING
      floorplan TYPE string
    CHANGING
      entity    TYPE z2ui5_cl_rap_util=>ty_s_entity_info.

  "! change the dynamic WHERE clause of a read (ABAP SQL syntax)
  METHODS adjust_where DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      where       TYPE string.

  "! the rows of a read, after the SELECT - a table of the entity
  METHODS after_load DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
      data        TYPE REF TO data.

  "! before a create, update, delete or action is written; add messages
  "! and set cancel to stop it
  METHODS before_save DEFAULT IGNORE
    IMPORTING
      entity_name TYPE string
      operation   TYPE string
      data        TYPE REF TO data
    CHANGING
      messages    TYPE string_table
      cancel      TYPE abap_bool.

  METHODS after_save DEFAULT IGNORE
    IMPORTING
      entity_name TYPE string
      operation   TYPE string
      data        TYPE REF TO data.

  "! every event, before the floorplan handles it; return abap_true to
  "! take it over
  METHODS on_event DEFAULT IGNORE
    IMPORTING
      floorplan     TYPE string
      client        TYPE REF TO z2ui5_if_client
    RETURNING
      VALUE(result) TYPE abap_bool.

  "! the texts of the floorplans (buttons, titles, messages) - the key is
  "! one of z2ui5_cl_rap_floorplan=>cs_text; change text to translate
  METHODS get_text DEFAULT IGNORE
    IMPORTING
      key  TYPE string
    CHANGING
      text TYPE string.

  "! add controls to a view the floorplan builds - spot is one of
  "! z2ui5_cl_rap_floorplan=>cs_spot, container the builder node there. An
  "! event of an added control arrives in on_event first. Two limits: a
  "! binding reaches only PUBLIC attributes of the floorplan (the app), not
  "! the extension's own - use events and constant values; and a control
  "! from another library declares its own xmlns (a( n = `xmlns:core` ... ))
  "! At cs_spot-custom_section, section_id is the id of the section of
  "! get_custom_sections being rendered - container is its blocks
  "! aggregation (added 2026-10, third round)
  METHODS extend_view DEFAULT IGNORE
    IMPORTING
      floorplan  TYPE string
      spot       TYPE string
      container  TYPE REF TO z2ui5_cl_ui5_view_builder
      client     TYPE REF TO z2ui5_if_client
      section_id TYPE string OPTIONAL.

  "! what the floorplans offer to write for entity_name - the operations
  "! its BDEF defines, and nothing for a database table. Set can_create,
  "! can_update and can_delete of a table to switch its writes on (the
  "! user still needs S_TABU_NAM for it), clear one of a business object to
  "! withhold it; is_rap_bo and is_table are what the entity is and stay.
  "! An operation the BDEF lacks cannot be added here
  METHODS adjust_capabilities DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      caps        TYPE z2ui5_cl_rap_floorplan=>ty_s_capabilities.

  "! the class of a z2ui5_cl_rap_start subclass: the link the object page
  "! copies then opens the record through it - a link that outlives the
  "! abap2UI5 draft. Without one the link restores the app's state, which
  "! lasts as long as its draft
  METHODS get_start_app DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      start_app   TYPE string.

  "! the CDS entity an association of entity_name leads to - needed for a
  "! #LINEITEM_REFERENCE facet, whose target the annotations do not name
  METHODS resolve_association DEFAULT IGNORE
    IMPORTING
      entity_name TYPE string
      association TYPE string
    CHANGING
      target      TYPE string.

  "! an inbound parameter of a link or a launchpad tile, before
  "! z2ui5_cl_rap_start hands it to the floorplan: for a list report or a
  "! worklist the value of the filter of the field it names (by name,
  "! case-insensitive), for an object page a key. Change name to the field
  "! it fills (a semantic object's parameter that is called differently),
  "! value to translate it, clear name to ignore it - a parameter that
  "! names no field is ignored anyway (added 2026-10, third round)
  METHODS map_inbound_parameter DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      name        TYPE string
      value       TYPE string.

  "! the sections the extension adds to the object page of entity_name,
  "! each placed BEFORE or AFTER (the default) the @UI.facet whose id is
  "! its anchor - no anchor, or one the page does not show, is the end.
  "! Its content comes from extend_view at cs_spot-custom_section with the
  "! section's id as section_id (added 2026-10, third round)
  METHODS get_custom_sections DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      sections    TYPE z2ui5_cl_rap_util=>ty_t_custom_section.

  "! the fields of entity_name whose change updates the draft at once
  "! (side effects; the BDEF source is not read): its determinations run
  "! and the page shows what they changed - * is every field. fields
  "! comes filled with the default: * for a business object with draft,
  "! nothing without one - a change of a business object without draft
  "! reaches it on Save only, so the list does nothing there (added
  "! 2026-10, third round)
  METHODS get_side_effect_fields DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      fields      TYPE string_table.

  "! a section of the change documents of a record of entity_name: entity
  "! is the CDS entity of its change documents (none: no section), filter
  "! its fields with the field of the record whose value they must have
  "! (name the change document entity's field, value the record's field;
  "! empty: the record's keys under their own names) - the section shows
  "! the entity's @UI.lineItem, read-only (added 2026-10, third round)
  METHODS get_change_documents DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      entity      TYPE string
      filter      TYPE z2ui5_cl_rap_util=>ty_t_name_value.

  "! The WHERE condition (ABAP SQL) of a free-text search instead of the
  "! LIKE over the searched text fields - empty keeps the LIKE (added
  "! 2026-10, third round). The fuzzy search of HANA
  "! (@Search.fuzzinessThreshold, threshold its highest value) is no ABAP
  "! SQL: run z2ui5_cl_rap_util=>build_fuzzy_search through ADBC or an
  "! AMDP and answer the keys it found, e.g. ( ID IN ( '1', '2' ) )
  METHODS build_search_condition DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
      fields      TYPE z2ui5_cl_rap_util=>ty_t_field_info
      search      TYPE string
      threshold   TYPE string
    CHANGING
      condition   TYPE string.

  "! The hierarchy of a tree (z2ui5_cl_rap_tree): the node and parent
  "! fields, the order of the siblings and what a delete does to the
  "! children (delete_mode, z2ui5_cl_rap_util=>cs_tree_delete) - added
  "! 2026-10, third round
  METHODS adjust_hierarchy DEFAULT IGNORE
    IMPORTING
      floorplan   TYPE string
      entity_name TYPE string
    CHANGING
      hierarchy   TYPE z2ui5_cl_rap_util=>ty_s_hierarchy.

ENDINTERFACE.
