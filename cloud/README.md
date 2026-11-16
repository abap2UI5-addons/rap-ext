# cloud/ - the files of the branch `cloud`

Every file here replaces the file of the same name in `src/` on the branch
`cloud`, the version of rap-ext to link in ABAP Cloud.
The branch is `main` plus one commit that puts these files into `src/`,
force-pushed by `.github/workflows/cloud-branch.yaml` on every push to `main`
(like the 702 branch of abap2UI5) - so GitHub shows it 1 commit ahead of
`main`. Before that, `scripts/cloud.mjs` builds the same tree into
`build/cloud` and checks it (`npm run lint:cloud`). Do not change the
branch `cloud` itself.

| File | In place of |
| --- | --- |
| `z2ui5_cl_rap_platform.clas.abap` / `.clas.xml` | the on-premise reads and calls (annotation service, DDIC, table maintenance) - the same public section, nothing on-premise behind it |
| `z2ui5_dd_rap_test_popup.ddls.asddls` | the demo popup without the value help on `I_MessageSeverity`, which is not in the released API set |

A new on-premise dependency goes into `src/z2ui5_cl_rap_platform.clas.abap`,
its public method into both versions of the class. Nothing else names an
on-premise object - not even by a literal: the ABAP Cloud syntax check
reports those too.
