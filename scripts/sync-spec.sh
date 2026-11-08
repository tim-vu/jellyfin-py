#!/usr/bin/env bash
# Check whether the published Jellyfin OpenAPI spec differs from the pinned one
# and, if so, rewrite SPEC_SHA256 and SPEC_VERSION in versions.env.
#
# Prints key=value lines (also appended to $GITHUB_OUTPUT when set):
#   changed=true|false           spec content differs from the pin
#   version_changed=true|false   info.version differs from the pin
#   spec_version=<info.version>
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# shellcheck source=../versions.env
source "$here/versions.env"

curl -sSfL -o "$tmp/spec.json" "$SPEC_URL"
new_sha256="$(sha256sum "$tmp/spec.json" | cut -d' ' -f1)"
new_version="$(jq -er '.info.version' "$tmp/spec.json")"

changed=false
version_changed=false

if [ "$new_sha256" != "$SPEC_SHA256" ]; then
  changed=true
  sed -i -E \
    -e "s|^SPEC_SHA256=.*|SPEC_SHA256=${new_sha256}|" \
    -e "s|^SPEC_VERSION=.*|SPEC_VERSION=${new_version}|" \
    "$here/versions.env"
fi

if [ "$new_version" != "$SPEC_VERSION" ]; then
  version_changed=true
fi

output="changed=${changed}
version_changed=${version_changed}
spec_version=${new_version}"

echo "$output"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "$output" >> "$GITHUB_OUTPUT"
fi
