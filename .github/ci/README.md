# The shared CI template of abap2UI5-addons

The addons of [abap2UI5-addons](https://github.com/abap2UI5-addons) run the
same checks: abaplint (Standard, Cloud, 702), the transpiled ABAP Unit tests,
the namespace rename, the abap2UI5-linter, the GitHub Pages site and the
monthly dependency bump. Until now every addon carried its own copy of each
workflow, and the copies drifted - in names (`abap-standard.yaml`,
`ABAP_STANDARD.yaml`, `abaplint.yaml`, `check.yml`), in action pins, in which
checks exist at all, and in fixes that reached some copies and not others
(the badges upload without `include-hidden-files`). This template is the one
copy. An addon calls it with the checks it has; a fix made here reaches every
addon with the next bump of its pin.

It lives in rap-ext because it has to live in an existing repository of the
organisation, and rap-ext is the one addon without GitHub releases of its own:
**the releases of rap-ext are the releases of this template** (`ci-v1.0.0`,
...), which is what lets the monthly bump move every caller's pin with no
change to `update-deps.mjs` (below). If rap-ext ever needs releases of its
own, the template moves to `abap2UI5-addons.github.io` - the natural long-term
home, and a find-and-replace of the `uses:` lines in the callers.

## The workflows

| Workflow | What it runs | Permissions the calling job grants |
|---|---|---|
| [`addon-check.yaml`](../workflows/addon-check.yaml) | abaplint per config, npm scripts, `npm run unit`, `npm run rename`, `npx abap2ui5lint` + badges | `contents: write` - only `publish-badges` uses it (on the `branch` input, `main` by default, never for a pull request), but GitHub refuses the whole run when a called job asks for more than the caller grants, so every caller grants it |
| [`addon-702.yaml`](../workflows/addon-702.yaml) | the downport to the branch `702`, then abaplint on that branch | `contents: write` |
| [`addon-build-rename.yaml`](../workflows/addon-build-rename.yaml) | the branch `rename_<name>` for a parallel installation | `contents: write` |
| [`addon-pages.yaml`](../workflows/addon-pages.yaml) | the VitePress site from `site/`, deployed from the `branch` input (`main` by default) | `contents: read`, `pages: write`, `id-token: write` |
| [`addon-bump-deps.yaml`](../workflows/addon-bump-deps.yaml) | the monthly pull request: the shared files from abap2UI5, npm, pinned actions, `extra`, `.github/deps.json` | `contents: write`, `pull-requests: write`; secret `DEPS_TOKEN` passed explicitly |

Every job inside declares its own permissions; a job that runs the code of a
pull request has `contents: read` whatever the caller grants. Secrets are
never inherited: `addon-bump-deps.yaml` takes `DEPS_TOKEN` by name, the others
need none. Inside it, the token reaches one job only, and that job runs no
npm and no script of the addon: the job `update` (npm, `update-deps.mjs
--actions`, `extra`, `pin-deps.mjs bump`) has `contents: read` and no secret
at all - `--actions` reads the latest releases, public data, with the job's
own read-only token - and hands what it changed to the job `pr` as a patch
artifact; `pr` lays it over a fresh checkout and runs create-pull-request
with `DEPS_TOKEN`. A just-bumped package can therefore not reach the token
through `$GITHUB_ENV`, `$GITHUB_PATH` or a file a later step runs. No
checkout keeps credentials in `.git/config` (`persist-credentials: false`).

### `addon-check.yaml` inputs

| Input | Default | |
|---|---|---|
| `abaplint` | `'["./abaplint.jsonc"]'` | JSON array of abaplint configs, one job each (`npx abaplint <config>`) - add `".github/abaplint/abap_cloud.jsonc"` for the Cloud lint. `'[]'` for none |
| `npm-scripts` | `'[]'` | JSON array of npm scripts, one job each - for a check that is more than one abaplint call (`check:702`, `lint:cloud`, `check:regex`) |
| `unit` | `false` | `npm run unit` |
| `unit-setup` | `''` | shell run before it (a checkout the tests need) |
| `rename` | `false` | `npm run rename`, the siblings taken from their pin (`RENAME_DEPS_FROM`) |
| `branch` | `main` | the branch the badges are published from - set it where the default branch is not `main` (http-connector, launchpad-kpi: `standard`); `addon-pages` takes the same input for the deploy |
| `abap2ui5lint` | `true` | `npx abap2ui5lint`, its Markdown summary, and on `branch` the badges it writes, pushed to the branch `badges` |
| `abap2ui5lint-render` | `true` | installs the browser of the render gate - `false` for an addon without views |
| `canary` | `false` | pass `${{ github.event_name == 'schedule' }}`: the siblings at the tip of their branch instead of the pin, and `canary-setup` before the lint jobs |
| `canary-setup` | `''` | e.g. `node scripts/core-pin.mjs set main` for an addon that pins the core to a release |
| `node-version` | `'22'` | every workflow takes it |

The job names a check shows on a pull request are
`check / abaplint (./abaplint.jsonc)`, `check / npm run check:702`,
`check / unit`, `check / rename`, `check / abap2ui5lint` - when an addon
adopts the template, the required status checks of its branch protection
have to be renamed to these.

### `addon-702.yaml` inputs

`repository` (required: the `owner/repo` that publishes - a fork runs
nothing), `publish` (default `true`), `downport-script` (default
`auto_downport`), `config` (the config linted on the branch `702`, default
`.github/abaplint/abap_702.jsonc`). Publishing and linting are two jobs of one
run: the push to `702` is made with the `GITHUB_TOKEN` and starts no workflow,
which is why the old `abap-702.yaml` needed a `workflow_run` trigger.

### `addon-build-rename.yaml`, `addon-pages.yaml`, `addon-bump-deps.yaml`

`namespace` (required); `install`, `build`, `path`, `cache-dependency-path`
(defaults: `npm ci --prefix site`, `npm run site`, `build/site`,
`site/package-lock.json`); `repository` (required) and `extra` (shell after
the npm and Actions update, e.g. the core pin).

## Sibling repositories: `.github/deps.json`

An addon that builds on other addons names them, each at a commit:

```json
{
  "abap2UI5-addons/layout-management": { "branch": "main", "sha": "<40 hex>" },
  "abap2UI5-addons/range-filter": { "branch": "main", "sha": "<40 hex>" }
}
```

The abaplint configs stay as they are - still with the `url` of each sibling,
so a local `npm run check` keeps working without anything of this. In CI,
[`pin-deps.mjs`](pin-deps.mjs) fetches every pinned commit and puts it into
the `folder` the dependency names: abaplint reads a dependency from its
folder when that holds files and clones the `url` only when it does not
(`loadDependencies` of `@abaplint/cli`). So the sibling is the pinned commit
in every config that depends on it on its pinned branch; a dependency on
another branch (`702`) is left alone. Two configs in one directory that give
the same folder to a pinned and an unpinned source are refused - give the
`702` one a folder of its own (`/layout-management-702`).

The rename takes the siblings from the same checkouts (`RENAME_DEPS_FROM`),
and an addon's `.github/scripts/unit.mjs` reads `deps.json` itself, so
`npm run unit` uses the pins on a laptop too (`DEPS_TIP=1` for the tips).

The core is not in `deps.json`: it is resolved as abap2UI5 CONVENTIONS §9
says - `"branch": "main"`, or a release tag moved by `scripts/core-pin.mjs`.

Locally, to lint exactly what CI lints:

```sh
node <a checkout of rap-ext>/.github/ci/pin-deps.mjs    # fills the folders, .deps/
npm run check
node <a checkout of rap-ext>/.github/ci/pin-deps.mjs clean
```

`.deps/` and `.ci-template/` belong in the addon's `.gitignore`.

### The scripts every addon carries: `update-deps.mjs`, `rename.mjs`

`.github/scripts/update-deps.mjs` and `.github/scripts/rename.mjs` are the
same bytes in every addon (and in the abap2UI5 repositories that have
them). Their source is `.github/shared/` in
[abap2UI5](https://github.com/abap2UI5/abap2UI5), whose `npm run
check:shared` compares every copy and names the addons `owner/repo` in its
manifest (`shared-file-gate.mjs`). `addon-bump-deps.yaml` pulls them: its
first step after the checkout asks that manifest for `$GITHUB_REPOSITORY`
and copies what it lists, so the monthly pull request carries a fix made
there - and runs it, since the npm step comes after. Change them in
abap2UI5, never in an addon: a local edit is pulled over next month.

### Bumping

- **The siblings:** `addon-bump-deps.yaml` moves every `sha` to the tip of its
  branch in the monthly pull request (`pin-deps.mjs bump`), with a link to the
  diff of each - and the checks of that pull request run against the new
  pins. By hand: `node pin-deps.mjs bump`.
- **The scheduled run** (`canary: true`) checks the tips every week, so an
  upstream rename is still noticed between two bumps - but it no longer
  breaks a pull request that has nothing to do with it.
- **The template itself:** callers pin it like an action, by commit with the
  release in a comment:

  ```yaml
  uses: abap2UI5-addons/rap-ext/.github/workflows/addon-check.yaml@<sha> # ci-v1.0.0
  ```

  `update-deps.mjs --actions` (the monthly pull request) moves every
  `uses: owner/repo...@<sha> # <tag>` to the latest release of `owner/repo` -
  for these lines, the latest release of rap-ext; the moves under
  `.github/workflows` reach the pull request only when the addon has the
  `DEPS_TOKEN` secret. A fix here is therefore: merge, publish a release `ci-vX.Y.Z` of
  rap-ext, and every addon picks it up in its next monthly pull request (or
  at once: dispatch its `bump-deps`).

The reusable workflows find `pin-deps.mjs` at the commit the caller pinned
(`job.workflow_repository`, `job.workflow_sha` - GitHub, September 2026), so
the script and the workflows always come from the same commit and there is
no second pin to keep in step.

## Adopting it

1. `.github/deps.json` with the sibling addons the abaplint configs name
   (`git ls-remote https://github.com/<repo> refs/heads/main` for the sha),
   and in `.github/scripts/unit.mjs` the refs read from it (see se16n).
2. `.github/workflows/ci.yaml` - the checks, replacing `abap-standard`,
   `abap-cloud`, `abap-unit`, `check-abap2ui5` and `check-rename`:

   ```yaml
   name: ci
   on:
     push:
       branches: [main]
     pull_request:
     schedule:
       - cron: '0 5 * * 1'
     workflow_dispatch:
   concurrency:
     group: ci-${{ github.ref }}
     cancel-in-progress: true
   permissions:
     contents: read
   jobs:
     check:
       permissions:
         contents: write
       uses: abap2UI5-addons/rap-ext/.github/workflows/addon-check.yaml@<sha> # ci-v1.0.0
       with:
         abaplint: '["./abaplint.jsonc", ".github/abaplint/abap_cloud.jsonc"]'
         unit: true
         rename: true
         canary: ${{ github.event_name == 'schedule' }}
   ```

3. `.github/workflows/ci-702.yaml` (push to main, dispatch) calling
   `addon-702.yaml`, replacing `publish-702` and `abap-702`;
   `build-rename.yaml`, `deploy-pages.yaml` and `bump-deps.yaml` reduced to
   their triggers and a call of the template.
4. README badges: one `ci.yaml` badge instead of one per workflow; the
   required status checks of the branch protection renamed (above).
5. Run what CI runs once locally (`npm ci`, `pin-deps.mjs`, each check) before
   the pull request. Never drop a check the addon ran before - if a new one
   (Cloud lint, unit) fails, fix the cause or leave it out and say so.

## Developing the template

`ci-template.yaml` runs actionlint over every workflow here
(`.github/actionlint.yaml` holds the one exception: actionlint 1.7.12 does not
know `job.workflow_*` yet) and `node --test ".github/ci/*.test.mjs"`.
`ci.yaml` calls the template locally (`uses: ./...`), so rap-ext runs every
change of the template on itself before a release reaches an addon.
