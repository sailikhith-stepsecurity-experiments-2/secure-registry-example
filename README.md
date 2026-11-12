# Secure Registry example

This repository shows how to use [Harden-Runner](https://github.com/step-security/harden-runner) Secure Registry in a public repository, and where to see what it did.

With Secure Registry turned on, package installs in a job go through StepSecurity Secure Registry instead of directly to the public registry. Secure Registry:

* refuses versions that StepSecurity has flagged as **compromised**,
* holds back versions published less than **2 days** ago (the **cooldown**), and
* refuses versions on your **block list**, if you set one.

It is free for public repositories on GitHub-hosted runners.

Full documentation: [docs.stepsecurity.io](https://docs.stepsecurity.io)

## Supported ecosystems

| Ecosystem | Status | Examples |
| --- | --- | --- |
| npm (npm, pnpm, and other npm-compatible clients) | Available | [npm](npm/README.md) |
| Other ecosystems | Planned | |

`secure-registry: true` covers every supported ecosystem, including ones added later. You do not need to change your workflow when a new ecosystem is supported.

## Turn it on

Add `secure-registry: true` to Harden-Runner, and keep Harden-Runner as the first step of the job:

```yaml
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

      # ... the rest of your job, unchanged
```

* **`id-token: write`** lets GitHub sign a statement of which repository the job belongs to. It is optional: without it, Secure Registry still protects the job, and packages appear in run insights when Harden-Runner telemetry is reachable.
* **Turn off dependency caching**, or clear existing caches. Packages restored from a cache are never downloaded, so Secure Registry never checks them. See [Dependency caches](#dependency-caches).

Each ecosystem's page has a complete workflow, for example [npm](npm/README.md#quick-start).

## Configuration

`secure-registry` takes `true`, `false`, or a YAML block. Anything you leave out uses the default.

```yaml
- uses: step-security/harden-runner@v2
  with:
    egress-policy: audit
    secure-registry: |
      ecosystems: all       # or a list such as [npm]
      ecosystem-defaults:   # every covered ecosystem
        mode: enforce
        cooldown:
          days: 2
      npm:                  # one ecosystem, overrides ecosystem-defaults
        cooldown:
          days: 5
          exemptions:
            - "@example-org/*"
        block-list:
          - "example-pkg@1.0.4"
```

* **`ecosystem-defaults`** applies to every covered ecosystem, including ones added later.
* **A block named after an ecosystem** (`npm`) overrides `ecosystem-defaults` for that ecosystem only. Package names and patterns in it use that ecosystem's naming.
* **`ecosystems`** says which ecosystems are covered: `all` (the default) or a list. Ecosystems that are not listed keep their normal registry.

| Setting | Default | Values |
| --- | --- | --- |
| `mode` | `enforce` | `enforce` refuses held and blocked versions. `audit` reports blocked versions without refusing them. Cooldown holds are not reported in audit mode yet. `off` leaves the ecosystem on its normal registry. |
| `cooldown.days` | `2` | `0` to `30`. `0` turns the cooldown off. |
| `cooldown.exemptions` | none | `name@version` for one release, `name@*` for every version of a package, `@scope/*` for a scope. Exempted versions are still checked for compromise. |
| `block-list` | off | Glob patterns such as `name@1.2.3`, `name@1*`, `name@*` or `@scope/*`. |
| Compromised packages | on | Always on. Cannot be turned off or exempted. |

Some settings exist for one ecosystem only. See that ecosystem's page.

Unknown keys and invalid values never fail a job. Harden-Runner prints a notice that starts with `secure-registry:` and uses the default.

### Common setups

Try it without breaking builds, in every ecosystem:

```yaml
    secure-registry: |
      ecosystem-defaults:
        mode: audit
```

Wait longer for new versions in a release pipeline, in every ecosystem:

```yaml
    secure-registry: |
      ecosystem-defaults:
        cooldown:
          days: 7
```

Let your own packages through the cooldown, in one ecosystem:

```yaml
    secure-registry: |
      npm:
        cooldown:
          exemptions:
            - "@example-org/*"
```

Turn one ecosystem off in a job, for example a publish job:

```yaml
    secure-registry: |
      npm:
        mode: off
```

## Where to see the results

### Harden-Runner step log

The first step of the job prints the settings that were applied, a line for each ecosystem it configured, and a notice for anything that was ignored or adjusted:

```
secure-registry session
  edition: community
  ...
secure-registry: npm installs now go through https://<secure-registry-host>/javascript/
```

### Package manager output

When a version is held or blocked, the package manager's own output says so. Each ecosystem's page shows what to look for.

### Job summary

When anything was held, blocked or would have been blocked, the job summary has a **Secure registry** section:

* **Blocked:** downloads that were refused, with the control and the reason.
* **Held:** versions hidden from the package manager, with the reason (cooldown, block list or compromised).
* **Would be blocked:** in audit mode, what enforce mode would have refused.
* A `secure-registry` snippet you can paste into your workflow to exempt the held versions.

Each table shows up to 5 rows, with a link to the full list in run insights.

The summary is written when the job ends. Requests from the last few seconds of the job may not be in it yet. Run insights has the complete list.

### Run insights

Every run of a job with Harden-Runner has insights in the StepSecurity dashboard at:

```
https://app.stepsecurity.io/github/<owner>/<repo>/actions/runs/<run-id>
```

The **Packages** tab lists each package and version the job pulled through Secure Registry, with the decision for each. The **Network events** tab shows the Secure Registry host. It can also show the public registry, which is expected in some cases that each ecosystem's page lists. With `egress-policy: block`, calls to the public registry show as blocked.

## Dependency caches

Packages restored from a cache are not downloaded, so Secure Registry never sees them: they are not checked, and they do not appear in the job summary or run insights. A cache saved before you turned Secure Registry on can install a version that Secure Registry would refuse today.

* Turn off dependency caching in the setup action, or
* delete existing caches after turning Secure Registry on (`gh cache delete --all`), and keep the lockfile hash in the cache key.

## Repository layout

```
<ecosystem>/                          example projects and README for one ecosystem
.github/workflows/<ecosystem>-*.yml   one workflow per scenario
.github/scripts/                      helpers shared by every ecosystem
.github/scripts/<ecosystem>/          helpers for one ecosystem
```

Every ecosystem has the same scenarios: quick start, cooldown and exemptions, block list, compromised package, audit mode and egress block. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to add an ecosystem.

## Run it yourself

Fork this repository, enable Actions on the fork, and run any workflow from the **Actions** tab. The fork must stay public.

## License

[Apache-2.0](LICENSE)
