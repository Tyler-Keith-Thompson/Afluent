"""Checks the published Package.swift against the Bazel graph.

scripts/modules.py writes Package.swift and every BUILD.bazel from one table, but nothing stops a
commit from carrying a regenerated BUILD.bazel without the matching Package.swift. Bazel is what
CI builds, so a stale manifest would pass unnoticed and only SwiftPM users would see the gap.

`swiftpm_manifest_test` reads each first-party Swift module and its direct dependencies off the
analyzed graph (through an aspect, so nothing is compiled), writes them as one line per module,
and compares that with the same lines pulled out of Package.swift's `.target`, `.executableTarget`
and `.testTarget` entries. A missing target, an extra one or a different dependency list fails the
test.
"""

_ModuleDependencies = provider(
    doc = "A Swift module's name and the modules it depends on directly, for the manifest check.",
    fields = {
        "name": "The module name, or for an external package's product, `identity/Product`.",
        "lines": "depset of `Module: Dependency Dependency` lines, one per first-party module.",
    },
)

def _external_name(label):
    # rules_swift_package_manager names a package's repository `swiftpkg_<identity>`, with the
    # identity's hyphens as underscores; the canonical name carries the extension's prefix.
    repository = label.repo_name.split("+")[-1].removeprefix("swiftpkg_").replace("_", "-")
    return repository + "/" + label.name

def _module_dependencies_aspect_impl(target, ctx):
    if target.label.repo_name:
        return [_ModuleDependencies(name = _external_name(target.label), lines = depset())]
    deps = [dep for dep in getattr(ctx.rule.attr, "deps", []) if _ModuleDependencies in dep]
    name = getattr(ctx.rule.attr, "module_name", None) or target.label.name
    names = sorted({dep[_ModuleDependencies].name: None for dep in deps}.keys())
    line = name + ":" + "".join([" " + dependency for dependency in names])
    return [_ModuleDependencies(
        name = name,
        lines = depset([line], transitive = [dep[_ModuleDependencies].lines for dep in deps]),
    )]

_module_dependencies_aspect = aspect(
    implementation = _module_dependencies_aspect_impl,
    attr_aspects = ["deps"],
)

# Pulls one `Module: Dependency ...` line out of every `.target(name:`, `.executableTarget(name:`
# and `.testTarget(name:` entry, writing a product dependency as `identity/Product`, as the aspect does.
# A product linked on Apple platforms only (`condition: .when(platforms: applePlatforms)`,
# APPLE_ONLY_PACKAGES in scripts/modules.py) is in Bazel's graph on macOS alone, so it is left out
# of both sides.
_SCRIPT = """#!/bin/sh
set -eu
manifest="$1"
expected="$2"
actual="${TEST_TMPDIR:-/tmp}/actual.txt"
bazel="${TEST_TMPDIR:-/tmp}/bazel.txt"
conditional=$(grep -oE '\\.product\\(name: "[^"]*", package: "[^"]*", condition:' "$manifest" \\
    | sed -E 's/.*name: "([^"]*)", package: "([^"]*)".*/\\2\\/\\1/' | LC_ALL=C sort -u | tr '\\n' ' ')
awk -v drop="$conditional" 'BEGIN { split(drop, names, " "); for (i in names) skip[names[i]] = 1 }
    { out = $1; for (i = 2; i <= NF; i++) if (!($i in skip)) out = out " " $i; print out }' "$expected" > "$bazel"
grep -E '^ *\\.(target|executableTarget|testTarget)\\(name: "' "$manifest" | while IFS= read -r line; do
    name="${line#*name: \\"}"
    name="${name%%\\"*}"
    deps=""
    case "$line" in
        *"dependencies: ["*)
            deps="${line#*dependencies: [}"
            deps="${deps%%]*}"
            ;;
    esac
    deps=$(printf '%s\\n' "$deps" \\
        | sed -E 's/\\.product\\(name: "[^"]*", package: "[^"]*", condition: [^)]*\\)\\)//g' \\
        | sed -E 's/\\.product\\(name: "([^"]*)", package: "([^"]*)"\\)/"\\2\\/\\1"/g' \\
        | tr ',' '\\n' \\
        | sed -nE 's/^ *"([^"]*)" *$/\\1/p' \\
        | LC_ALL=C sort -u \\
        | awk '{ printf " %s", $0 }')
    printf '%s:%s\\n' "$name" "$deps"
done | LC_ALL=C sort > "$actual"
if ! diff -u "$bazel" "$actual"; then
    echo
    echo "Package.swift disagrees with the Bazel graph (- Bazel, + Package.swift)."
    echo "Run \\`just modules\\` and commit Package.swift together with the BUILD.bazel files."
    exit 1
fi
"""

def _swiftpm_manifest_test_impl(ctx):
    lines = depset(transitive = [module[_ModuleDependencies].lines for module in ctx.attr.modules])
    expected = ctx.actions.declare_file(ctx.label.name + ".expected.txt")
    ctx.actions.write(expected, "\n".join(sorted(lines.to_list())) + "\n")
    checker = ctx.actions.declare_file(ctx.label.name + ".check.sh")
    ctx.actions.write(checker, _SCRIPT, is_executable = True)
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        runner,
        '#!/bin/sh\nexec "{}" "{}" "{}"\n'.format(checker.short_path, ctx.file.manifest.short_path, expected.short_path),
        is_executable = True,
    )
    return [DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(files = [checker, expected, ctx.file.manifest]),
    )]

swiftpm_manifest_test = rule(
    implementation = _swiftpm_manifest_test_impl,
    doc = "Fails when Package.swift's targets and dependencies differ from the Bazel graph's.",
    attrs = {
        "manifest": attr.label(allow_single_file = True, mandatory = True),
        "modules": attr.label_list(aspects = [_module_dependencies_aspect], mandatory = True),
    },
    test = True,
)
