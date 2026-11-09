PROJECT_ROOT := justfile_directory()
BAZEL := "bazel"

# Optimized builds use a separate output base: switching --compilation_mode changes the
# configuration, and sharing a base with debug builds would discard the analysis cache on every
# switch (which .bazelrc refuses).
BAZEL_RELEASE := "bazel --output_base=" + home_directory() + "/Library/Caches/bazel-afluent-release"

# SwiftPM runs through Xcode's default toolchain. A development snapshot selected through
# TOOLCHAINS (or first on PATH via swiftly) can fail to read the SDK's Testing module.
SWIFT := "env -u TOOLCHAINS xcrun --toolchain default swift"

[doc('Build everything (default)')]
all: build

[doc('Build every target')]
build:
    {{BAZEL}} build //...

[doc('Run every test')]
test:
    {{BAZEL}} test //...

[doc('Build Afluent for every Apple platform it supports (Platforms/BUILD.bazel; needs Xcode)')]
platforms:
    {{BAZEL}} test //Platforms

[doc('Run one test target, e.g. just test-one //Tests/AfluentTests')]
test-one target:
    {{BAZEL}} test {{target}}

[doc('Run tests matching a filter, e.g. just filter Greeting')]
filter pattern:
    {{BAZEL}} test //... --test_filter={{pattern}}

[doc('Run the speed-reliant tests (the PerformanceTests targets) optimized (-O); the rest run in debug only')]
test-release:
    {{BAZEL_RELEASE}} test --config=release //...

[doc('Re-resolve SwiftPM dependencies for Bazel after editing PACKAGES in scripts/modules.py')]
resolve:
    cd {{PROJECT_ROOT}}/swift && {{SWIFT}} package resolve

[doc('Build via SwiftPM too, to verify the published package')]
spm:
    {{SWIFT}} build

[doc('Run the tests via SwiftPM')]
spm-test *args="":
    {{SWIFT}} test {{args}}

[doc('Verify both build systems agree — run before pushing')]
verify: test spm-test

[doc('Regenerate Package.swift and every BUILD.bazel from scripts/modules.py')]
modules:
    python3 {{PROJECT_ROOT}}/scripts/modules.py

[doc('Build the combined DocC site for every library module into .build/docs (what the DocC workflow publishes)')]
docs:
    {{BAZEL}} build //:docs
    rm -rf {{PROJECT_ROOT}}/.build/docs && mkdir -p {{PROJECT_ROOT}}/.build
    cp -RL {{PROJECT_ROOT}}/bazel-bin/docs {{PROJECT_ROOT}}/.build/docs && chmod -R u+w {{PROJECT_ROOT}}/.build/docs

# The checkout of BenchmarkHarness whose benchmark-harness tool records simulated baselines.
BENCHMARK_HARNESS := env("BENCHMARK_HARNESS", home_directory() / "workspace" / "BenchmarkHarness")

[doc('Run the benchmarks, e.g. just bench, or just bench --target AfluentBenchmarks')]
bench *args="":
    cd {{PROJECT_ROOT}}/Benchmarks && {{SWIFT}} package --allow-writing-to-package-directory benchmark {{args}}

[doc('Record the current results as the baseline named main')]
bench-baseline:
    cd {{PROJECT_ROOT}}/Benchmarks && {{SWIFT}} package --allow-writing-to-package-directory benchmark baseline update main

[doc('Compare the current results against the saved baseline')]
bench-compare:
    cd {{PROJECT_ROOT}}/Benchmarks && {{SWIFT}} package --allow-writing-to-package-directory benchmark baseline compare main

[doc("Record the benchmarks' simulated counts (Callgrind in a Linux VM; steady on a busy machine) as the simulated baseline, e.g. just bench-simulated, or just bench-simulated --target X")]
bench-simulated *args="": (_simulated-baseline "simulated" args)

[doc("Record simulated counts as simulated-current and compare them against the simulated baseline, e.g. just bench-simulated-compare --target X")]
bench-simulated-compare *args="": (_simulated-baseline "simulated-current" args)
    cd {{PROJECT_ROOT}}/Benchmarks && {{SWIFT}} package --allow-writing-to-package-directory benchmark baseline compare simulated simulated-current {{args}}

[private]
_simulated-baseline name args:
    just --justfile {{BENCHMARK_HARNESS}}/justfile harness
    {{BENCHMARK_HARNESS}}/Harness/.build/release/benchmark-harness baseline update {{name}} --package-path {{PROJECT_ROOT}}/Benchmarks {{args}}

[doc('Generate an Xcode project from the Bazel graph and open it')]
generate *args="":
    @bash scripts/generate-xcodeproj.sh {{args}}

[doc('Build optimized: the library and the speed-reliant tests, not the debug-only test targets')]
release:
    {{BAZEL_RELEASE}} build --config=release //...

[doc('Store the BuildBuddy API key in the login Keychain (asks for it), once per Mac: every project from the template then builds with the remote cache (tools/bazel)')]
buildbuddy-key:
    #!/usr/bin/env bash
    set -euo pipefail
    read -r -s -p "BuildBuddy API key (hidden): " key
    echo
    if [ -z "$key" ]; then
        echo "No key entered; nothing stored" >&2
        exit 1
    fi
    # Through security's own command reader, so the key never appears in a process's arguments.
    printf 'add-generic-password -U -s buildbuddy -a api-key -l "BuildBuddy API key" -w %s\n' "$key" | security -i >/dev/null
    echo "Stored. Builds use BuildBuddy from the next Bazel command."

[doc('Set this repository’s BUILDBUDDY_API_KEY Actions secret from the Keychain with gh, so CI uses the remote cache too')]
ci-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! key="$(security find-generic-password -s buildbuddy -a api-key -w 2>/dev/null)"; then
        echo "No BuildBuddy API key in the Keychain; store it with just buildbuddy-key" >&2
        exit 1
    fi
    printf '%s' "$key" | gh secret set BUILDBUDDY_API_KEY

# The checkout of ProjectTemplate this project came from; .template.json records the commit.
PROJECT_TEMPLATE := env("PROJECT_TEMPLATE", home_directory() / "workspace" / "ProjectTemplate")

[doc('Merge the project template’s changes since .template.json’s commit into this checkout (needs a clean worktree), e.g. just template-update, or just template-update --to <commit>')]
template-update *args="":
    python3 {{PROJECT_TEMPLATE}}/template.py update {{PROJECT_ROOT}} {{args}}

[doc('Remove all build artifacts')]
clean:
    {{BAZEL}} clean
    {{BAZEL_RELEASE}} clean || true
    rm -rf {{PROJECT_ROOT}}/.build
    rm -rf {{PROJECT_ROOT}}/Benchmarks/.build

[doc('Print the dependency graph of a target')]
deps target="//Sources/Afluent":
    {{BAZEL}} query 'deps({{target}})' --output=label_kind

[doc('List every buildable target')]
targets:
    {{BAZEL}} query '//...' --output=label_kind
