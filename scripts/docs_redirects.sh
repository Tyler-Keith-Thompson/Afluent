#!/usr/bin/env bash
# scripts/docs_redirects.sh <site> <Module>...
#
# Each module's documentation was once published as a site of its own, at
# /Afluent/<Module>/documentation/<module>/; the combined site (//:docs) has every module at
# /Afluent/documentation/<module>/. For every page of each module in <site>, this writes a page
# at its old address that redirects to the new one, and one at /Afluent/<Module>/ for the module.
set -euo pipefail

site="$1"
shift
base=/Afluent

redirect() {  # redirect <file> <target URL>
    mkdir -p "$(dirname "$1")"
    printf '<!doctype html>\n<meta charset="utf-8">\n<title>Moved</title>\n<link rel="canonical" href="%s">\n<meta http-equiv="refresh" content="0; url=%s">\n<a href="%s">This page has moved.</a>\n' \
        "$2" "$2" "$2" > "$1"
}

cd "$site"
for module in "$@"; do
    lower="$(printf '%s' "$module" | tr '[:upper:]' '[:lower:]')"
    if [ ! -d "documentation/$lower" ]; then
        echo "No documentation/$lower in $site" >&2
        exit 1
    fi
    redirect "$module/index.html" "$base/documentation/$lower/"
    find "documentation/$lower" -name index.html | while IFS= read -r page; do
        path="${page%index.html}"
        redirect "$module/${path}index.html" "$base/$path"
    done
done
