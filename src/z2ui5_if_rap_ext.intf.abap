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
  METHODS extend_view DEFAULT IGNORE
    IMPORTING
      floorplan TYPE string
      spot      TYPE string
      container TYPE REF TO z2ui5_cl_ui5_view_builder
      client    TYPE REF TO z2ui5_if_client.

  "! the CDS entity an association of entity_name leads to - needed for a
  "! #LINEITEM_REFERENCE facet, whose target the annotations do not name
  METHODS resolve_association DEFAULT IGNORE
    IMPORTING
      entity_name TYPE string
      association TYPE string
    CHANGING
      target      TYPE string.

ENDINTERFACE.
