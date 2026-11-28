#!/usr/bin/env bash
# Generate an Xcode project from the Bazel graph, via rules_xcodeproj.
#
# Usage:
#   ./scripts/generate-xcodeproj.sh             # generate and open
#   ./scripts/generate-xcodeproj.sh --no-open   # generate only
set -euo pipefail

OPEN=true
for arg in "$@"; do
    case "$arg" in
        --no-open) OPEN=false ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# Out of the root, where xcodebuild without -project would pick it over Package.swift.
PROJECT="xcode/Afluent.xcodeproj"

if [ -e "Afluent.xcodeproj" ]; then
    echo "warning: Afluent.xcodeproj at the root is stale (the project is now ${PROJECT}) and makes xcodebuild ignore Package.swift; delete it." >&2
fi

# rules_xcodeproj's installer fails when the install directory is missing.
mkdir -p xcode

echo "Generating ${PROJECT} from the Bazel graph..."
bazel run //:xcodeproj

# rules_xcodeproj marks generated files read-only, which stops Xcode writing scheme state.
chmod -R u+w "$PROJECT"

if [ "$OPEN" = true ]; then
    echo "Opening ${PROJECT}..."
    open "$PROJECT"
else
    echo "Done. Open ${PROJECT} when you want it."
fi
