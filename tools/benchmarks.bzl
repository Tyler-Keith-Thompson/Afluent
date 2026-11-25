"""Simulated benchmark counts as cached Bazel outputs.

`simulated_benchmark` measures one ordo-one/benchmark target of the Benchmarks/ package with
BenchmarkHarness (Callgrind in its Linux VM on macOS, on the host on Linux) and writes the
target's baseline JSON as its output. Instruction counts are deterministic, so the result is keyed
on its inputs like any build output: the benchmark's sources, the sources of the library modules
it depends on (directly or not), the package manifests and pins, and the harness binary with a
stamp of the toolchain (Benchmarks/.harness, which scripts/bench_simulated.py writes). A source a
generator writes at build time (GENERATED_SOURCES in scripts/modules.py) is staged from the
generator's output, at the path of the checked-in copy SwiftPM compiles, so what the generator
writes is an input too. Nothing else reaches the measurement, so an unchanged target comes from the
disk cache or BuildBuddy and only targets whose inputs changed are measured again.

The action runs outside the sandbox, which can't start a VM, but it is still cached. It stages the
package at a fixed path per checkout and target (under the user's cache directory), so SwiftPM's
build there stays incremental between runs and two checkouts never measure each other's sources.
The generated Benchmarks/BUILD.bazel holds one target per row of
BENCHMARKS in scripts/modules.py; `just bench-simulated` builds them.
"""

load(":generated_sources.bzl", "GeneratedSwiftSourcesInfo")
load(":resources.bzl", "ModuleResourcesInfo")

_SourcesInfo = provider(
    doc = "The first-party files a module compiles from, its own and its dependencies': Swift sources and resources.",
    fields = {
        "files": "depset of File",
        "generated": "depset of lines `<path><TAB><path of the checked-in copy>`, one per generated source among the files",
    },
)

def _sources_aspect_impl(target, ctx):
    own = []
    generated = []
    if target.label.workspace_name == "" and hasattr(ctx.rule.files, "srcs"):
        # Bazel's own `Bundle.module` (tools/resources.bzl) is generated; SwiftPM generates its own.
        own = [file for file in ctx.rule.files.srcs if file.is_source]
        # Sources a generator writes (tools/generated_sources.bzl) are generated too, but SwiftPM
        # compiles their checked-in copies, which the module's srcs leave out: they are staged there.
        for src in ctx.rule.attr.srcs:
            if GeneratedSwiftSourcesInfo in src:
                for file, destination in src[GeneratedSwiftSourcesInfo].destinations.items():
                    own.append(file)
                    generated.append(file.path + "\t" + destination)
    # A module's resources (RESOURCES in scripts/modules.py), which SwiftPM bundles with it.
    if ModuleResourcesInfo in target:
        own = target[ModuleResourcesInfo].files.to_list()
    # A module's compiler plugins (`plugins`) expand its macros, so their sources are inputs too.
    attributes = getattr(ctx.rule.attr, "deps", []) + getattr(ctx.rule.attr, "plugins", []) + getattr(ctx.rule.attr, "data", [])
    dependencies = [d[_SourcesInfo] for d in attributes if _SourcesInfo in d]
    return [_SourcesInfo(
        files = depset(own, transitive = [d.files for d in dependencies]),
        generated = depset(generated, transitive = [d.generated for d in dependencies]),
    )]

_sources_aspect = aspect(
    implementation = _sources_aspect_impl,
    attr_aspects = ["deps", "plugins", "data"],
)

# One measurement starts a VM of 4 processors and 16 GiB (BenchmarkHarness's defaults), so Bazel
# runs no more of them at once than the machine's --local_resources allow.
def _resources(_os, _inputs):
    return {"cpu": 4, "memory": 16384}

_STAGE = """\
set -euo pipefail
target="$1" files="$2" generated="$3" harness="$4" out="$5" project="$6" benchmarks="$7"
shift 7
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
# Sources written at build time, at the paths of the checked-in copies SwiftPM compiles. They keep
# the generator's output's time, which moves only when the output is written again.
while IFS=$'\\t' read -r source destination; do
    mkdir -p "$fresh/$(dirname "$destination")"
    cp -p "$source" "$fresh/$destination"
    chmod u+w "$fresh/$destination"
done < "$generated"
# Every library target the root manifest declares must exist for SwiftPM to load it. A module this
# benchmark doesn't use gets a placeholder source, dated so that it never looks changed. So does a
# command plugin (Plugins/, PLUGINS in scripts/modules.py), which no benchmark uses: Linux's
# SwiftPM links it, so its placeholder is an empty plugin, and it gets no BUILD.bazel, which its
# target doesn't exclude.
for directory in "$@"; do
    mkdir -p "$fresh/$directory"
    case "$directory" in
        Plugins/*)
            if [ -z "$(find "$fresh/$directory" -name '*.swift' -print -quit)" ]; then
                printf '// Not staged: no benchmark uses the plugin.\nimport PackagePlugin\n\n@main\nstruct Placeholder: CommandPlugin {\n    func performCommand(context: PluginContext, arguments: [String]) async throws {}\n}\n' > "$fresh/$directory/Placeholder.swift"
                touch -t 200001010000 "$fresh/$directory/Placeholder.swift"
            fi
            continue
            ;;
    esac
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
    generated = depset(transitive = [m[_SourcesInfo].generated for m in ctx.attr.modules])
    inputs = depset(
        ctx.files.srcs + ctx.files.manifests + ctx.files.harness_files + [ctx.file.harness, ctx.file.stamp],
        transitive = [sources],
    )
    listing = ctx.actions.declare_file(ctx.label.name + ".files")
    harness = [ctx.file.harness] + ctx.files.harness_files
    # Files of the repository only: the generated ones are staged from their own listing, so nothing
    # lands under a bazel-out/ path, which SwiftPM never reads.
    ctx.actions.write(listing, "".join([f.path + "\n" for f in inputs.to_list() if f.is_source and f not in harness]))
    generated_listing = ctx.actions.declare_file(ctx.label.name + ".generated")
    ctx.actions.write(generated_listing, "".join([line + "\n" for line in generated.to_list()]))
    out = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.run_shell(
        command = _STAGE,
        arguments = [
            ctx.label.name,
            listing.path,
            generated_listing.path,
            ctx.file.harness.path,
            out.path,
            ctx.attr.project,
            " ".join(ctx.attr.benchmarks),
        ] + ctx.attr.library_directories,
        inputs = depset([listing, generated_listing], transitive = [inputs]),
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
