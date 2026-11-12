#!/usr/bin/env bash
# Fails the step when a package manager still uses its public registry, so an
# example cannot pass while Secure Registry is off.
#
#   require-secure-registry.sh <package-manager>
#
# Not needed in your own workflows: Harden-Runner prints the registry it
# configured in its step log.
#
# To add an ecosystem, add a case below that reads the registry the package
# manager will use, and the public registry it would use otherwise.
set -euo pipefail

tool=${1:?usage: require-secure-registry.sh <package-manager>}

case "$tool" in
  npm | pnpm)
    registry=$("$tool" config get registry)
    public_registry=https://registry.npmjs.org
    ;;
  *)
    echo "::error title=Unknown package manager::require-secure-registry.sh has no check for '$tool'. Add one."
    exit 1
    ;;
esac

echo "$tool registry: $registry"

if [ -z "$registry" ] || [ "${registry%/}" = "$public_registry" ]; then
  echo "::error title=Secure Registry is off::$tool uses ${registry:-its default registry}. Check the Harden-Runner step log for a secure-registry notice."
  exit 1
fi
