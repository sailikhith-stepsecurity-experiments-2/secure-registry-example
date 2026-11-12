#!/usr/bin/env bash
# Runs a command that Secure Registry is expected to refuse.
#
#   expect-refused.sh <pattern> <command...>
#
# Passes when the command fails and its output matches <pattern> (an extended
# regular expression). Fails the step when the command succeeds, because that
# means the package was not refused.
set -uo pipefail

pattern=$1
shift

log=$(mktemp)
"$@" >"$log" 2>&1
status=$?
cat "$log"

if [ "$status" -eq 0 ]; then
  echo "::error title=Not refused::'$*' succeeded, but it was expected to be refused."
  exit 1
fi
if ! grep -Eq "$pattern" "$log"; then
  echo "::error title=Unexpected error::'$*' failed, but its output does not match '$pattern'."
  exit 1
fi
echo "::notice title=Refused as expected::$*"
