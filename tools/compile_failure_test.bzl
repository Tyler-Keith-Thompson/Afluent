"""A test that a Swift source fails to compile, with the errors it must report.

`swift_compile_failure_test` type-checks `src` against the modules of `deps` (their swiftmodules and
clang module maps, from SwiftInfo) and, given `plugin`, with that compiler plugin loaded. It passes
when the compiler fails and its output holds every string in `expected_errors`; it fails when the
source compiles, or the output lacks one, and prints the output. Checking the text, not just the
failure, keeps a fixture that fails for another reason (a missing module, a typo) from passing.
With no `expected_errors` it passes only when the source compiles: a control, which shows that
the search paths and the plugin work.

Fixtures and their tests live in `Tests/CompileFailures` (hand-written BUILD.bazel), which the root
BUILD.bazel leaves out of the test bundles by name and no Package.swift target holds:

    swift_compile_failure_test(
        name = "NonCodableProperty",
        size = "small",
        src = "NonCodableProperty.swift",
        expected_errors = ["error: ..."],
        plugin = "//Sources/<Plugin>",
        plugin_module_name = "<Plugin>",
        tags = ["debug-only"],
        deps = ["//Sources/<Module>"],
    )

The compiler is the host's: `xcrun swiftc` on macOS (the Xcode that xcode-select names, which builds
the deps too), `swiftc` on the PATH elsewhere, as in CI's image. It is a test rather than a build
action because a build action that must fail can't be cached as an output.
"""

load("@rules_swift//swift:providers.bzl", "SwiftInfo")

_SCRIPT = """#!/bin/sh
set -u
if command -v xcrun >/dev/null 2>&1; then
    swiftc="xcrun swiftc"
else
    swiftc="swiftc"
fi
cache="${TEST_TMPDIR:-/tmp}/module-cache"
# -disable-sandbox: on macOS the compiler runs a plugin in a sandbox of its own, which can't start
# inside Bazel's.
output="$($swiftc -typecheck -swift-version 6 -disable-sandbox -module-cache-path "$cache" %s "%s" 2>&1)"
status=$?
if [ -z "$(printf '%%s' '%s' | tr -d '[:space:]')" ]; then
    [ "$status" -eq 0 ] && exit 0
    echo "%s must compile, but:"
    echo "$output"
    exit 1
fi
if [ "$status" -eq 0 ]; then
    echo "%s compiled, but it must fail to."
    exit 1
fi
missing=0
while IFS= read -r expected; do
    [ -n "$expected" ] || continue
    case "$output" in
        *"$expected"*) ;;
        *) echo "The compiler's output lacks: $expected"; missing=1 ;;
    esac
done <<'EXPECTED'
%s
EXPECTED
if [ "$missing" -ne 0 ]; then
    echo
    echo "$output"
    exit 1
fi
"""

def _quote(text):
    return "'" + text.replace("'", "'\\''") + "'"

def _swift_compile_failure_test_impl(ctx):
    modules = depset(transitive = [dep[SwiftInfo].transitive_modules for dep in ctx.attr.deps]).to_list()
    files = []
    transitive_files = []
    arguments = []
    directories = {}
    for module in modules:
        if module.swift and module.swift.swiftmodule:
            files.append(module.swift.swiftmodule)
            directories[module.swift.swiftmodule.short_path.rpartition("/")[0]] = None
        if module.clang:
            module_map = module.clang.module_map
            if module_map and hasattr(module_map, "short_path"):
                files.append(module_map)
                arguments += ["-Xcc", "-fmodule-map-file=" + module_map.short_path]
            context = module.clang.compilation_context
            if context:
                transitive_files.append(context.headers)
                for include in context.includes.to_list() + context.quote_includes.to_list() + context.system_includes.to_list():
                    # Paths from the execution root, where an external repository's files sit
                    # under external/; the test runs from the main repository's runfiles, beside
                    # the others'.
                    arguments += ["-Xcc", "-I" + ("../" + include.removeprefix("external/") if include.startswith("external/") else include)]
    arguments = ["-I " + _quote(directory) for directory in directories] + [_quote(argument) for argument in arguments]
    if ctx.attr.plugin:
        plugin = ctx.executable.plugin
        files.append(plugin)
        arguments.append("-load-plugin-executable " + _quote(plugin.short_path + "#" + ctx.attr.plugin_module_name))
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        script,
        _SCRIPT % (
            " ".join(arguments),
            ctx.file.src.short_path,
            "".join(ctx.attr.expected_errors).replace("'", ""),
            ctx.file.src.short_path,
            ctx.file.src.short_path,
            "\n".join(ctx.attr.expected_errors),
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = files + [ctx.file.src], transitive_files = depset(transitive = transitive_files))
    if ctx.attr.plugin:
        runfiles = runfiles.merge(ctx.attr.plugin[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = script, runfiles = runfiles)]

swift_compile_failure_test = rule(
    implementation = _swift_compile_failure_test_impl,
    doc = "Passes when `src` fails to type-check against `deps` with every one of `expected_errors`, or compiles when there are none.",
    attrs = {
        "src": attr.label(allow_single_file = [".swift"], mandatory = True),
        "deps": attr.label_list(providers = [SwiftInfo]),
        "plugin": attr.label(executable = True, cfg = "exec"),
        "plugin_module_name": attr.string(doc = "The plugin's module name, which `-load-plugin-executable` pairs with it."),
        "expected_errors": attr.string_list(doc = "Text the compiler's output must hold; none for a source that must compile."),
    },
    test = True,
)
