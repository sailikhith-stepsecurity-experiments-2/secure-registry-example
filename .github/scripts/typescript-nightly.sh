#!/usr/bin/env bash
# Looks up the latest nightly TypeScript version (the "next" dist-tag) and how
# many days ago it was built. Asks the public registry, because Secure Registry
# hides versions that are newer than the cooldown.
#
# Outputs: version, age-days
set -euo pipefail

version=$(curl -fsS https://registry.npmjs.org/-/package/typescript/dist-tags | jq -er .next)

# Nightly versions carry their build date, for example 7.1.0-dev.20261111.1.
built=$(echo "$version" | sed -nE 's/.*-dev\.([0-9]{8}).*/\1/p')
if [ -z "$built" ]; then
  echo "::error title=Unexpected version::typescript@next is $version, which has no build date."
  exit 1
fi
age_days=$(( ($(date -u +%s) - $(date -u -d "$built" +%s)) / 86400 ))

echo "typescript@next is $version, built on $built, about $age_days day(s) ago"
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "age-days=$age_days" >> "$GITHUB_OUTPUT"
