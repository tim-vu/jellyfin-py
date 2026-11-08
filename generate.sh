#!/usr/bin/env bash
# Regenerate the Jellyfin OpenAPI client in this repository.
#
# Inputs come from versions.env (generator version, spec URL, spec hash). The
# package version comes from .release-please-manifest.json so regenerating
# never clobbers a version bump made by release-please. Requires a JRE, curl,
# jq and network access.
#
# The API classes are rendered with the override in ./templates instead of the
# generator's stock template, to carry the fix for openapi-generator bug #16071
# (enum path/query params crash with "'str' object has no attribute 'value'").
# See templates/api.mustache for the details; drop the override once a released
# generator includes the upstream fix (PR #25540).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# shellcheck source=versions.env
source "$here/versions.env"
package_version="$(jq -r '.["."]' "$here/.release-please-manifest.json")"

jar_url="https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${GENERATOR_VERSION}/openapi-generator-cli-${GENERATOR_VERSION}.jar"
curl -sSfL -o "$tmp/oag.jar" "$jar_url"
curl -sSfL -o "$tmp/spec.json" "$SPEC_URL"
echo "${SPEC_SHA256}  $tmp/spec.json" | sha256sum -c -

java -jar "$tmp/oag.jar" generate \
  -i "$tmp/spec.json" \
  -g python \
  -o "$tmp/out" \
  -t "$here/templates" \
  --git-user-id=tim-vu \
  --git-repo-id=jellyfin-py \
  --additional-properties="packageName=jellyfin,projectName=jellyfin-py,packageVersion=${package_version},library=urllib3,packageUrl=https://github.com/tim-vu/jellyfin-py" \
  --global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false

# Generated CI and publishing scaffolding is replaced by our own workflows.
rm -rf "$tmp/out/.github" "$tmp/out/.travis.yml" "$tmp/out/.gitlab-ci.yml" "$tmp/out/git_push.sh"

# Let release-please bump the version on the lines that carry it.
"$here/scripts/mark-version.sh" "$tmp/out" "$package_version"

# Replace the generated client. Only top-level entries the generator produced
# are removed, so files we own (workflows, scripts, release config) survive.
for generated in "$tmp"/out/* "$tmp"/out/.[!.]*; do
  rm -rf "${here:?}/$(basename "$generated")"
done
cp -a "$tmp/out/." "$here/"

echo "Regenerated Jellyfin client ${package_version} (spec ${SPEC_VERSION}) in $here"
