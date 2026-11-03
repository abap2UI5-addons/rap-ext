---
layout: home

hero:
  name: "RAP Extension"
  text: "Fiori-elements-style apps for CDS views, generated at runtime."
  image:
    src: /favicon.png
    alt: abap2UI5
  actions:
    - theme: brand
      text: Get started
      link: /guide
    - theme: alt
      text: GitHub
      link: https://github.com/abap2UI5-addons/rap-ext
    - theme: alt
      text: All addons
      link: https://abap2ui5-addons.github.io/

features:
  - title: "Eight floorplans from list report and object page to value help and action dialog"
  - title: "One-line call via nav_app_call with the CDS view name"
  - title: "Every rendering and event step is a protected method a subclass can redefine"
  - title: "Interface z2ui5_if_rap_ext extends data, metadata, texts and events without a subclass"
  - title: "Writes through RAP (EML) incl. actions, drafts and feature control"
  - title: "ABAP Cloud path reads annotations through the XCO API with listed limits"
  - title: "Demo app z2ui5_cl_rap_test with deep links"
---

## What it does

rap-ext reads a CDS entity and its UI annotations, metadata extensions included, and builds a list report, worklist, tree, flexible column layout, object page, overview page, value help or action dialog from them, writing through RAP where the entity is a business object. It is for ABAP developers on a standard ABAP system who want such a UI with one line of code and can still redefine any step of it with plain abap2UI5 view code, since every floorplan is a non-final class with protected methods. It is not for plain internal tables. The README states that none of it has been clicked through in an SAP system yet.

## Requirements

- Standard ABAP 7.58 or higher
- abap2UI5 (checks run against the release pinned in abaplint.jsonc)
- ABAP Cloud: additional path with limits, written without an ABAP Cloud system
- UI5 1.77 or higher in the browser
- For the RAP parts of the demo: the /DMO/ flight reference scenario

## Installation

With [abapGit](https://abapgit.org), from [the repository](https://github.com/abap2UI5-addons/rap-ext):

- Install with abapGit in this order: abap2UI5, then this repository (branch main)
- Run the demo app with ?app_start=z2ui5_cl_rap_test

The [Guide](/guide) has every step.

## A first app

```abap
client->nav_app_call( NEW z2ui5_cl_rap_list_report(
  cds_view_name = `I_COUNTRY`
  title         = `Countries` ) ).
```

## Links

- [The repository](https://github.com/abap2UI5-addons/rap-ext) - issues and pull requests welcome
