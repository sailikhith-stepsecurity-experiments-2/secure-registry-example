#!/usr/bin/env bash
# Fails the step when npm (or the package manager named in $1) still uses the
# public npm registry, so an example cannot pass while Secure Registry is off.
#
#   require-secure-registry.sh [npm|pnpm]
#
# Not needed in your own workflows: Harden-Runner prints the registry in its
# step log.
set -euo pipefail

tool=${1:-npm}
registry=$("$tool" config get registry)
echo "$tool registry: $registry"

case "$registry" in
  https://registry.npmjs.org | https://registry.npmjs.org/ | "")
    echo "::error title=Secure Registry is off::$tool uses $registry. Check the Harden-Runner step log for a secure-registry notice."
    exit 1
    ;;
esac
