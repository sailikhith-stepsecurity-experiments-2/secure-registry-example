# Secure Registry example

This repository shows how to use [Harden-Runner](https://github.com/step-security/harden-runner) Secure Registry in a public repository, and where to see what it did.

With Secure Registry turned on, every npm install in a job goes through StepSecurity Secure Registry instead of directly to the public npm registry. Secure Registry:

* refuses versions that StepSecurity has flagged as **compromised**,
* holds back versions published less than **2 days** ago (the **cooldown**), and
* refuses versions on your **block list**, if you set one.

It is free for public repositories on GitHub-hosted runners. It supports **npm** and npm-compatible package managers today. Other ecosystems are planned.

Full documentation: [docs.stepsecurity.io](https://docs.stepsecurity.io)

## Add it to your workflow

Add `secure-registry: true` to Harden-Runner, and keep Harden-Runner as the first step of the job:

```yaml
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write # optional, recommended
    steps:
      - uses: step-security/harden-runner@v2
        with:
          egress-policy: audit
          secure-registry: true

      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: 22
          package-manager-cache: false
      - run: npm ci
      - run: npm test
```

Nothing else changes. `npm ci`, `npm install`, `npx`, and `pnpm install` with a lockfile pick up Secure Registry automatically.

* **`id-token: write`** lets GitHub sign a statement of which repository the job belongs to. It is optional: without it, Secure Registry still protects the job, and packages appear in run insights when Harden-Runner telemetry is reachable.
* **`package-manager-cache: false`** matters. Packages restored from a cache are never downloaded, so Secure Registry never checks them. See [Dependency caches](#dependency-caches).

### Requirements

| Requirement | Detail |
| --- | --- |
| Repository | Public |
| Owner | An organization or user without a StepSecurity subscription |
| Runner | GitHub-hosted (Linux, Windows, macOS), including `container:` jobs |
| Package manager | npm, and pnpm or Bun with a lockfile. See [Package managers](#package-managers). |

Jobs that do not meet these requirements are never failed. Harden-Runner prints a notice and npm keeps using its normal registry.

## The examples

Each workflow in [`.github/workflows`](.github/workflows) shows one scenario. They run on every push to `main` (the quick start also runs on pull requests) and can be run by hand from the **Actions** tab. Steps that are expected to be refused check for the refusal, and each scenario first checks that npm uses Secure Registry (`.github/scripts/require-secure-registry.sh`; your own workflows do not need this). What the job summary shows is written after the last step, so check it on the run page.

| Workflow | Settings | What happens |
| --- | --- | --- |
| [1. Quick start](.github/workflows/quick-start.yml) | `secure-registry: true` | `npm ci` and `npm test` pass. All 65 packages in the lockfile go through Secure Registry. |
| [2. Cooldown and exemptions](.github/workflows/cooldown.yml) | default cooldown, then `cooldown.exemptions` | The latest nightly TypeScript build is usually less than a day old. The first job cannot install it. The second job exempts `typescript@*` and `@typescript/*` (its platform packages, published at the same time) and installs it. |
| [3. Block list](.github/workflows/block-list.yml) | `block-list: ["ms@2.1.3"]` | `npm ci` fails with `E403`, because the lockfile pins `ms@2.1.3`. `ms@2.1.2` still installs. |
| [4. Compromised package](.github/workflows/compromised.yml) | `secure-registry: true` | A lockfile that pins a version flagged as compromised fails with `E403`. |
| [5. Audit mode](.github/workflows/audit-mode.yml) | `mode: audit` and the same block list | `npm ci` passes. The job summary lists `ms@2.1.3` under **Would be blocked**. |
| [6. Egress block](.github/workflows/egress-block.yml) | `egress-policy: block` | Installs go through Secure Registry. The public npm registry is not reachable from the job. |
| [7. pnpm](.github/workflows/pnpm.yml) | `secure-registry: true` | `pnpm install --frozen-lockfile` downloads every package through Secure Registry. `pnpm/action-setup` installs pnpm through Secure Registry too, so a pnpm release newer than the cooldown can be listed under **Held**. That is expected. |

The compromised package example uses `@harden-runner-canary/basic-npm-package@1.5.0`, a StepSecurity test package that is flagged on purpose. It is harmless: it has no install scripts.

## Where to see the results

### Harden-Runner step log

The first step of the job prints the settings that were applied, and a notice for anything that was ignored or adjusted:

```
secure-registry session
  edition: community
  ...
secure-registry: npm installs now go through https://<secure-registry-host>/javascript/
```

### npm output

When Secure Registry hides versions of a package, npm prints a notice that says which versions and why:

```
npm notice StepSecurity: 1 version(s) of @harden-runner-canary/basic-npm-package are hidden by your registry policy. compromised: 1.5.0. They may still be listed on the public registry.
```

A download that Secure Registry refuses fails with `E403` and the reason:

```
npm error 403 403 Forbidden - GET https://<secure-registry-host>/javascript/... - '<package>@<version>' is blocked by security policy with StepSecurity: ...
```

### Job summary

When anything was held, blocked or would have been blocked, the job summary has a **Secure registry** section:

* **Blocked:** downloads that were refused, with the control and the reason.
* **Held:** versions hidden from npm, with the reason (cooldown, block list or compromised).
* **Would be blocked:** in audit mode, what enforce mode would have refused.
* A `secure-registry` snippet you can paste into your workflow to exempt the held versions.

Each table shows up to 5 rows, with a link to the full list in run insights.

The summary is written when the job ends. Requests from the last few seconds of the job may not be in it yet. Run insights has the complete list.

### Run insights

Every run of a job with Harden-Runner has insights in the StepSecurity dashboard at:

```
https://app.stepsecurity.io/github/<owner>/<repo>/actions/runs/<run-id>
```

The **Packages** tab lists each package and version the job pulled through Secure Registry, with the decision for each. The **Network events** tab shows the Secure Registry host. It can also show `registry.npmjs.org`, which is expected in some cases. With `egress-policy: block`, calls to `registry.npmjs.org` show as blocked. See [Calls to the public registry](#calls-to-the-public-registry).

## Configuration

`secure-registry` takes `true`, `false`, or a YAML block. Anything you leave out uses the default.

```yaml
- uses: step-security/harden-runner@v2
  with:
    egress-policy: audit
    secure-registry: |
      ecosystem-defaults:   # every supported ecosystem
        mode: enforce
      npm:                  # npm only, overrides ecosystem-defaults
        cooldown:
          days: 5
          exemptions:
            - "@example-org/*"
            - "left-pad@1.3.0"
        block-list:
          - "example-pkg@1.0.4"
```

| Setting | Default | Values |
| --- | --- | --- |
| `mode` | `enforce` | `enforce` refuses held and blocked versions. `audit` reports blocked versions without refusing them. Cooldown holds are not reported in audit mode yet. `off` leaves the ecosystem on its normal registry. |
| `cooldown.days` | `2` | `0` to `30`. `0` turns the cooldown off. |
| `cooldown.exemptions` | none | `name@version` for one release, `name@*` for every version of a package, `@scope/*` for a scope. |
| `block-list` | off | Glob patterns such as `name@1.2.3`, `name@1*`, `name@*` or `@scope/*`. |
| Compromised packages | on | Always on. Cannot be turned off or exempted. |
| Typosquatting protection | off | Not available for public repositories. |
| `ecosystems` (top level) | `all` | `all` covers every supported ecosystem, including ones added later. A list such as `[npm]` covers only those. |
| `lockfile-resolved` (under `npm`) | `keep` | `omit` stops npm writing registry URLs into `package-lock.json`. See [Lockfiles written in CI](#lockfiles-written-in-ci). |

Unknown keys and invalid values never fail a job. Harden-Runner prints a notice that starts with `secure-registry:` and uses the default.

### Common setups

Try it without breaking builds. The job summary lists what the block list and the compromised check would have refused. Cooldown holds are not reported in audit mode yet.

```yaml
    secure-registry: |
      ecosystem-defaults:
        mode: audit
```

Wait longer for new versions in a release pipeline:

```yaml
    secure-registry: |
      npm:
        cooldown:
          days: 7
```

Let your own packages through the cooldown:

```yaml
    secure-registry: |
      npm:
        cooldown:
          exemptions:
            - "@example-org/*"
```

Turn it off in a publish job (`npm publish` does not work through Secure Registry):

```yaml
    secure-registry: |
      npm:
        mode: off
```

## Things to know

### Dependency caches

Packages restored from a cache are not downloaded, so Secure Registry never sees them: they are not checked, and they do not appear in the job summary or run insights. A cache saved before you turned Secure Registry on can install a version that Secure Registry would refuse today.

* Turn off the package manager cache (`package-manager-cache: false` on `actions/setup-node`, no `cache:` on `pnpm/action-setup`), or
* delete existing caches after turning Secure Registry on (`gh cache delete --all`), and keep the lockfile hash in the cache key.

### Package managers

| Package manager | Covered |
| --- | --- |
| npm (`npm ci`, `npm install`, `npx`) | Yes |
| pnpm with `pnpm-lock.yaml` | Yes |
| pnpm without a lockfile, Yarn 1 without a lockfile | Version selection only. Downloads go to the public registry. |
| Yarn 1 with `yarn.lock`, Yarn 2 and later, Deno | No |
| Bun 1.4.4 and later, with `bun.lock` | Yes |

### Calls to the public registry

Network events can still show `registry.npmjs.org` or `registry.yarnpkg.com`. This is expected when:

* Corepack downloads the package manager named in `packageManager` (pnpm or Yarn) itself,
* a package manager that is not fully covered downloads packages (see the table above),
* `actions/setup-node` with `registry-url: https://registry.npmjs.org` replaces the npm configuration. Harden-Runner adds an annotation when this happens.

The [2. Cooldown and exemptions](.github/workflows/cooldown.yml) workflow also calls the public registry on purpose, to look up the latest nightly TypeScript version.

### Setups that keep their own registry

A project `.npmrc` with `registry=`, `NPM_CONFIG_REGISTRY` in the environment, or a private mirror in the user `.npmrc` keeps that registry. Secure Registry does not check those installs.

### Lockfiles written in CI

A lockfile that npm writes during the job can contain Secure Registry URLs. Do not commit it from CI: installs that do not use the job's credentials fail with `E401`. If a job has to commit lockfiles, set `lockfile-resolved: omit` under `npm`.

## Troubleshooting

| What you see | Why | What to do |
| --- | --- | --- |
| `ETARGET No matching version found`, with a `hidden by your registry policy` notice | The version is held by the cooldown, blocked, or compromised. The notice says which. | Wait for the cooldown, pick an older version, or add a cooldown exemption. Compromised versions cannot be exempted: upgrade or downgrade. |
| `E403 ... is blocked by security policy with StepSecurity` | A lockfile pins a version that is held, blocked or compromised. | Update the lockfile to another version, or add an exemption for a held version. The job summary has a snippet. |
| `E404` for a private package on npmjs.com | npmjs credentials are not sent to Secure Registry. | Set `mode: off` for npm in that job. |
| `E401` on `npm publish` | Publishing does not go through Secure Registry. | Set `mode: off` for npm in the publish job. |
| A notice at job start, and nothing is checked | The job is not eligible (for example, a private repository or a self-hosted runner). | Nothing to fix. npm uses its normal registry. |
| Nothing in the job summary, but packages were installed | Nothing was held or blocked, or the packages came from a cache. | Check the **Packages** tab in run insights. |

## Run it yourself

Fork this repository, enable Actions on the fork, and run any workflow from the **Actions** tab. The fork must stay public.

## License

[Apache-2.0](LICENSE)
