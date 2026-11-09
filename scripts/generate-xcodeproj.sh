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

PROJECT="Afluent.xcodeproj"

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
