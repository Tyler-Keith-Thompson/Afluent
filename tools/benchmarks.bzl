"""Simulated benchmark counts as cached Bazel outputs.

`simulated_benchmark` measures one ordo-one/benchmark target of the Benchmarks/ package with
BenchmarkHarness (Callgrind in its Linux VM on macOS, on the host on Linux) and writes the
target's baseline JSON as its output. Instruction counts are deterministic, so the result is keyed
on its inputs like any build output: the benchmark's sources, the sources of the library modules
it depends on (directly or not), the package manifests and pins, and the harness binary with a
stamp of the toolchain (Benchmarks/.harness, which scripts/bench_simulated.py writes). Nothing else
reaches the measurement, so an unchanged target comes from the disk cache or BuildBuddy and only
targets whose inputs changed are measured again.

The action runs outside the sandbox, which can't start a VM, but it is still cached. It stages the
package at a fixed path per checkout and target (under the user's cache directory), so SwiftPM's
build there stays incremental between runs and two checkouts never measure each other's sources.
The generated Benchmarks/BUILD.bazel holds one target per row of
BENCHMARKS in scripts/modules.py; `just bench-simulated` builds them.
"""

_SourcesInfo = provider(
    doc = "The first-party Swift sources a module compiles from, its own and its dependencies'.",
    fields = {"files": "depset of File"},
)

def _sources_aspect_impl(target, ctx):
    own = []
    if target.label.workspace_name == "" and hasattr(ctx.rule.files, "srcs"):
        own = ctx.rule.files.srcs
    transitive = [d[_SourcesInfo].files for d in getattr(ctx.rule.attr, "deps", []) if _SourcesInfo in d]
    return [_SourcesInfo(files = depset(own, transitive = transitive))]

_sources_aspect = aspect(
    implementation = _sources_aspect_impl,
    attr_aspects = ["deps"],
)

# One measurement starts a VM of 4 processors and 16 GiB (BenchmarkHarness's defaults), so Bazel
# runs no more of them at once than the machine's --local_resources allow.
def _resources(_os, _inputs):
    return {"cpu": 4, "memory": 16384}

_STAGE = """\
set -euo pipefail
target="$1" files="$2" harness="$3" out="$4" project="$5" benchmarks="$6"
shift 6
# Bazel passes actions no HOME; the user database has it. The harness keeps its VM and builds there.
HOME="$(eval echo "~$(id -un)")"
export HOME
case "$(uname -s)" in
    Darwin) cache="$HOME/Library/Caches" ;;
    *) cache="${XDG_CACHE_HOME:-$HOME/.cache}" ;;
esac
# One staging directory per checkout and target: a checkout's runs reuse it, so SwiftPM's build
# there stays incremental, and two checkouts (worktrees, each with its own Bazel output base and so
# its own execution root, the working directory here) never share one. cksum is POSIX, so this
# needs nothing beyond the base system on macOS or Linux.
checkout="$(printf '%s' "$PWD" | cksum | cut -d ' ' -f 1)"
stage="$cache/$project-benchmarks/$checkout/$target"
fresh="$(mktemp -d)"
trap 'rm -rf "$fresh"' EXIT

# The declared inputs, at their paths in the repository.
rsync -a --copy-links --files-from="$files" . "$fresh/"
# Every library target the root manifest declares must exist for SwiftPM to load it. A module this
# benchmark doesn't use gets a placeholder source, dated so that it never looks changed.
for directory in "$@"; do
    mkdir -p "$fresh/$directory"
    if [ -z "$(find "$fresh/$directory" -name '*.swift' -print -quit)" ]; then
        echo "// Not staged: this benchmark doesn't use the module." > "$fresh/$directory/Placeholder.swift"
        touch -t 200001010000 "$fresh/$directory/Placeholder.swift"
    fi
    [ -e "$fresh/$directory/BUILD.bazel" ] || { : > "$fresh/$directory/BUILD.bazel"; touch -t 200001010000 "$fresh/$directory/BUILD.bazel"; }
done

# Likewise every benchmark target the benchmarks manifest declares. The harness builds them all, so
# another target's placeholder is an empty benchmark.
for name in $benchmarks; do
    directory="$fresh/Benchmarks/Benchmarks/$name"
    mkdir -p "$directory"
    if [ -z "$(find "$directory" -name '*.swift' -print -quit)" ]; then
        printf '// Not staged: measured by its own target.\nimport Benchmark\n\nlet benchmarks: @Sendable () -> Void = {}\n' > "$directory/Placeholder.swift"
        touch -t 200001010000 "$directory/Placeholder.swift"
    fi
done

# Into the fixed staging directory, changing only what differs, so SwiftPM rebuilds only that.
# The harness shares the enclosing Git work tree with the VM (the package alone without one), so
# the staging directory is a repository, for the root manifest to reach it.
mkdir -p "$stage"
[ -d "$stage/.git" ] || git init -q "$stage"
rsync -a --delete --exclude /.git --exclude /.build --exclude /.swiftpm --exclude /Benchmarks/.build \\
    --exclude /Benchmarks/.swiftpm --exclude /Benchmarks/.benchmarkBaselines "$fresh/" "$stage/"
rm -rf "$stage/Benchmarks/.benchmarkBaselines/$target/bazel"
"$harness" baseline update bazel --package-path "$stage/Benchmarks" --target "$target" >&2
cp "$stage/Benchmarks/.benchmarkBaselines/$target/bazel/results.json" "$out"
"""

