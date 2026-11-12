# Contributing

## Adding an ecosystem

When Secure Registry supports a new ecosystem, add it next to npm. Use [`npm`](npm) as the template. In the steps below, `<ecosystem>` is the key used in the `secure-registry` input (for example `npm`).

### 1. Example projects

Create `<ecosystem>/` with:

* `app/`: a small project with a few real dependencies, a lockfile and a test. Generate the lockfile from the public registry, with versions published more than 7 days ago, so that no cooldown setting in the examples holds them.
* `compromised/`: a lockfile that pins a version StepSecurity flags as compromised on purpose (a StepSecurity canary package with no install scripts).
* One folder per extra package manager that is covered, like `npm/pnpm`.

### 2. Workflows

Add one workflow per scenario in `.github/workflows/`, named `<ecosystem>-<scenario>.yml`, with `name: "<ecosystem>: N. <Scenario>"`:

| File | Shows |
| --- | --- |
| `<ecosystem>-quick-start.yml` | `secure-registry: true`, install and test |
| `<ecosystem>-cooldown.yml` | a version newer than the cooldown is held, then installed with an exemption |
| `<ecosystem>-block-list.yml` | a version pinned in the lockfile is refused, other versions install |
| `<ecosystem>-compromised.yml` | the compromised canary is refused |
| `<ecosystem>-audit-mode.yml` | the same block list in audit mode: install passes, the summary lists it |
| `<ecosystem>-egress-block.yml` | `egress-policy: block` without the public registry in `allowed-endpoints` |

Every workflow follows these rules:

* Harden-Runner is the first step, with `secure-registry`.
* Settings for one ecosystem go under the `<ecosystem>:` key. Settings for every ecosystem go under `ecosystem-defaults:`.
* `permissions: contents: read` at the top, `id-token: write` on the job, `persist-credentials: false` on checkout, and `timeout-minutes` on every job.
* Actions are pinned to a full commit SHA, with the version in a comment.
* No dependency caching.
* Each scenario checks that the package manager uses Secure Registry with `.github/scripts/require-secure-registry.sh <package-manager>`, before the first install.
* A step that is expected to be refused runs through `.github/scripts/expect-refused.sh "<pattern>" <command>`, with a pattern taken from a real run.

### 3. Scripts

* Add the package manager to `.github/scripts/require-secure-registry.sh`: how to read the registry it will use, and its public registry.
* Put helpers for one ecosystem in `.github/scripts/<ecosystem>/`.

### 4. Documentation

* Add `<ecosystem>/README.md` with the same sections as [`npm/README.md`](npm/README.md): quick start, examples, what the package manager prints, settings for this ecosystem, package managers, calls to the public registry, and troubleshooting.
* Add the ecosystem to **Supported ecosystems** in [README.md](README.md).

### 5. Check

Run every new workflow and confirm each one passes for the right reason: the refusals in the logs, and the **Secure registry** section of the job summary.
