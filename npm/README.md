# npm

Secure Registry covers npm and package managers that read npm configuration, such as pnpm. Harden-Runner points them at Secure Registry for the rest of the job. Nothing else in the workflow changes.

## Quick start

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

`package-manager-cache: false` matters: `actions/setup-node` turns caching on by itself when `package.json` names npm in `packageManager`, and a restored cache is never checked.

## Examples

| Workflow | Settings | What happens |
| --- | --- | --- |
| [npm: 1. Quick start](../.github/workflows/npm-quick-start.yml) | `secure-registry: true` | `npm ci` and `npm test` pass in [`app`](app). All 65 packages in the lockfile go through Secure Registry. |
| [npm: 2. Cooldown and exemptions](../.github/workflows/npm-cooldown.yml) | default cooldown, then `cooldown.exemptions` | The latest nightly TypeScript build is usually less than a day old. The first job cannot install it. The second job exempts `typescript@*` and `@typescript/*` (its platform packages, published at the same time) and installs it. |
| [npm: 3. Block list](../.github/workflows/npm-block-list.yml) | `block-list: ["ms@2.1.3"]` | `npm ci` fails with `E403`, because the lockfile pins `ms@2.1.3`. `ms@2.1.2` still installs. |
| [npm: 4. Compromised package](../.github/workflows/npm-compromised.yml) | `secure-registry: true` | [`compromised`](compromised) pins a version flagged as compromised, and `npm ci` fails with `E403`. |
| [npm: 5. Audit mode](../.github/workflows/npm-audit-mode.yml) | `mode: audit` and the same block list | `npm ci` passes. The job summary lists `ms@2.1.3` as would be blocked. |
| [npm: 6. Egress block](../.github/workflows/npm-egress-block.yml) | `egress-policy: block` | Installs go through Secure Registry. The public npm registry is not reachable from the job. |
| [npm: 7. pnpm](../.github/workflows/npm-pnpm.yml) | `secure-registry: true` | `pnpm install --frozen-lockfile` in [`pnpm`](pnpm) downloads every package through Secure Registry. `pnpm/action-setup` installs pnpm through Secure Registry too, so a pnpm release newer than the cooldown can be listed under **Held**. That is expected. |

The workflows run on every push to `main` (the quick start also runs on pull requests) and can be run by hand from the **Actions** tab. Steps that are expected to be refused check for the refusal, and each scenario first checks that npm uses Secure Registry. Your own workflows do not need these checks.

The compromised package example uses `@harden-runner-canary/basic-npm-package@1.5.0`, a StepSecurity test package that is flagged on purpose. It is harmless: it has no install scripts.

## What npm prints

When Secure Registry hides versions of a package, npm prints a notice that says which versions and why. Installing a hidden version by name then fails with `ETARGET`:

```
npm notice StepSecurity: 1 version(s) of ms are hidden by your registry policy. block list: 2.1.3. They may still be listed on the public registry.
npm error code ETARGET
```

When a lockfile pins a refused version, the download fails with `E403` and the reason:

```
npm error code E403
npm error 403 403 Forbidden - GET https://<secure-registry-host>/javascript/ms/-/ms-2.1.3.tgz - 'ms@2.1.3' is blocked by security policy with StepSecurity: 'ms' matches a configured block list pattern
```

## npm settings

| Setting | Default | Values |
| --- | --- | --- |
| `lockfile-resolved` | `keep` | `omit` stops npm writing registry URLs into `package-lock.json`. See [Lockfiles written in CI](#lockfiles-written-in-ci). |

Turn npm off in a publish job, because `npm publish` does not work through Secure Registry:

```yaml
    secure-registry: |
      npm:
        mode: off
```

## Package managers

| Package manager | Covered |
| --- | --- |
| npm (`npm ci`, `npm install`, `npx`) | Yes |
| pnpm with `pnpm-lock.yaml` | Yes |
| pnpm without a lockfile, Yarn 1 without a lockfile | Version selection only. Downloads go to the public registry. |
| Yarn 1 with `yarn.lock`, Yarn 2 and later, Deno | No |
| Bun 1.4.4 and later, with `bun.lock` | Yes |

## Calls to the public registry

Network events can still show `registry.npmjs.org` or `registry.yarnpkg.com`. This is expected when:

* Corepack downloads the package manager named in `packageManager` (pnpm or Yarn) itself,
* a package manager that is not fully covered downloads packages (see the table above),
* `actions/setup-node` with `registry-url: https://registry.npmjs.org` replaces the npm configuration. Harden-Runner adds an annotation when this happens.

The [npm: 2. Cooldown and exemptions](../.github/workflows/npm-cooldown.yml) workflow also calls the public registry on purpose, to look up the latest nightly TypeScript version.

## Setups that keep their own registry

A project `.npmrc` with `registry=`, `NPM_CONFIG_REGISTRY` in the environment, or a private mirror in the user `.npmrc` keeps that registry. Secure Registry does not check those installs.

## Lockfiles written in CI

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