def _simulated_benchmark_impl(ctx):
    sources = depset(transitive = [m[_SourcesInfo].files for m in ctx.attr.modules])
    inputs = depset(
        ctx.files.srcs + ctx.files.manifests + ctx.files.harness_files + [ctx.file.harness, ctx.file.stamp],
        transitive = [sources],
    )
    listing = ctx.actions.declare_file(ctx.label.name + ".files")
    harness = [ctx.file.harness] + ctx.files.harness_files
    ctx.actions.write(listing, "".join([f.path + "\n" for f in inputs.to_list() if f not in harness]))
    out = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.run_shell(
        command = _STAGE,
        arguments = [
            ctx.label.name,
            listing.path,
            ctx.file.harness.path,
            out.path,
            ctx.attr.project,
            " ".join(ctx.attr.benchmarks),
        ] + ctx.attr.library_directories,
        inputs = depset([listing], transitive = [inputs]),
        outputs = [out],
        mnemonic = "SimulatedBenchmark",
        progress_message = "Measuring %{label} under Callgrind",
        execution_requirements = {"no-sandbox": "1"},
        resource_set = _resources,
        use_default_shell_env = True,
    )
    return [DefaultInfo(files = depset([out]))]

simulated_benchmark = rule(
    implementation = _simulated_benchmark_impl,
    doc = "One benchmark target's simulated baseline (results.json), measured by BenchmarkHarness.",
    attrs = {
        "srcs": attr.label_list(allow_files = True, doc = "The benchmark target's sources."),
        "modules": attr.label_list(aspects = [_sources_aspect], doc = "The library modules it imports."),
        "manifests": attr.label_list(allow_files = True, doc = "The root and benchmark manifests and the benchmark package's pins."),
        "library_directories": attr.string_list(doc = "Every non-test target directory the root manifest declares."),
        "benchmarks": attr.string_list(doc = "Every benchmark target the benchmarks manifest declares."),
        "project": attr.string(mandatory = True, doc = "Names the staging directory."),
        "harness": attr.label(allow_single_file = True, mandatory = True, doc = "The benchmark-harness binary."),
        "harness_files": attr.label_list(allow_files = True, doc = "The harness's resource bundles, which hold the guest's scripts."),
        "stamp": attr.label(allow_single_file = True, mandatory = True, doc = "The toolchain and host the counts depend on."),
    },
)
