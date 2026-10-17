# rap-ext

[![abap2UI5-addons](https://img.shields.io/badge/abap2UI5--addons-library-1873b4)](https://github.com/abap2UI5-addons)
[![ABAP](https://img.shields.io/badge/ABAP-Standard%20%E2%89%A5%207.58-blue)](#installation)
[![abap2UI5](https://img.shields.io/badge/requires-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![License](https://img.shields.io/github/license/abap2UI5-addons/rap-ext)](LICENSE)
<br>
[![ABAP Standard](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/rap-ext/abap-standard.yaml?branch=main&label=ABAP%20Standard)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/abap-standard.yaml)
[![ABAP Unit](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/rap-ext/unit.yaml?branch=main&label=ABAP%20Unit)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/unit.yaml)
[![check-abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fbadges%2Fcheck-abap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check-abap2ui5.yaml)
[![abap2UI5](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabap2UI5-addons%2Frap-ext%2Fbadges%2Fabap2ui5.json)](https://github.com/abap2UI5-addons/rap-ext/actions/workflows/check-abap2ui5.yaml)

**Fiori-Elements-style apps for your CDS views, generated at runtime and
rendered with abap2UI5.** rap-ext reads a CDS entity and its UI annotations
(metadata extensions included) and builds a list report, worklist, object
page, overview page, value help or action dialog from them - writing through
RAP where the entity is a business object. It is for ABAP developers on a
standard ABAP system who want such a UI with one line of code and can still
redefine any step of it with plain abap2UI5 view code.

> Part of [abap2UI5-addons](https://github.com/abap2UI5-addons) - addons and apps for [abap2UI5](https://github.com/abap2UI5/abap2UI5), installed with [abapGit](https://abapgit.org).

## Why

A CDS view with `@UI` annotations already says what its list, its filter bar
and its object page look like. rap-ext turns those annotations into abap2UI5
apps at runtime: create a floorplan with the name of the entity, call it with
`nav_app_call`, and the screen is there. Every floorplan is a normal class -
not FINAL, every rendering and event step a protected method - so where the
generated screen is not enough, a subclass replaces that one step with its
own view code ([The Escape Hatch](#the-escape-hatch)).

Good for:

- **CDS views and RAP business objects** that need a list, a detail page or
  a dashboard inside an abap2UI5 app.
- **Value helps and parameter dialogs** in your own abap2UI5 apps, driven by a
  CDS view or an abstract CDS entity.

What it is not:

- **Not for ABAP Cloud.** The annotations are read through on-premise DDIC
  APIs (`CL_DD_DDL_ANNOTATION_SERVICE`) that are not released for ABAP Cloud.
- **Not for a plain internal table.** This addon renders from **CDS
  annotations**. For a list report over a plain internal table there is no
  counterpart in the abap2UI5 core today — an RTTI-based
  `z2ui5_cl_fp_list_report` existed there briefly and was removed again, so
  do not rely on it; build such a view with `z2ui5_cl_ui5_view_builder`
  directly.

## Installation

**Requirements**

- Standard ABAP 7.58 or higher - the release the code is checked against;
  not ABAP Cloud
- [abap2UI5](https://github.com/abap2UI5/abap2UI5) - the checks run against
  the release pinned in `abaplint.jsonc`
- UI5 1.77 or higher in the browser (the object page uses
  `sap.uxap.ObjectPageSubSection.showTitle`)
- for the RAP parts of the demo: the `/DMO/` flight reference scenario

**Steps** - with [abapGit](https://abapgit.org), in this order:

1. [abap2UI5](https://github.com/abap2UI5/abap2UI5)
2. this repository (branch `main`)

**Start** - run the demo app like any abap2UI5 app,
`?app_start=z2ui5_cl_rap_test`; it shows every floorplan. Its deep links
come from `z2ui5_cl_rap_test_start` (see [Deep links](#deep-links)).

> [!NOTE]
> Everything passes the offline checks, but none of it has been clicked
> through in an SAP system yet - the RAP write path and the reading of
> metadata extensions were written without one. The checklist for that is
> [docs/system-test.md](docs/system-test.md); see also [ROADMAP.md](ROADMAP.md).

## Usage

| Floorplan | Class |
| --- | --- |
| List Report | `z2ui5_cl_rap_list_report` |
| Worklist | `z2ui5_cl_rap_worklist` |
| Tree (a list report of a hierarchy) | `z2ui5_cl_rap_tree` |
| Flexible Column Layout (list and object pages side by side) | `z2ui5_cl_rap_fcl` |
| Object Page | `z2ui5_cl_rap_object_page` |
| Overview Page | `z2ui5_cl_rap_overview_page` |
| Value Help | `z2ui5_cl_rap_value_help` |
| Action Dialog (popup) | `z2ui5_cl_rap_action_dialog` |

All of them inherit from `z2ui5_cl_rap_floorplan`, which holds what they share
(reading, the filter syntax, the control for a field, value helps, writing,
texts, extension points). `z2ui5_cl_rap_util` reads the metadata,
`z2ui5_cl_rap_eml` writes through RAP.

The shortest call - a list report for a CDS view:

```abap
client->nav_app_call( NEW z2ui5_cl_rap_list_report(
  cds_view_name = `I_COUNTRY`
  title         = `Countries` ) ).
```

## The Escape Hatch

Every floorplan in this addon is deliberately **not FINAL**: all rendering
and event steps are `PROTECTED` methods a subclass can redefine with
ordinary abap2UI5 view code, and events the floorplan does not know are
routed to the `on_event` hook. Breaking out of a floorplan is not a
breakout — it is just another view method.

> **Builder change (breaking for subclasses).** The floorplans build their
> views with the core's generic builder
> **`z2ui5_cl_ui5_view_builder`** (`src/02`, the released API) instead of the
> frozen `z2ui5_cl_xml_view`. Every render hook that takes a builder handle
> (`io_page`, `io_table`, `io_columns`, `io_cells`, `io_op`, `io_actions`,
> `io_parent`, `io_container`) types it
> `TYPE REF TO z2ui5_cl_ui5_view_builder`, and a redefining subclass has to
> be updated to the verbs `ele` / `tag` / `a` / `end` shown below. Parameter
> names and the set of hooks are unchanged. In return the views are now
> checkable without an SAP system — see [Development](#development).
>
> An earlier version of this note named the builder `z2ui5_cl_ai_xml` and the
> verbs `open` / `leaf` / `shut`. No such class ever shipped in the core, so
> the repository did not compile against it; the names here are the ones
> `abap2UI5/abap2UI5` actually releases.

```abap
CLASS zcl_my_report DEFINITION PUBLIC
  INHERITING FROM z2ui5_cl_rap_list_report CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor.
  PROTECTED SECTION.
    METHODS render_toolbar REDEFINITION.
    METHODS on_event REDEFINITION.
ENDCLASS.

CLASS zcl_my_report IMPLEMENTATION.

  METHOD constructor.
    super->constructor( cds_view_name = `I_COUNTRY` ).
  ENDMETHOD.

  METHOD render_toolbar.
    "replace the generated toolbar with your own - plain abap2UI5 view code
    DATA(lo_toolbar) = io_table->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).

    lo_toolbar->tag( `Title`
        )->a( n = `text`
              v = mv_title && ` (` && client->_bind( mv_count ) && `)` ).

    lo_toolbar->tag( `ToolbarSpacer` ).

    lo_toolbar->tag( `Button`
        )->a( n = `text`  v = `Approve`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `APPROVE` ) ).

    lo_toolbar->tag( `Button`
        )->a( n = `icon`  v = `sap-icon://refresh`
        )->a( n = `press` v = client->_event( cs_event-refresh ) ).
  ENDMETHOD.

  METHOD on_event.
    "custom events land here - exactly like a hand-written app
    IF client->check_on_event( `APPROVE` ).
      client->message_toast_display( `Approved` ).
      RETURN.
    ENDIF.
    super->on_event( client ).
  ENDMETHOD.

ENDCLASS.
```

Overridable steps per floorplan:
- **List Report**: `render_page`, `render_filter_bar`, `render_table`, `render_toolbar`, `render_column`, `render_cell`, `on_row_press`, `on_create`, `on_action`, `execute_action`, `render_action_buttons`, `open_created`, `on_navigated`, `load_data`, `get_where_clause`, `get_line_item_fields`, `get_selection_fields`, `get_row_key_fields`, `get_line_item_actions`, `get_line_item_intents`, `get_visible_columns`, `get_missing_filters`, `on_nav_path`, `on_intent`, `on_export`, `render_export_button`, `init_variants`, `get_action_rows`, `apply_filter_presets`, `render_variant_controls`, `render_variant_popup`, `render_column_popup`, `on_variant_event`, `capture_variant`, `apply_variant`, `apply_row_states`, `fill_draft_status`, `update_action_state`, `get_action_enabled`, `has_row_column`, `create_filter`, `update_filter_tokens`, `take_filter_inputs`, `apply_presentation_variants`, `on_filter_event`, `render_condition_popup`, `render_adapt_popup`, `get_adaptable_fields`, `clear_rows`, `is_initial_load`, `apply_text_columns`, `get_text_column`, `has_selection`, `get_condition_operators`, `get_ordered_columns`, `get_variant_key`, `render_toolbar_content`, `render_grid_table`, `render_grid_column`, `apply_analytics`, `read_aggregates`, `add_row_columns`, `get_selected_rows`, `on_event`
- **Worklist**: everything of the list report (it is a subclass of it), plus `load_segments`
- **Tree**: everything of the list report (it is a subclass of it), plus `get_hierarchy`, `get_delete_mode`, `build_tree_rows`, `refresh_tree_state`, `get_node_key`, `get_node_row`, `get_selected_node`, `on_create_child`, `render_delete_popup`, `delete_node`
- **Flexible Column Layout** (`z2ui5_cl_rap_fcl`): `dispatch`, `open_column`, `close_column`, `render`, `render_skeleton`, `update_layout`, `get_column_app`
- **Object Page**: `render_page`, `render_header_title`, `render_actions`, `render_header_content`, `render_sections`, `render_section_content`, `render_section_form`, `render_section_fields`, `render_section_table`, `get_sections`, `save_data`, `delete_data`, `reload_data`, `load_child_rows`, `get_association_target`, `get_child_filter`, `get_child_context`, `on_child_create`, `get_bdef`, `get_root_keys`, `get_own_keys`, `start_draft`, `save_draft`, `find_created_record`, `get_link`, `on_action`, `execute_action`, `get_record_actions`, `get_identification_fields`, `render_section_actions`, `render_action_buttons`, `on_child_action`, `execute_child_action`, `open_created`, `on_child_row`, `format_value`, `load_permissions`, `get_field_for_edit`, `read_own_draft`, `read_draft_status`, `resume_draft`, `render_draft_info`, `get_disabled_actions`, `apply_start_mode`, `get_custom_sections`, `render_section`, `render_custom_section`, `get_side_effect_fields`, `on_side_effect`, `get_admin_fields`, `render_admin_fields`, `get_change_documents`, `get_path_children`, `render_path_input`, `add_path_token`, `delete_path_token`, `get_path_as_child`, `get_token_key`, `get_token_keys`, `read_child_rows`, `add_row_flags`, `render_child_cell`, `on_child_row_add`, `on_child_row_delete`, `get_child_original`, `write_children`, `on_event`
- **Overview Page**: `render_page`, `render_table_card`, `render_kpi_card`, `render_chart_card`, `render_card_link`, `load_all_cards`, `load_kpi_value`, `load_chart_rows`, `collect_card_rows`, `display`, `on_card`, `on_card_row`, `on_event`
- **Value Help**: `render_dialog`, `render_filter_dialog`, `load_data`, `get_where_clause`, `on_confirm`, `on_event`
- **Action Dialog**: `render_action_dialog`, `get_control_for_field`, `render_value_help`, `handle_value_help_confirm`, `apply_default_values`, `get_mandatory_parameters`, `apply_mandatory_parameters`, `get_missing_fields`, `on_event`
- **Every floorplan** (`z2ui5_cl_rap_floorplan`): `select_rows`, `count_rows`, `get_read_info`, `query_rows`, `calculate_virtual_elements`, `adjust_virtual_order_by`, `aggregate_rows`, `get_load_error`, `build_filter_condition`, `build_search_condition`, `build_key_condition`, `create_host`, `render_field_input`, `prepare_value_lists`, `load_suggestions`, `open_value_help`, `apply_value_help`, `get_entity_capabilities`, `write_row`, `write_table_row`, `is_draft_enabled`, `write_draft`, `run_draft_action`, `run_action`, `is_static_action`, `get_action_entries`, `get_action_button_type`, `is_hidden_by_annotation`, `navigate_to_intent`, `read_association_target`, `get_permissions`, `get_row_permissions`, `get_keys_of_row`, `read_drafts`, `read_draft_children`, `get_etag_field`, `check_etag`, `show_messages`, `render_message_view`, `render_file_field`, `render_upload_popup`, `apply_upload`, `download_file`, `get_max_file_size`, `get_default_function_name`, `apply_action_defaults`, `read_association_texts`, `get_association_text_key`, `get_text`, ...
- **Deep links** (`z2ui5_cl_rap_start`): `get_allowed_entities`, `get_extension`, `get_parameters`, `map_parameters`, `open`, `render_message`

## Extension points without a subclass

`z2ui5_if_rap_ext` changes a floorplan's data, metadata, texts and events;
hand an implementation to any floorplan with `set_extension( )`. Every method
is `DEFAULT IGNORE` - implement only what you need. The floorplans pass the
extension on to the apps they call (object page, value help, action dialog).

```abap
CLASS zcl_my_ext DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_rap_ext.
ENDCLASS.

CLASS zcl_my_ext IMPLEMENTATION.

  METHOD z2ui5_if_rap_ext~adjust_entity.
    "hide a field, rename another - without touching the CDS view
    entity-fields[ name = `CREATEDBY` ]-is_hidden = abap_true.
    entity-fields[ name = `COUNTRY` ]-label = `Land`.
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~adjust_where.
    "only the user's own travels - every read passes here, the value
    "helps' included, so look at the entity first
    IF entity_name <> `/DMO/C_TRAVEL_PROCESSOR_M`.
      RETURN.
    ENDIF.
    where = COND #( WHEN where IS INITIAL THEN |CREATEDBY = '{ sy-uname }'|
                    ELSE |{ where } AND CREATEDBY = '{ sy-uname }'| ).
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~get_text.
    IF key = z2ui5_cl_rap_floorplan=>cs_text-create.
      text = `Anlegen`.
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_if_rap_ext~resolve_association.
    "the target of a #LINEITEM_REFERENCE facet
    IF association = `_BOOKING`.
      target = `/DMO/C_BOOKING_PROCESSOR_M`.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

```abap
DATA(lo_report) = NEW z2ui5_cl_rap_list_report( cds_view_name = `/DMO/C_TRAVEL_PROCESSOR_M` ).
lo_report->set_extension( NEW zcl_my_ext( ) ).
client->nav_app_call( lo_report ).
```

| Method | When |
| --- | --- |
| `adjust_entity` | after the metadata is read - labels, hidden fields, positions, field groups, value helps, actions |
| `adjust_where` | before every read - the dynamic WHERE clause |
| `after_load` | after every read - the rows |
| `before_save` / `after_save` | around create, update, delete and actions - `cancel` stops one |
| `on_event` | every event, before the floorplan - return `abap_true` to take it over |
| `get_text` | every text (keys in `z2ui5_cl_rap_floorplan=>cs_text`) - translation |
| `resolve_association` | the target entity of a `#LINEITEM_REFERENCE` facet - decided before the DDL source is asked |
| `adjust_capabilities` | what may be written: switch on the writes of a database table, withhold an operation of a business object |
| `get_start_app` | the `z2ui5_cl_rap_start` subclass whose links the object page copies (see "Deep links") |
| `map_inbound_parameter` | a parameter of a link or a launchpad tile before `z2ui5_cl_rap_start` uses it - rename it to the field it fills, change its value, clear its name to ignore it |
| `extend_view` | add controls at fixed places (`z2ui5_cl_rap_floorplan=>cs_spot`): the table toolbar, the object page's header actions, header content (`HEADER_CONTENT`, behind the header facets) and sections, the content of a custom section (`CUSTOM_SECTION`, its id in `section_id`), the dialog's content, the overview's cards - their events arrive in `on_event` first |
| `get_custom_sections` | sections of the object page with their place: `id`, `title`, `anchor` (the id of a `@UI.facet`) and `placement` `BEFORE` or `AFTER` (default); no anchor, or one the page does not show, is the end - the content comes from `extend_view` |
| `get_side_effect_fields` | the fields whose change updates the draft at once (`*` every field) - default `*` with draft, none without (see "Object page: children, side effects, sections") |
| `get_change_documents` | the CDS entity of the record's change documents and its filter (its field = the record's field; empty: the keys) - a read-only section "Changes" |
| `build_search_condition` | the WHERE of a free-text search instead of the `LIKE` - e.g. the keys a HANA fuzzy search found (see "CDS List Report") |
| `adjust_hierarchy` | the hierarchy of a tree: node and parent field, the order of the siblings, the delete mode (see "CDS Tree") |

The built-in texts are German for a German logon (`sy-langu` `D`) and
otherwise the text pool of `z2ui5_cl_rap_floorplan` (English, translatable in
SE63); `get_text` changes any of them.

The extension travels with the app through the abap2UI5 draft: the interface
includes `if_serializable_object`, so keep its attributes serializable.

## Metadata

`z2ui5_cl_rap_util=>read_entity( )` reads the fields (RTTI), the keys and the
data element texts (DDIC), the associations and every annotation - through
`CL_DD_DDL_ANNOTATION_SERVICE=>GET_ANNOS`, so **metadata extensions** are
included (RAP objects keep their `@UI` annotations there). Annotation arrays
and qualifiers are read per entry:

| Annotation | Used for |
| --- | --- |
| `@UI.headerInfo` | titles, object page header; `imageUrl` (a field) is the header's avatar, `typeImageUrl` (a URL or `sap-icon://`) stands in when the record has no image |
| `@UI.lineItem` | columns (position, label, importance - a semantic key without one is HIGH -, criticality with its icon unless `criticalityRepresentation: #WITHOUT_ICON`, `cssDefault.width`, `iconUrl`, `hidden: true` or `#(Field)` per row); `#AS_FIELDGROUP` with `valueQualifier` a cell with the fields of that field group one under the other; a qualified `@UI.lineItem` is the table of a presentation variant whose `visualizations` names it; the entity's own `@UI.lineItem` `criticality` highlights the rows; `type: #FOR_ACTION` entries are actions (`inline: true` per row) - by `position`, `criticality` the button's type (positive Accept, negative Reject, critical Emphasized; a field's value on the object page), `actionGroupId` puts one into the menu button of a `#FOR_ACTION_GROUP` entry (`id`, `label`), `invocationGrouping: #ISOLATED` runs it row by row; `#WITH_URL` a link to the URL in another field, `#WITH_NAVIGATION_PATH` the object page of the record the association (`targetElement`) leads to, `#WITH_INTENT_BASED_NAVIGATION` and `#FOR_INTENT_BASED_NAVIGATION` a navigation in the Fiori launchpad (`semanticObject`, `semanticObjectAction`, `semanticObjectBinding` - the parameters the row's, the selected rows' or the record's fields fill; a toolbar navigation with bindings makes the rows selectable) |
| `@UI.selectionField` | filter bar - each filter with the control of its type (see "Filter syntax") |
| `@UI.identification` | object page header attributes (the unqualified entries; `criticality` an ObjectStatus with its icon, `importance` LOW left out on phones and tablets, MEDIUM on phones, `hidden` true or a field of the record); a `qualifier` puts the field (with its `label`) into the `#IDENTIFICATION_REFERENCE` facet of that `targetQualifier` only; `#FOR_ACTION` entries are header actions, qualified ones the actions of that section (groups, criticality and position as in `@UI.lineItem`) |
| `value: '_Assoc.Element'` (in `@UI.identification`, `@UI.fieldGroup`) | a 1:n child as a MultiInput: a token per child of the association with its element's value - in edit mode a token creates a child by association, a deleted token deletes it; the value help is the element's (see "Object page: children, side effects, sections"). On any element, the association itself included; such an entry is no entry of the element that carries it. A `@UI.lineItem` entry of that kind is read (`path_fields`) but no column yet |
| `@UI.fieldGroup` | object page forms - a field can sit in several groups, with the entry's `label`, `criticality`, `criticalityRepresentation`, `importance` and `hidden` (as in `@UI.identification`); a `#FOR_ACTION` entry is an action of the group's section |
| `@UI.createHidden`, `.updateHidden`, `.deleteHidden` | no Create (list report, child tables), Edit or Delete (object page): `true`, or a field of the record (`#(IsLocked)`) whose value decides on the object page |
| `@UI.facet` | object page sections: `#COLLECTION`, `#FIELDGROUP_REFERENCE`, `#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE` - on the entity or on an element; with `purpose: #HEADER` (`#DATAPOINT_REFERENCE`, `#FIELDGROUP_REFERENCE`) the object page header |
| `@UI.dataPoint` | status with criticality, KPI cards; `criticalityCalculation` (`#MAXIMIZE`, `#MINIMIZE`, `#TARGET` with tolerance/deviation values) colors a KPI card |
| `@UI.presentationVariant` | the default sort order (`sortOrder`) and grouping (`groupBy`) of list report and worklist, the qualified `@UI.lineItem` of its `visualizations`; an overview card's content (`visualizations` - a chart or a qualified line item -, `sortOrder`, `maxItems`) |
| `@UI.selectionPresentationVariant` | which presentation variant (`presentationVariantQualifier`) and selection variant (`selectionVariantQualifier`) a list report starts with - the unqualified one, else the first |
| `@UI.selectionVariant` | the filter values a list report starts with (the unqualified one, or the one its selection presentation variant names: `selectOptions` and the comparisons of an AND in `filter`; an OR is applied as it is); worklist tabs - one per variant, its `filter` string and `selectOptions` (`propertyName`, `ranges` with `sign`, `option`, `low`, `high`), the `filter` string (`Status EQ O AND Priority GE 3`, `(Status EQ O OR Status EQ A) AND Priority GE 3`; EQ NE GT GE LT LE, AND before OR, parentheses) |
| `@UI.textArrangement` | how value and text are shown: `#TEXT_FIRST` (default), `#TEXT_LAST`, `#TEXT_ONLY`, `#TEXT_SEPARATE` |
| `@UI.chart` | chart cards (first dimension, first measure); `chartType` `#BAR`/`#COLUMN` bars, `#DONUT`/`#PIE` shares, `#LINE`/`#AREA` a trend |
| `@UI.hidden`, `@UI.multiLineText`, `@UI.defaultValue` | visibility, text areas, dialog defaults |
| `@ObjectModel.text.element` | "Text (Value)" cells, value help descriptions, the text beside an input in edit mode (`description`) |
| `@ObjectModel.text.association` | the text of a field from its association's target - the target's `@Semantics.text` field, in the logon language by its `@Semantics.language` field (list report cells, object page) |
| `@ObjectModel.semanticKey` | the key when the DDIC has none; its fields bold (`ObjectIdentifier`) and of HIGH importance in the list |
| `@Semantics.imageUrl` | the value is an image: an `Avatar` in a cell and on the object page |
| `@Consumption.hidden` | the field is offered nowhere - no column, no filter, not in "adapt filters" |
| `@Consumption.semanticObject`, `.semanticObjectMapping.additionalBinding` | the value is a link that navigates to the semantic object (`display`), with the value (under the mapped name) and the row's keys - in the list and on the object page |
| `@ObjectModel.mandatory` / `.readOnly` | required fields (checked before save/confirm), read-only inputs |
| `@ObjectModel.resultSet.sizeCategory: #XS` | a dropdown instead of a value help - its entries with the value help's text element and the key beside it; in the filter bar a list |
| domain fixed values | a field without an annotated value help whose domain has fixed values gets a dropdown of them (edit mode, action dialog) and a list in the filter bar (`CL_ABAP_ELEMDESCR->GET_DDIC_FIXED_VALUES`, called dynamically) |
| `@Consumption.valueHelpDefinition` | value helps, with `additionalBinding` (usage `#FILTER` and `#RESULT`) |
| `@Consumption.filter` | filter bar: `defaultValue`, `mandatory` (no rows until it has a value), `selectionType: #SINGLE` / `multipleSelections: false` (the value help selects one), `hidden` |
| `@Search.searchable`, `@Search.defaultSearchElement` | the search field and what it searches: the `defaultSearchElement` fields (also when `@UI.hidden`), else every visible text and string field; a case-insensitive `LIKE` |
| `@Search.fuzzinessThreshold` | read (`search_fuzziness`); the threshold `z2ui5_if_rap_ext~build_search_condition` is handed - a fuzzy search is HANA SQL (`CONTAINS ... FUZZY`, `z2ui5_cl_rap_util=>build_fuzzy_search`), which ABAP SQL has not: without the hook the search stays a `LIKE` |
| `@Aggregation.default` | `#SUM`, `#MIN`, `#MAX`, `#AVG`, `#COUNT_DISTINCT`: the subtotals and the total of an analytical list report (`analytical = abap_true`) |
| `@Hierarchy.parentChild` (`recurse.parent` / `.child`, `recurseBy`, `siblingsOrder`), `@ObjectModel.hierarchy.association`, `@OData.hierarchy.recursiveHierarchy` | the hierarchy of a tree (`z2ui5_cl_rap_tree`): the parent and node fields, or the association to the parent (its ON condition), or the CDS hierarchy (`define hierarchy ... as parent child hierarchy( source ... child to parent association ... siblings order by ... )`, read from its DDL source); without any of them a to-one association of the entity to itself whose target fields are keys |
| `@ObjectModel.query.implementedBy` | a custom entity - read through its query provider (see "Reading") |
| `@ObjectModel.virtualElementCalculatedBy` | a virtual element - calculated after each read; not a filter field, not searched, sortable only with `@ObjectModel.sort.transformedBy` (see "Reading") |
| `@Semantics.amount.currencyCode`, `.quantity.unitOfMeasure`, `.booleanIndicator` | numbers with units, Yes/No |
| `@Semantics.user.createdBy`, `.systemDateTime.createdAt` | a record created with late numbering is found again by them; with `.user.lastChangedBy` and `.systemDateTime.lastChangedAt` the object page's section "Change Information" (also when `@UI.hidden`; not when one of them is in a field group or the identification) |
| `@Semantics.systemDateTime.localInstanceLastChangedAt`, `.lastChangedAt` | the field of the optimistic check before an update without a draft (the first one, else the second) |
| `@Semantics.user.lastChangedBy` | of a draft: whose draft it is - another user's locks the record |
| `@Semantics.largeObject` (`mimeType`, `fileName`, `acceptableMimeTypes`, `contentDispositionPreference`), `@Semantics.mimeType` | a file field (a `RAWSTRING`): a link that downloads it, in edit mode and in the action dialog an Upload button; the MIME type and file name go into their fields; the size (`get_max_file_size`, 5 MB) and the type are checked on the server (see "Files") |
| BDEF `default function GetDefaultsFor<Action>` | the default values of the action's parameter dialog (see "Writing") |
| BDEF feature control (via `GET PERMISSIONS`) | `features`, `authorization`, `field ( readonly )`, `readonly : update`, `mandatory`, `mandatory : create`, internal operations - what is offered, enabled and accepted |
| `@EndUserText.label` / `.quickInfo` | labels; the quick info is the tooltip of the label in the object page's forms and the action dialog and of the column headers |

The **associations** come from the entity's DDL source (`DDDDLSRC`, read by
name): `association [..] to X as _A on ...`, `association to parent`,
`composition [..] of X as _A`, the 7.58 forms (`of many to one`) and in a
projection `_A : redirected to [composition child | parent] X`. A projection
takes what it does not redirect from its base, and a composition takes its
ON condition from the child's association to parent. The object page reads
the rows of a `#LINEITEM_REFERENCE` table by that ON condition (else by the
keys under the same names), and `resolve_association` still decides first.

## Reading - views, custom entities, virtual elements

Every floorplan reads through `select_rows` and `count_rows`
(`z2ui5_cl_rap_floorplan`), and so does every value help, child table and
overview card. How an entity is read is decided by `get_read_info`:

- **A CDS view or a table** is read with ABAP SQL, as before.
- **A custom entity** (`@ObjectModel.query.implementedBy: 'ABAP:ZCL_...'`)
  is read through its query provider: `z2ui5_cl_rap_query` calls
  `IF_RAP_QUERY_PROVIDER~SELECT` with its own request and response. The
  provider is given the filter as ABAP SQL (`get_as_sql_string`, the key
  values of an object page as literals) and as ranges (`get_as_ranges` -
  it raises `CX_RAP_QUERY_FILTER_NO_RANGE` when the filter is no AND of one
  range per field, e.g. an OR over two fields), the search apart from the
  filter (`get_search_expression`), the sort order, the page (offset 0,
  `max_rows`), every element as requested, and whether rows
  (`is_data_requested`) or the count (`is_total_numb_of_rec_requested`) are
  wanted - a list asks twice, once for each. No aggregation is requested and
  no entity parameter is supplied; `get_as_tree` answers no tree. The
  worklist's tabs and the overview's KPI and chart cards aggregate the rows
  in ABAP (`aggregate_rows`, at most 5000 rows). A provider that raises is
  shown as an error (`get_load_error`: the load error, the entity and the
  exception's text) - never as an empty list.
- **A virtual element** (`@ObjectModel.virtualElementCalculatedBy`) has no
  column: the other columns are selected, a condition on it is left out of
  the WHERE (`remove_where_fields`) and it is not offered as a filter or
  searched. After the read its class is called -
  `IF_SADL_EXIT_CALC_ELEMENT_READ~GET_CALCULATION_INFO` and `~CALCULATE`,
  dynamically, once per class for the rows read. It is sortable only with
  `@ObjectModel.sort.transformedBy`: the sort is then by the elements
  `IF_SADL_EXIT_SORT_TRANSFORM~MAP_ELEMENT` names (`adjust_virtual_order_by`).
  `@ObjectModel.filter.transformedBy` is read but not called - its
  transformation builds conditions with SADL objects no release offers here,
  so a virtual element stays no filter field.

A subclass can change all of it: `get_read_info` names a provider or a
calculation the annotations do not show, `query_rows` builds the request,
`calculate_virtual_elements` and `adjust_virtual_order_by` call the exits.

## Writing - RAP, tables, read-only

What an entity lets the user do is asked from its BDEF
(`z2ui5_cl_rap_floorplan=>get_capabilities`): a business object whose root is
the entity is written through **dynamic EML** (`MODIFY ENTITIES OPERATIONS`,
`COMMIT ENTITIES`), and only the operations its BDEF defines are offered
(Create, Edit, Delete, and the `#FOR_ACTION` actions - with a parameter
dialog when the action has a parameter). The messages of `REPORTED` and
`FAILED` are shown. A **static action** (its derived type
`\ACTION=...\TYPE=IMPORTING` carries no `%KEY`) runs without selected
rows, with a `%cid`; a **factory action** - static or not - opens the
object page of the record it created, by the keys `MAPPED` returns. An
action with `invocationGrouping: #ISOLATED` runs row by row, each in a
request of its own, so a row that fails does not stop the others. The
toolbar actions of a child's `@UI.lineItem` run on the selected rows of its
table on the object page, and after any action the page reads the record
and its tables again. A CDS view that is no business object is read-only: no
Create, Edit or Delete.

A **transparent table is read-only too, unless an extension allows its
writes** - up to 2026-10 every table a floorplan was opened on could be
changed and deleted by anyone who reached the app:

```abap
METHOD z2ui5_if_rap_ext~adjust_capabilities.
  IF entity_name = `ZMY_TABLE`.
    caps-can_create = abap_true.
    caps-can_update = abap_true.
    caps-can_delete = abap_true.
  ENDIF.
ENDMETHOD.
```

A table write then checks the authorization `S_TABU_NAM` (activity `02`)
for the table, locks the row (`ENQUEUE_E_TABLE`), and refuses an update or
delete when the row in the database is no longer the one the user saw. It is
committed right after the write (`COMMIT WORK`) - the abap2UI5 core rolls
back the LUW of every non-sticky app after `main( )`. `adjust_capabilities`
can also withhold an operation of a business object; it cannot add one its
BDEF lacks. Every write and action is checked against these capabilities on
the server, not only by hiding the buttons, and only the actions the
annotations offer can be run.
After a RAP create the page reads the record again by the keys `MAPPED`
returns; a business object that assigns its key only on save (late
numbering) hands none back, and the page then returns to the list.

A **draft-enabled** business object (its BDEF has the draft action Edit) is
written the way its own UI does: a change is Edit (a draft of the active
instance), the change of the draft, Activate; a create is a draft that is
activated. All of it runs before the one `COMMIT ENTITIES`, and a failed step
rolls the request back - no draft is left behind.

A **child entity** is written through the BDEF of its root: the object page
of a child carries its place in the business object
(`z2ui5_cl_rap_floorplan=>ty_s_rap_context` - the BDEF, the root's keys, the
parent), and a table of a composition offers Create - a create by
association (`%target`) under the record. A change of a child of a draft
business object edits and activates the root.

On the object page, a **draft business object is edited in a draft that spans
roundtrips**: Edit creates it (committed), Save writes the changes into it
and activates it, and Cancel discards it. When the activation is refused the
draft keeps the changes and the page stays in edit mode. Leaving the page
while editing asks whether to **keep or discard the draft**. A record that has
a draft of the user's own is **read back** (`READ ENTITIES` with `%is_draft`)
and opens to be edited further; a draft left by another app makes Edit offer
"Resume draft" or "Discard draft"; another user's draft locks the record
("Locked by ..." above the header, no Edit or Delete). Whose draft it is, is
decided by the draft's `@Semantics.user.lastChangedBy` field (none: the
user's own). A record found only as a draft - what a factory action of a
draft business object creates - opens in edit mode.

**Feature control** (`GET PERMISSIONS`): the global, static and instance
permissions decide what is offered and what is accepted on the server -
Create, Edit, Delete, a create by association (`%assoc`), the actions
(their buttons shown disabled; in the list report per row for an inline
action and by the selected rows for a toolbar action), and the field control
in edit mode: `field ( readonly )`, `readonly : update`, `mandatory`,
`mandatory : create`, instance field control. A key is never typed in on
change; on create it is read-only when the field control says so (early or
managed numbering) or when it is a UUID (`RAW16`). An internal operation is
not offered where `GET PERMISSIONS` reports it as disabled. An update of a
read-only field, and an action a row does not allow, are refused.

**Optimistic check**: before an update or delete of a business object
without a draft, the record's etag field - the
`@Semantics.systemDateTime.localInstanceLastChangedAt` field, else the
`lastChangedAt` one - is compared with the stored record; a change in
between is refused. The BDEF's `etag master` is not read (its source has no
readable table here) - redefine `get_etag_field` to name another field.

Keys are compared with **typed host variables**, not literals, so a RAW key
(a UUID) reads the record again. A record created with **late numbering**
(no key in `MAPPED`, only a `%pid`) gets its final key with `CONVERT KEY`
between `COMMIT ENTITIES BEGIN` and `END`; where that cannot run it is found
again by `@Semantics.user.createdBy` and `@Semantics.systemDateTime.createdAt`,
and without them the page returns to the list. The fields a RAP message
names (`%element`) are marked in edit mode.

`GET PERMISSIONS OPERATIONS`, `READ ENTITIES OPERATIONS` and `CONVERT KEY`
are in three small classes of their own (`z2ui5_cl_rap_eml_perm`, `_read`,
`_key`) that no offline gate reads, called dynamically: on a system where
one does not activate, only its feature is lost.

**Messages by severity** (since 2026-10, third round): what a write reports
is shown by its severity - only success and information messages as a
toast; one message of the floorplan itself (no field, no entity) as a
message box; everything else in a dialog with a `sap.m.MessageView` that
lists each message with its own type, the labels of the fields it names
(`%element`) as subtitle and, when there are several, grouped by entity. A
success message is left out when there is an error. The messages of
`REPORTED` without an entity (`%other`) are collected too. The fields a
message names keep their value state in edit mode. `show_messages`
decides it (`z2ui5_cl_rap_util=>prepare_messages`, `get_message_display`).

**Action dialogs**: the parameter dialog of an action is filled by its
**default function** (`default function GetDefaultsFor<Action>` in the BDEF):
before the dialog opens it is executed (`READ ENTITIES OPERATIONS`, through
`z2ui5_cl_rap_eml_read`) for the first selected row, the record of the object
page or - for a static action - without one, and its result fills the
parameter's empty fields; `@UI.defaultValue` fills what is still empty.
`get_default_function_name` names another function. A parameter is mandatory
by `@ObjectModel.mandatory`, the extension, or - where `GET PERMISSIONS`
answers for the abstract entity - by its BDEF's `field ( mandatory )`
(`get_mandatory_parameters`; whether RAP answers that for an abstract entity
is for the system test).

### Files

A field with `@Semantics.largeObject` (a `RAWSTRING`) is a file: the object
page shows a link that downloads it (named by its `fileName` field), and in
edit mode an Upload button opens a dialog with the core's upload control
(`z2ui5.cc.FileUploader`). The file is taken into the record - its MIME type
and file name into their fields - and written with the next Save (or into
the draft). The server checks it: its size (`get_max_file_size`, by default
`cv_file_max_size`, 5 MB) and its type (`acceptableMimeTypes`, `image/*`
included; a browser that names no type is judged by the file's extension);
the file dialog offers the known extensions of the accepted types. A file
parameter of an action is the same: a `@Semantics.largeObject` field of the
abstract entity. The list report does not send files to the browser - the
object page reads its record again with them. `contentDispositionPreference`
is read; the file is downloaded either way (a browser refuses to open a
data URI in a new tab).

```cds
@Semantics.largeObject: { mimeType: 'MimeType', fileName: 'FileName',
                          acceptableMimeTypes: [ 'image/png', 'application/pdf' ],
                          contentDispositionPreference: #ATTACHMENT }
Attachment : abap.rawstring(0);
@Semantics.mimeType: true
MimeType   : abap.char(128);
FileName   : abap.char(128);
```

## Filter syntax

Each filter of the filter bar has the control of its field's type
(`z2ui5_cl_rap_util=>get_filter_control`): a list for a boolean (Yes, No,
all), for fixed values and for a dropdown value help; a date picker for a
date of a single value, else a date range; a `MultiInput` with a token per
value for a field with a value help that takes several (the value help
adds tokens, a typed value becomes one on Enter or Go, a token's delete
removes it); an input with the syntax below for every other field. The
filter button next to an input or a MultiInput opens **Define
conditions**: rows of an operator (equal to, not equal to, between,
greater, greater or equal, less, less or equal, contains, starts with,
ends with, empty) with its values, each including or excluding - written
into the same syntax (`conditions_to_filter`, read back by
`filter_to_conditions`). A mandatory filter without a value is marked as
an error on Go. **Adapt filters** adds a filter for any visible field and
removes one again (a mandatory filter stays); the views keep the filter
fields.

The filter bar (and `build_filter_condition`) understands:

| Input | Meaning |
| --- | --- |
| `abc` | contains (text fields), equals (other types) |
| `a*c` | pattern |
| `=abc` | equals |
| `!abc` | not |
| `a..z` | between |
| `>x` `>=x` `<x` `<=x` | compare |
| `a;b` | several, ORed |
| `=` | empty |

An excluding part (`!...`) is ANDed with the others since 2026-10 (third
round): `=A;=B;!=C` is `( A OR B ) AND NOT C`. Dates can be typed as
`2024-01-15`, a range as `2024-01-01..2024-01-31`. A value help in the filter bar fills
exact values (`=US;=DE`).

## CDS Action Dialog (Popup)

Renders a popup dialog for an abstract CDS entity, driven by its annotations (labels, tooltips, default values, value helps, dropdowns, multiline texts, hidden and mandatory fields). The list report and the object page use it for the parameter of a RAP action.

### Popup Definition
```cds
@EndUserText.label: 'Entity for popup'
define abstract entity z2ui5_dd_rap_test_popup
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Country', element: 'Country' } }]
  @EndUserText.label: 'Country'
  SearchCountry : land1;
  @EndUserText.label: 'Valid To'
  @UI.defaultValue: '99991231'
  NewDate       : abap.dats;
  @EndUserText.label: 'Message Type'
  MessageType   : abap.int4;
  @EndUserText.label: 'Update data'
  FlagUpdate    : abap.char(1);
  @EndUserText.label: 'Show Messages'
  FlagMessage   : abap_boolean;
}
```

### abap2UI5 Popup Call
```abap
  METHOD z2ui5_if_app~main.

    IF client->check_on_init( ).

      DATA(lo_dialog) = NEW z2ui5_cl_rap_action_dialog(
        val   = VALUE z2ui5_dd_rap_test_popup( searchcountry = `US` )
        title = `Enter Parameters` ).
      client->nav_app_call( lo_dialog ).
      RETURN.

    ENDIF.

    lo_dialog = CAST #( client->get_app_prev( ) ).
    IF lo_dialog->was_confirmed( ).
      DATA(ls_cds_result) = CONV z2ui5_dd_rap_test_popup( lo_dialog->result( )->* ).
    ENDIF.

  ENDMETHOD.
```

## CDS Value Help

Renders a table select dialog for any CDS view. Visible columns come from the
entity metadata; `@ObjectModel.text.element` adds description columns. The
search field searches the database. `multi_select` lets the user pick several
rows, `filters` restricts the rows (name/value pairs). An entity with
`@UI.selectionField` fields gets a filter bar of its own (the list report's
filter syntax).

An input with a value help (object page, action dialog) **suggests values
while the user types**: the rows whose element starts with the text or whose
text fields contain it.

### abap2UI5 Value Help Call
```abap
  DATA(lo_vh) = NEW z2ui5_cl_rap_value_help(
    cds_view_name = `I_COUNTRY`
    element       = `Country`
    title         = `Select Country` ).
  client->nav_app_call( lo_vh ).
```

On return, read the selection:
```abap
  lo_vh = CAST #( client->get_app_prev( ) ).
  IF lo_vh->was_confirmed( ).
    DATA(lv_country) = lo_vh->result_value( ).     "the element of the first row
    DATA(lt_countries) = lo_vh->result_values( ).  "of every selected row
    DATA(lr_rows) = lo_vh->result_table( ).        "the selected rows
  ENDIF.
```

## CDS List Report

Renders a Fiori-Elements-style list report for any CDS view, driven entirely by its annotations:
- Columns from `@UI.lineItem` (position, label, importance-based responsive popin)
- Filter bar from `@UI.selectionField` - filter syntax above, value helps, defaults; a search field for `@Search.searchable` views
- Criticality columns from `@UI.lineItem.criticality` / `@UI.dataPoint.criticality`
- Amount/quantity columns from `@Semantics.amount.currencyCode` / `@Semantics.quantity.unitOfMeasure`, "Text (Value)" for `@ObjectModel.text.element`
- Title from `@UI.headerInfo.typeNamePlural`, the count of all matching rows
- Sorting in the database - a select of the columns and a direction button, the default from `@UI.presentationVariant`; "More" loads the next rows from the database
- Actions from `@UI.lineItem` `#FOR_ACTION` (toolbar on the selected rows, or inline per row); links and launchpad navigations from `#WITH_URL`, `#WITH_NAVIGATION_PATH`, `#WITH_INTENT_BASED_NAVIGATION` and `#FOR_INTENT_BASED_NAVIGATION`
- Mandatory and single-value filters from `@Consumption.filter`
- Views per user (filters, the filter fields, search, sort order, the columns - hidden, order, width -, the group field; one the default, each public or private and applied automatically or not), a columns dialog (visible, order, width, group by), and the export of every matching row as a CSV file
- Filters by type (lists, dates, date ranges, MultiInputs with tokens), "define conditions", "adapt filters", the error state of a missing mandatory filter
- Grouping (`@UI.presentationVariant.groupBy` or the user's group field): the rows ordered by it in the database, a group header per value
- The start from `@UI.selectionPresentationVariant` (sort, group, a qualified `@UI.lineItem`, the selection variant's filter values); `initial_load` (`AUTO` - unless the default view does not apply automatically -, `ENABLED`, `DISABLED`: the rows only on Go)
- Row highlight by the entity's `@UI.lineItem.criticality`, criticality icons, `#AS_FIELDGROUP` cells, images, icons, the semantic key bold, texts of a text association, links to semantic objects
- Create where the entity allows it; row navigation to a generated object page
- RAP feature control: an inline action enabled per row, a toolbar action by the selected rows; a draft business object shows the editing status of each row (own draft, locked by another user) and filters by it
- A **grid table** (`table_type = cs_table_type-grid`, a `sap.ui.table.Table` for long lists - a check box column for the selection, a navigation column, the inline actions as button columns, the toolbar in its extension; no annotation needed). The `sap.ui.table` library is declared only then
- An **analytical list** (`analytical = abap_true`): the fields with `@Aggregation.default` summed up (`SUM`, `MIN`, `MAX`, `AVG`, `COUNT_DISTINCT`) over every row that matches the filters - a group header row per value of the group field ("Status: Open" with the subtotals) and a total row at the end. Aggregated by `GROUP BY` in the database; a custom entity, a virtual element or an aggregate the database refuses is computed from the rows (at most 5000, `aggregate_rows`). Group and total rows do not navigate and are never selected. Works with both tables
- **Fuzzy search**: `z2ui5_if_rap_ext~build_search_condition` replaces the `LIKE` of the search with a condition of its own. HANA's fuzzy search (`@Search.fuzzinessThreshold`) is no ABAP SQL - run `z2ui5_cl_rap_util=>build_fuzzy_search` (`CONTAINS( ( "NAME", "CITY" ), 'text', FUZZY( 0.8 ) )`) through ADBC or an AMDP and answer the keys it found

### abap2UI5 List Report Call
```abap
client->nav_app_call( NEW z2ui5_cl_rap_list_report(
  cds_view_name = `I_COUNTRY`
  title         = `Countries`
  max_rows      = 500
  initial_load  = z2ui5_cl_rap_list_report=>cs_initial_load-disabled ) ).

"a grid table with subtotals per group and a total
client->nav_app_call( NEW z2ui5_cl_rap_list_report(
  cds_view_name = `ZC_SALES_ORDER`
  table_type    = z2ui5_cl_rap_list_report=>cs_table_type-grid
  analytical    = abap_true ) ).
```

```abap
"a fuzzy search through ADBC - the keys it found as the search's WHERE
METHOD z2ui5_if_rap_ext~build_search_condition.
  IF entity_name <> `ZC_CUSTOMER` OR threshold IS INITIAL.
    RETURN.
  ENDIF.
  DATA(lv_sql) = |SELECT "ID" FROM "ZCUSTOMER" WHERE |
              && z2ui5_cl_rap_util=>build_fuzzy_search( it_fields  = fields
                                                        search    = search
                                                        threshold = threshold ).
  "... run lv_sql with cl_sql_statement, then e.g.
  condition = |ID IN ( { lv_ids } )|.
ENDMETHOD.
```

A view can be **public** (every user sees it with its owner's name; only
the owner saves or deletes it) and **apply automatically** - the list is
read as soon as it is chosen; one that does not sets its filters and waits
for Go. Both need the columns `IS_PUBLIC` and `AUTO_APPLY` of
`z2ui5_t_rap_var` (added 2026-10, third round); a system whose table lacks
them keeps private views that always apply.

## CDS Tree

`z2ui5_cl_rap_tree` (added 2026-10, third round) is a list report whose rows
are the nodes of the entity's hierarchy - each under its parent, indented by
its level, with a button that expands and collapses it; Expand all and
Collapse all in the toolbar. The hierarchy comes from the annotations
(`z2ui5_cl_rap_util=>read_hierarchy`, see "Metadata"), from the constructor
or from `z2ui5_if_rap_ext~adjust_hierarchy`:

```abap
client->nav_app_call( NEW z2ui5_cl_rap_tree(
  cds_view_name = `ZC_ORG_UNIT`
  "only where the annotations do not say it
  hierarchy     = VALUE #( node_field = `ORGUNIT` parent_field = `PARENTUNIT` )
  delete_mode   = z2ui5_cl_rap_util=>cs_tree_delete-move_up
  expand_levels = 2 ) ).
```

- The nodes are read at once, up to `max_rows` (default 1000), sorted by the
  order of the siblings (`siblingsOrder`, `siblings order by`), then by the
  list report's order. Expanding and collapsing is a roundtrip that reads
  nothing - a collapsed node's descendants stay in the rows, hidden
  (`ZZROW_VISIBLE`; the table does not grow then). The rows are read again
  after a filter, a search, a save on the object page and a delete.
- A node whose parent is not among the rows read (filtered away, beyond
  `max_rows`) is shown as a root; a cycle does not loop. The CDS hierarchy's
  `start where` is read, not applied - the roots are the nodes without a
  parent.
- **Create child** opens the object page of a new record with the parent
  field set to the selected node. **Delete** asks, then deletes by the
  delete mode (`cs_tree_delete`): `SUBTREE` (default) the node's
  descendants first, then the node; `MOVE_UP` gives the children the
  node's parent, then deletes it; `LEAF` deletes only a node without
  children. Every write goes through `write_row` (RAP, or a table whose
  writes the extension allowed) and stops at the first that fails. The
  delete mode comes from the constructor, the hierarchy (`adjust_hierarchy`)
  and, per node, `get_delete_mode`.
- The filter bar, the search, the views, the actions and the object page are
  the list report's; the tree uses the responsive table.

## Flexible Column Layout

`z2ui5_cl_rap_fcl` (added 2026-10, third round) shows the list report and
the object page side by side in a `sap.f.FlexibleColumnLayout` (1.46): the
list in the first column, the object page a row opens in the second, the
object page of a child in the third.

```abap
client->nav_app_call( NEW z2ui5_cl_rap_fcl(
  cds_view_name = `/DMO/C_TRAVEL_A_D`
  title         = `Travels` ) ).

"any list report - a worklist, a tree, a subclass - as the first column
client->nav_app_call( NEW z2ui5_cl_rap_fcl(
  list = NEW z2ui5_cl_rap_worklist( cds_view_name = `/DMO/I_TRAVEL_U`
                                    segment_field = `Status` ) ) ).
```

**The design decision.** The floorplans are apps of their own and call each
other with `nav_app_call` - that stays the default, nothing changes without
this class. For the column layout they are not rewritten: the host keeps
them as public attributes (`mo_begin`, `mo_mid`, `mo_end` - the core resolves
their bindings through them, `MO_BEGIN->MR_DATA`) and calls their `main( )`
with a client of its own, `z2ui5_cl_rap_fcl_client`, which hands every call
to the real client except these:

- `view_display` keeps the floorplan's view; the host puts the content of
  each column's view (its `Page`, without the `Shell`) into its column of one
  view and declares their namespaces on its root
  (`z2ui5_cl_rap_util=>compose_view`). Nested views were the other way - the core has two
  (`nest_view_display`, `nest2_view_display`), a third column has none.
- `_event` puts the column in front of the event (`MID~SAVE`); the host
  routes the event to that column's floorplan, which sees `SAVE`.
- `nav_app_call` of an object page opens it in the next column (from the
  third: the third again); any other app (a value help, an action dialog)
  is called as before and returns to the column that called it.
- `nav_app_leave` in the second or third column closes it (the page's back
  button), and the floorplan to its left is called as if the page had
  returned - `check_on_navigated( )`, `get_app_prev( )` the closed page - so
  the list report reads its rows again after a save. In the first column it
  leaves the host.

The layout (`OneColumn`, `TwoColumnsMidExpanded`,
`ThreeColumnsMidExpanded`) follows the open columns; the user resizes them
with the layout's own arrows. The client is created for each call and never
kept, so it does not travel through the draft. A floorplan that keeps the
client it was called with, or names a new member of `z2ui5_if_client`, needs
the client class extended - it implements every method of the pinned core's
interface.

## CDS Object Page

Renders an object page for a single record of a CDS entity:
- Header title/description from `@UI.headerInfo`
- Header from the `@UI.facet` entries with `purpose: #HEADER`, else attributes from `@UI.identification` (fallback: first visible fields)
- Status attributes with criticality from `@UI.dataPoint`
- Sections from `@UI.facet`: collections with subsections, field groups, identification, tables of an association (`#LINEITEM_REFERENCE` - the target and the rows from the DDL source's association, or from `resolve_association`); Create in a composition's table
- An avatar from `@UI.headerInfo.imageUrl` / `typeImageUrl`
- Edit/Save/Delete (unless `@UI.updateHidden` / `.deleteHidden`) and the `@UI.identification` actions where the entity allows them - grouped into menu buttons, typed by criticality, at a section when qualified or in a field group; the actions of a child table on its selected rows; keys read-only on change, required fields checked, value helps, suggestions and dropdowns in edit mode, the fields of a save's messages marked; a draft business object edited in its draft, an own draft resumed, another user's shown as "locked by"; the feature control of `GET PERMISSIONS` (operations, actions, read-only and mandatory fields)
- 1:n children as a MultiInput (an entry `value: '_Assoc.Element'`), child tables edited in edit mode, side effects in a draft, custom sections placed before or after a facet, "Change Information" and change documents (see below)
- A button that copies a link to the record (see "Deep links")
- User-format dates/times, Yes/No booleans, amounts/quantities with unit via `@Semantics`

### abap2UI5 Object Page Call
```abap
"val: any structure typed after the CDS entity
client->nav_app_call( NEW z2ui5_cl_rap_object_page( val = ls_row ) ).

"or read by key
client->nav_app_call( NEW z2ui5_cl_rap_object_page(
  cds_view_name = `I_COUNTRY`
  keys          = VALUE #( ( name = `Country` value = `DE` ) ) ) ).
```

### Object page: children, side effects, sections

**1:n children as tokens.** An `@UI.identification` or `@UI.fieldGroup`
entry whose `value` is an association path shows the children of that
association as the tokens of a `MultiInput` - in the section of its
qualifier (an unqualified identification entry in the general section):

```cds
annotate view ZC_TRAVEL with {
  @UI.fieldGroup: [{ qualifier: 'General', position: 40, value: '_Tags.TagId', label: 'Tags' }]
  _Tags;
}
```

In edit mode a value typed and confirmed with Enter, or chosen in the value
help of the child's element, creates a child by association (the
composition fills the fields that point at the record); a deleted token
deletes its child. A draft business object writes both into the draft at
once (committed, not activated - Save activates them, Cancel discards
them); without draft they wait for Save and are written after the record,
each on its own. Create needs the child's create (`create by association`,
its feature control and `@UI.createHidden`), delete the child's delete -
both checked on the server for every event.

**Child tables in edit mode.** A `#LINEITEM_REFERENCE` table becomes
editable with the page: a cell is an input where the row may be changed
(the child's update, its instance feature control from `GET PERMISSIONS`,
`@UI.updateHidden` per row, and not for a static `field ( readonly )`, a
key - except in a new row -, a field the composition fills, a virtual
element or a file); a row has a delete button where it may be deleted;
Create adds a row. With draft each of these goes into the draft at once;
without draft the rows are written on Save (new ones created, changed ones
updated - each checked like every write, against the record as it is
stored). The rows carry the columns `cs_row_flag` (`ZZUPDKZ`, `ZZDELKZ`,
`ZZNEWKZ`), set on the server - what the browser sends back in them decides
nothing.

**Side effects.** The BDEF's `side effects` cannot be read (no table holds
the BDEF source), so the page decides by `get_side_effect_fields` (an
extension: `z2ui5_if_rap_ext~get_side_effect_fields`) which fields update
the draft at once. The default is `*` - every field - for a business object
with draft and nothing without one: a draft runs its determinations on
every modify, so any field may change others, and the `change` event
(never `liveChange`) costs one roundtrip per value the user leaves. Such a
change is written into the draft, the draft read back, its field control
and its children read again, and the page shown with what the business
object determined. Without draft nothing reaches the business object
before Save, and the list does nothing. A changed cell of a child table
goes into the draft when the list is not empty.

**Custom sections and the header.** `z2ui5_if_rap_ext~get_custom_sections`
names sections with their place, `extend_view` fills them:

```abap
METHOD z2ui5_if_rap_ext~get_custom_sections.
  sections = VALUE #( ( id = `NOTES` title = `Notes` anchor = `Booking` placement = `BEFORE` ) ).
ENDMETHOD.

METHOD z2ui5_if_rap_ext~extend_view.
  IF spot = z2ui5_cl_rap_floorplan=>cs_spot-custom_section AND section_id = `NOTES`.
    container->tag( `Text`
        )->a( n = `text`
              v = `...` ).
  ENDIF.
ENDMETHOD.
```

The spot `HEADER_CONTENT` adds controls to the header behind its facets
(or its attributes and data points).

**Change information and change documents.** The administrative fields
(`@Semantics.user.createdBy`, `.systemDateTime.createdAt`,
`.user.lastChangedBy`, `.systemDateTime.lastChangedAt`) form a read-only
section "Change Information" at the end - not on create, and not when one of
them is placed in a field group or the identification already. A table of
change documents works as before through a `#LINEITEM_REFERENCE` facet of an
association to them; without one, `get_change_documents` names a CDS entity
and its filter, and the page adds a read-only section "Changes" with its
`@UI.lineItem` - no dependency on a change document framework.

## Deep links

`z2ui5_cl_rap_start` opens a floorplan from its URL - or the startup
parameters of a launchpad tile - so a link outlives the abap2UI5 draft:

```
...?app_start=zcl_my_rap_start&floorplan=OBJECT_PAGE&entity=I_COUNTRY&Country=DE
```

`floorplan` is `OBJECT_PAGE` (the default when keys are given),
`LIST_REPORT` or `WORKLIST`; every other parameter is a key of the object
page - and, for a list report or a worklist, the value of the filter of the
field it names (case-insensitive; a field outside the filter bar gets a
filter of its own, a parameter that names no field is ignored), applied
over the default view (`set_filter_presets`). `mode=edit` opens the object
page in edit mode - a draft business object in a draft of its own - where
Edit would be allowed; `mode` is therefore no key name. A semantic object's
parameters that are called differently are mapped by
`z2ui5_if_rap_ext~map_inbound_parameter` (or a redefined `map_parameters`):

```
...?app_start=zcl_my_rap_start&floorplan=LIST_REPORT&entity=/DMO/C_TRAVEL_PROCESSOR_M&AgencyID=070001
...?app_start=zcl_my_rap_start&entity=I_COUNTRY&Country=DE&mode=edit
```

A URL can name any entity, so `z2ui5_cl_rap_start` opens none by itself - a
subclass lists the entities it may open:

```abap
CLASS zcl_my_rap_start DEFINITION PUBLIC INHERITING FROM z2ui5_cl_rap_start
  FINAL CREATE PUBLIC.
  PROTECTED SECTION.
    METHODS get_allowed_entities REDEFINITION.
ENDCLASS.

CLASS zcl_my_rap_start IMPLEMENTATION.
  METHOD get_allowed_entities.
    result = VALUE #( ( `I_COUNTRY` ) ( `/DMO/C_TRAVEL_PROCESSOR_M` ) ).
  ENDMETHOD.
ENDCLASS.
```

`get_extension` hands the floorplan an extension, and
`z2ui5_cl_rap_start=>get_link( )` builds such a link. The object page's link
button copies one when `z2ui5_if_rap_ext~get_start_app` names the subclass,
else the link of the app's current state (valid while its draft lives).

## CDS Worklist

The items to work through: a table with `@UI.lineItem` columns, a search
field, sorting, the actions and row navigation. With `segment_field`, a tab
per value of that field with its count; without it, a tab per
`@UI.selectionVariant` of the entity:

```abap
client->nav_app_call( NEW z2ui5_cl_rap_worklist(
  cds_view_name = `/DMO/I_TRAVEL_U`
  title         = `Travels`
  segment_field = `Status` ) ).
```

## CDS Overview Page

Renders a grid of cards for multiple CDS views - `TABLE` (the first rows), `KPI`
(an aggregated number) or `CHART` (the first `@UI.chart`: bars for `#BAR` and
`#COLUMN`, shares of the total for `#DONUT` and `#PIE`, a trend for `#LINE` and
`#AREA` - drawn with `sap.m` controls, which every UI5 runtime has; the card's
`chart_type` overrides it). A card with `presentation_variant` shows that
`@UI.presentationVariant`: its chart, or the table sorted and sized as the
variant says. Every card links to the list report of its view; a table row
opens its object page.

```abap
client->nav_app_call( NEW z2ui5_cl_rap_overview_page(
  title = `Business Overview`
  cards = VALUE #(
    ( cds_view_name = `I_COUNTRY`  title = `Countries`  card_type = `TABLE` max_rows = 5 )
    ( cds_view_name = `I_LANGUAGE` title = `Languages`  card_type = `KPI` )
    ( cds_view_name = `ZC_SALES`   title = `Revenue`    card_type = `KPI`
      kpi_field = `NetAmount` kpi_aggregation = `SUM` kpi_unit = `EUR` )
    ( cds_view_name = `ZC_SALES`   title = `By region`  card_type = `CHART` ) ) ) ).
```

A KPI card aggregates `kpi_field` (`SUM`, `AVG`, `MIN`, `MAX`), else the first
numeric `@UI.dataPoint` field, else counts the rows.

The cards bind their rows through the public `mr_card_rows`: after
`load_all_cards( )` has filled `mt_card_data`, `collect_card_rows( )` moves
each card's rows into a component of it (`CARD_1`, `CARD_2`, ... by position)
and points the card's `data_ref` there. A redefined `render_table_card` binds
`is_card-data_ref->*` the way the shipped one does, and a redefined
`load_all_cards` only has to fill `mt_card_data`.

## Changes

### 2026-09

Additive for callers and subclasses, with these exceptions a subclass may notice:

- The floorplans have a superclass, `z2ui5_cl_rap_floorplan`. A subclass that
  declared a method of the same name as one of its new protected methods has
  to rename it.
- `z2ui5_cl_rap_worklist` is a subclass of `z2ui5_cl_rap_list_report`; its
  `cs_event` is the list report's (same values for `refresh` and `back`), and
  the list report's events (`GO`, `SEARCH`, `CREATE`, `ACTION`, `ROW_PRESS`,
  `FILTER_VALUE_HELP`) no longer reach a worklist subclass's `on_event`.
- Create, Edit and Delete appear only where the entity is writable (see
  "Writing").
- When the list report has actions, `mr_data` rows carry the selection column
  `ZZSELKZ`; `to_entity_row( )` drops it.
- The action dialog calls `z2ui5_cl_rap_value_help` for a value help instead
  of rendering its own popup; `mt_vh_data` holds the rows the value help
  returned.
- The overview page's cards are `sap.f.Card`s in a `sap.f.GridContainer`
  instead of panels and tiles in a layout grid; `count` is the number of rows
  of the view.

### 2026-10

- New protected members in the floorplans (`render_sort_controls`,
  `get_order_by`, `render_header_facets`, `get_display_text`,
  `render_dialog_field`, `render_extension`, ...) - the same rename rule as
  above applies to a subclass.
- `z2ui5_if_rap_ext` has a new method, `extend_view` - `DEFAULT IGNORE`, so
  existing implementations keep compiling.
- A draft-enabled business object is written through its draft (see
  "Writing").
- The list report sorts in the database, and its "more" button loads rows
  instead of the table growing over the loaded ones; the object page header
  follows the header facets when there are any.

### 2026-10, second round

- **A database table is read-only** until an extension allows its writes
  (`adjust_capabilities`, see "Writing") - an app that changed a table through
  a floorplan needs one now.
- New protected members in the floorplans (see the lists above) - the rename
  rule applies to a subclass. `render_cell` has a new optional `client`.
- `z2ui5_if_rap_ext` has the new methods `adjust_capabilities` and
  `get_start_app` - `DEFAULT IGNORE`.
- Appended components: `ty_s_result` (`details`), `ty_s_field_info`,
  `ty_s_entity_info`, `ty_s_action`, the list report's `ty_s_filter`, the
  object page's `ty_s_child`, the overview's `ty_s_card`, `ty_s_card_data` and
  `ty_s_chart_row` grew at their end. New optional parameters (`context`,
  `host`, `with_selection`, `value_state`) leave every call as it was.
- New objects: `z2ui5_cl_rap_start` (deep links), `z2ui5_cl_rap_variant` and
  the table `z2ui5_t_rap_var` (views), `z2ui5_cl_rap_test_start` (the demo's
  deep links).
- The object page of a draft business object edits in a committed draft; the
  value help of an entity with selection fields is a `sap.m.Dialog`.

### 2026-10, third round

- The object page header shows only the unqualified `@UI.identification`
  fields and actions; a qualified entry belongs to the
  `#IDENTIFICATION_REFERENCE` facet (or section) of its qualifier - up to
  now every such facet showed every identification field.
- A `#FOR_ACTION` entry of a `@UI.fieldGroup` is no field of the group any
  more, but an action of its section.
- The action buttons of the list report, the worklist and the object page are
  drawn by `render_action_buttons` (new, protected): actions sorted by
  position (one without a position last), action groups as `MenuButton`s, a
  criticality as the button type. A subclass that redefined `render_toolbar`
  keeps its own buttons.
- `run_action` runs a static action without rows, and its result carries the
  keys of a record a factory action created; `z2ui5_cl_rap_eml=>execute_action`
  has the new optional `is_static` and `isolated`.
- Appended components: `ty_s_field_info` (`identifications`),
  `ty_s_header_info` (`type_image_url`), `ty_s_action` (`qualifier`,
  `criticality`, `group_id`, `invocation_grouping`), `ty_s_entity_info`
  (`action_groups`, `create_hidden`, `update_hidden`, `delete_hidden`), the
  object page's `ty_s_child` (`actions`) and `cs_event` (`child_action`); new
  types `ty_s_action_group` and the floorplan's `ty_s_action_entry`. New
  optional parameters: `run_action-invocation_grouping`,
  `get_identification_fields-qualifier`.
- New protected members (see the lists above) - the rename rule applies to a
  subclass.
- Reading (see "Reading"): a custom entity is read through its query provider
  (new class `z2ui5_cl_rap_query`, the only one implementing the
  `IF_RAP_QUERY_*` interfaces), a virtual element is calculated and no longer
  selected, filtered or sorted by ABAP SQL. `select_rows` and `count_rows` keep
  their signatures; a failed read sets the new `mv_read_error`, and the list
  report, the worklist, the object page and the value help show it. The
  search also covers `STRING` fields and hidden `@Search.defaultSearchElement`
  fields. Appended components: `ty_s_field_info` (`is_virtual`,
  `virtual_calc_class`, `sort_transform_class`, `filter_transform_class`,
  `search_fuzziness`), `ty_s_entity_info` (`query_class`); new types and
  methods of `z2ui5_cl_rap_util` (`get_read_info`, `build_query_filter`,
  `parse_order_by`, `remove_where_fields`, `aggregate_rows`, ...) and the
  floorplan's `query_available`.
- RAP behaviour and draft (see "Writing"): feature control through
  `GET PERMISSIONS`, reading a draft back, keeping a draft when leaving, the
  editing status in the list report, late numbering through `CONVERT KEY`,
  the optimistic check before an update. New classes `z2ui5_cl_rap_eml_perm`,
  `_read` and `_key` (one dynamic EML statement each, called dynamically).
  Leaving the object page while editing a draft no longer discards it - the
  user is asked. A key field is now edited through the field control
  (`get_field_for_edit`) instead of the `editable` parameter of
  `render_field_input`. The object page's `render_action_buttons` has the new
  optional `disabled`, the list report's `enabled_values`; the list report's
  rows of a business object can carry the columns `cs_row_column` (`ZZDRAFT`,
  `ZZDRAFT_TEXT`, `ZZACTION_n`). Appended: `cs_text` (11 texts, text pool
  043-053), the object page's `cs_event-leave_decision` and
  `ty_s_child-disabled_actions`, the list report's
  `cs_event-selection_change`; new types of `z2ui5_cl_rap_util`
  (`ty_s_permissions`, `ty_s_perm_set`, `ty_s_field_control`,
  `ty_s_draft_status`, `cs_editing_status`) and its functions
  (`get_field_control`, `get_instance_permissions`, `get_draft_status`, ...).
  The derived type of a create by association is tried as `\ASSOC=` (the
  documented form) before `\ASSOCIATION=`.
- Messages, files, inbound navigation: `show_messages` shows by severity
  (a toast, a message box or a message view) instead of one message box,
  and has the new optional `details` and `fields`; the floorplan's
  `ty_s_message` is now `z2ui5_cl_rap_util=>ty_s_message` (the same
  components, `target` appended). `render_field_input` has the new optional
  `record` and draws a file field as a link and an Upload button. The list
  report clears the files of its rows (`clear_large_objects`), and the
  object page reads a record it got without keys again when the entity has
  a file field. New public members: the floorplan's `mt_message_items`,
  `mv_file_value`, `mv_file_name`, `cv_event_upload`, `cv_event_download`,
  `cv_event_upload_open`, `cv_event_upload_cancel`, the list report's
  `set_filter_presets`, `z2ui5_cl_rap_start=>cs_param-mode` and
  `cs_mode`, `z2ui5_cl_rap_eml=>read_action_defaults`;
  `z2ui5_if_rap_ext~map_inbound_parameter` (`DEFAULT IGNORE`). Appended:
  `ty_s_field_info` (`is_large_object`, `lob_mime_field`,
  `lob_file_name_field`, `lob_mime_types`, `lob_disposition`,
  `is_mime_type`), `cs_text` (9 texts, text pool 054-062). The
  floorplan's own dialogs are now read by the view gate too.
- Filter bar, table, views, display: the filter bar is no longer one
  input per filter in the subheader - the subheader holds the search, the
  editing status, "adapt filters" and Go, and the filters (a label over the
  control of their type) are the first content of the page. A filter value
  that excludes (`!...`) is ANDed with the others instead of ORed, and `=`
  alone is the empty condition. The list report's constructor has the new
  optional `initial_load`, its rows can carry the columns
  `cs_row_column-text_prefix` (`ZZTEXT_n`); the rows are selectable also
  for an intent navigation with `semanticObjectBinding`. A criticality
  cell shows its icon (`#WITHOUT_ICON` leaves it out), 5 is Information
  everywhere (`criticality_state`, `criticality_expression`, which has the
  new optional `kind`). `navigate_to_intent` sends a parameter named
  several times as an array. The object page applies a field group
  entry's `label`. Appended: `ty_s_field_info` (`line_item_width`,
  `line_item_crit_repr`, `line_item_value_qualifier`, `line_item_hidden`,
  `line_item_icon_url`, `line_items`, `is_image_url`, `text_association`,
  `is_semantic_text`, `is_language`, `is_consumption_hidden`,
  `semantic_object`, `sem_object_bindings`, `entry_criticality`,
  `entry_crit_repr`, `entry_importance`, `entry_hidden`),
  `ty_s_field_group` (`criticality`, `crit_representation`, `importance`,
  `hidden`), `ty_s_value_help` (`text_element`, `fixed_values`),
  `ty_s_action` (`sem_object_bindings`), `ty_s_presentation_variant`
  (`group_by`), `ty_s_selection_variant` (`select_options`),
  `ty_s_entity_info` (`row_criticality`, `group_by`,
  `sel_pres_variants`), the list report's `ty_s_filter` (`control`,
  `tokens`, `entries`, `input`, `state`, `is_added`), `ty_s_column`
  (`width`) and `cs_event` (tokens, conditions, adapt filters, column
  order), the overview's `ty_s_card_data` (`line_item_qualifier`),
  `z2ui5_cl_rap_variant`'s `ty_s_data` (`filter_fields`, `column_order`,
  `column_widths`, `group_field`) and `ty_s_variant` (`is_public`,
  `auto_apply`, `owner`), `cs_text` (24 texts, text pool 063-086). New:
  the table columns `IS_PUBLIC` and `AUTO_APPLY` of `z2ui5_t_rap_var`,
  `z2ui5_cl_rap_variant=>has_public_views`, the util's
  `conditions_to_filter`, `filter_to_conditions`, `split_filter_value`,
  `get_filter_control`, `get_filter_list`, `selection_variant_filters`,
  `selection_variant_where`, `get_line_item_columns`,
  `criticality_binding`, `get_navigation_params`, `normalize_css_width`
  and types `ty_s_line_item`, `ty_s_sel_pres_variant`, `ty_s_condition`,
  `cs_condition_op`, `cs_filter_control`; the list report's
  `cs_initial_load`, `ty_s_filter_entry`, `ty_s_condition_row` and its
  public `mv_variant_public`, `mv_variant_auto`, `mt_condition`,
  `mt_condition_op`, `mt_adapt`, `mv_group_field`, `mt_group_item`,
  `mv_no_data`. New protected members (see the lists above) - the rename
  rule applies to a subclass.
- Object page (children, side effects, sections, see "Object page:
  children, side effects, sections"): an `@UI.lineItem`,
  `@UI.identification` or `@UI.fieldGroup` entry whose `value` is an
  association path is no longer taken for an entry of the element that
  carries it, but collected in the new `ty_s_entity_info-path_fields`. The
  child tables always carry the selection column and the columns
  `cs_row_flag`, are read from the draft while the page edits one and are
  editable in edit mode (Create adds a row there instead of opening a child
  object page, and a row does not navigate); the child rows are read again
  after Edit, Cancel and Save, not on the return from a called app in edit
  mode. `render_sections` places each section with the new
  `render_section` and `render_custom_section`. `mr_child_rows` holds a
  component `PATH_n` per MultiInput. New optional parameters:
  `write_row-in_draft`, `write_draft-check`, `render_extension-section_id`,
  `render_section_fields-it_paths`, `z2ui5_cl_rap_eml=>create-in_draft`
  and `=>delete-in_draft`, `z2ui5_if_rap_ext~extend_view-section_id`. New:
  `z2ui5_if_rap_ext~get_custom_sections`, `~get_side_effect_fields`,
  `~get_change_documents` (`DEFAULT IGNORE`), `z2ui5_cl_rap_eml=>read_by_association`,
  the spots `cs_spot-custom_section` and `-header_content`, the util's
  `parse_association_path`, `parse_path_fields`, `is_side_effect_field`,
  `get_changed_fields`, `get_admin_fields`, `order_sections` and types
  `ty_s_path_field`, `ty_s_custom_section`, `ty_s_section_slot`; the object
  page's `cs_row_flag`, `ty_s_token`, `ty_s_path_value`,
  `cv_key_separator`, `ty_s_path_child`, `ty_s_pending`, `cs_section_id`
  and `cs_event` (`path_token_add`, `path_token_delete`, `path_value_help`,
  `child_row_add`, `child_row_delete`, `child_cell_change`,
  `side_effect`). Appended: `ty_s_child` (`can_update`, `can_delete`,
  `read_only`), `cs_text` (2 texts, text pool 087-088). New protected
  members (see the lists above) - the rename rule applies to a subclass.
- **Tree, analytical list, grid table, column layout, fuzzy search**: new
  classes `z2ui5_cl_rap_tree`, `z2ui5_cl_rap_fcl` and
  `z2ui5_cl_rap_fcl_client`. The list report's constructor has the new
  optional `table_type` and `analytical`, `cs_table_type` is new and
  `cs_row_column` has the appended `row_kind`, `row_label` and
  `row_visible`. `render_toolbar` now calls the new `render_toolbar_content`
  with the toolbar it opened - a subclass that redefined `render_toolbar`
  keeps its own toolbar, one that wants to add to the shipped one redefines
  `render_toolbar_content` (the grid table calls only that one). The table's
  `growing` is off when the rows have `ZZROW_VISIBLE`. New protected:
  `render_grid_table`, `render_grid_column`, `apply_analytics`,
  `read_aggregates`, `add_row_columns`, and `get_selected_rows` redefined
  (group and total rows are never selected). `build_search_condition` of the
  floorplan has the new optional `entity_name`. New:
  `z2ui5_if_rap_ext~build_search_condition` and `~adjust_hierarchy` (`DEFAULT IGNORE`),
  `cs_floorplan-tree` and `-fcl`; the util's `get_hierarchy`,
  `get_hierarchy_fields`, `parse_ddl_hierarchy`, `read_hierarchy`,
  `build_tree`, `get_tree_descendants`, `get_tree_children`,
  `get_tree_indent`, `normalize_aggregation`, `get_aggregations`,
  `build_aggregate_select`, `get_fcl_layout`, `get_view_namespaces`,
  `get_view_body`, `compose_view`, `to_column_event`,
  `split_column_event`, `get_search_fuzziness`, `build_fuzzy_search`,
  `get_search_fields`, the types `ty_s_hierarchy`, `ty_s_tree_node`,
  `ty_s_aggregation` and the constants `cs_tree_delete`, `cs_row_kind`;
  `aggregate_rows` knows `COUNT_DISTINCT`. Appended:
  `ty_s_field_info-aggregation_default`, `cs_text` (10 texts, text pool
  089-098).

## Development

Three gates run offline, no SAP system needed (CI runs the same on every push
and PR):

```bash
npm ci                          # the pinned toolchain, linter and render runtime
npm run lint                    # abaplint: syntax/style, 0 issues expected
npm run unit                    # ABAP Unit tests that need no system, transpiled -
                                # the util and the list report and object page
npx abap2ui5lint                # every generated view: UI5 metadata + headless render
npx abap2ui5lint --no-render    # fast loop, no browser
npm run check                   # all three
```

abaplint checks against the abap2UI5 release pinned in `abaplint.jsonc`
(`scripts/core-pin.mjs`, moved weekly by `bump-core.yml`); the weekly run of
`abap-standard.yaml` is the canary against the core's `main`.

End-to-end still needs a system: install via abapGit and run
`z2ui5_cl_rap_test`.

## Contributing

Issues and pull requests are welcome - see [CONTRIBUTING.md](CONTRIBUTING.md)
and, for the rules of the code, [AGENTS.md](AGENTS.md). Security issues:
[SECURITY.md](SECURITY.md).

## License

MIT - see [LICENSE](LICENSE).
