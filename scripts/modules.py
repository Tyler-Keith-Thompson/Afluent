#!/usr/bin/env python3
"""The module graph, written once.

Package.swift, swift/Package.swift, every Sources/*/BUILD.bazel and Tests/*/BUILD.bazel, the
umbrella module, tools/performance_tests.bzl and tools/executables.bzl are generated from the tables below, so SwiftPM
and Bazel cannot drift. Run `just modules` after editing them. `//:package_swift_test` fails when
Package.swift disagrees with the Bazel graph.

Modules are named after the concept they hold, with a `Module` suffix only where the module
would otherwise share a name with its main type (`GreetingModule` would hold `Greeting`). No
catch-all modules ("Core", "Utilities").
"""

import os

# The package, umbrella module and test-support module take the project's name. A package whose
# main module takes the project's name (`import Afluent` is that module, not an umbrella) lists
# it in MODULES like any other, and then has no umbrella.
PROJECT = "Afluent"
TEST_SUPPORT = f"{PROJECT}TestSupport"

# External packages: (identity, url, minimum version). A dependency written "identity/Product"
# in the tables below refers to a product of one of these. A version written "exact:1.2.3" pins
# that release, for a package whose later releases resolve differently on different toolchains
# (Bazel resolves on each machine with its own swift). After adding one: `just modules`,
# add `swiftpkg_<identity>` (hyphens as underscores) to use_repo in MODULE.bazel, `just resolve`.
PACKAGES = [
    # Lock-free counters and flags behind the operators.
    ("swift-atomics", "https://github.com/apple/swift-atomics.git", "1.2.0"),
    # Tests only: controllable clocks (TestClock, ImmediateClock). Pinned: 1.1.1's manifests name
    # its IssueReporting dependency differently for Swift 6.4 and for 6.0-6.3, so Bazel's
    # resolution here (Xcode's Swift) breaks on CI's Linux Swift 6.3.
    ("swift-clocks", "https://github.com/pointfreeco/swift-clocks.git", "exact:1.1.0"),
    # Tests only: LockIsolated and withMainSerialExecutor.
    ("swift-concurrency-extras", "https://github.com/pointfreeco/swift-concurrency-extras.git", "1.1.0"),
    # Tests only: stubbed URLSession responses, on Apple platforms (APPLE_ONLY_PACKAGES).
    ("ohhttpstubs", "https://github.com/AliSoftware/OHHTTPStubs.git", "9.1.0"),
    # Mocks generated from protocols (`@Mockable`). Uncomment when a module first needs one; see
    # MOCKING below.
    # ("mockable", "https://github.com/Kolos65/Mockable", "0.6.4"),
]

# Packages that only Apple platforms build (Objective-C, or wrappers of Apple frameworks), by
# identity. SwiftPM links their products on Apple platforms only and Bazel on macOS only (a
# `select`), so the same targets still build on Linux, where the code using them is left out by
# `#if canImport`. //:package_swift_test leaves their products out of its comparison.
APPLE_ONLY_PACKAGES = ["ohhttpstubs"]

# The product whose macro generates mocks. A module that depends on it is compiled with the
# MOCKING condition in debug builds only (SwiftPM's debug configuration, Bazel's
# --compilation_mode=dbg), so `@Mockable` emits Mock<Protocol> types for tests and release
# builds carry none.
MOCKING = "mockable/Mockable"

# (name, group, description, dependencies)
MODULES = [
    ("Afluent", "Library", "Reactive operators over async/await: DeferredTask, AsyncSequence operators, subjects and caches.", ["swift-atomics/Atomics"]),
    ("AfluentTesting", "Testing", "Helpers for testing code built on Afluent: waiting until a condition holds or work is scheduled.", ["Afluent"]),
]

# Executables: (name, description, dependencies). Each is an `.executableTarget` and product in
# Package.swift and a swift_binary in Bazel (`bazel run //Sources/<name>`). Keep them thin: the
# code lives in MODULES, where tests can reach it. They are left out of the umbrella and the docs.
EXECUTABLES = [
]

# Test targets. SwiftPM rejects a target with no sources, so list a target only once its directory
# holds tests. (name, dependencies)
TEST_TARGETS = [
    ("AfluentTests", ["Afluent", "AfluentTesting", "ohhttpstubs/OHHTTPStubs", "ohhttpstubs/OHHTTPStubsSwift",
                      "swift-concurrency-extras/ConcurrencyExtras", "swift-clocks/Clocks"]),
]

# The modules the test-support target depends on (fixtures are usually written against the
# vocabulary module). Empty is fine.
TEST_SUPPORT_DEPENDENCIES = []

# Bazel test sizes above the default "small" (60 s timeout), for suites whose solo run takes more
# than about 15 s on a laptop or 30 s on a four-core CI runner, and so can pass 60 s when other
# tests load the machine. "medium" is 300 s.
TEST_SIZES = {name: "medium" for name in [
]}

# Test targets whose speed-reliant tests live in Performance/ under the target's directory: tests
# that pass only if the code is fast enough, because they bound their own wall-clock time
# (ContinuousClock) or run a large or adversarial input under a `.timeLimit` meant to catch a
# complexity regression. Each is built as a target of its own, performance_target(name), with the
# same dependencies, in the same Bazel package. `--config=release` builds and runs only those:
# every other test target and test library is tagged RELEASE_EXCLUDED_TAG, which .bazelrc filters
# out under release. Debug runs both. A `.timeLimit` that only guards a small input against a hang
# does not make a test speed-reliant.
PERFORMANCE_TESTS = [
]

# Performance tests run up to their one-minute limits each, so their targets get "medium" (300 s).
PERFORMANCE_TEST_SIZE = "medium"

# The tag .bazelrc's release config filters out of builds and tests (see PERFORMANCE_TESTS).
RELEASE_EXCLUDED_TAG = "debug-only"

# The Benchmarks/ package's targets: (name, library modules it imports). Both its Package.swift and
# its BUILD.bazel are written from this list. Each target is an ordo-one/benchmark executable in
# Benchmarks/Benchmarks/<name>; its Bazel target (tools/benchmarks.bzl) caches its simulated counts,
# so `just bench-simulated` measures again only the targets whose modules or sources changed.
BENCHMARKS = [
    ("AfluentBenchmarks", ["Afluent"]),
]
BENCHMARK_PACKAGE = ("https://github.com/ordo-one/benchmark", "1.27.0")

# Keep in step with .bazelrc's --macos_minimum_os.
PLATFORMS = '[.iOS(.v15), .macOS(.v13), .macCatalyst(.v15), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)]'
MACOS_MINIMUM = "13.0"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def performance_target(name):
    """The speed-reliant target split from test target `name`: FlowsTests -> FlowsPerformanceTests."""
    return name.removesuffix("Tests") + "PerformanceTests"


def check():
    names = [m[0] for m in MODULES]
    assert len(names) == len(set(names)), "duplicate module"
    packages = [p[0] for p in PACKAGES]
    for name, deps in [(m[0], m[3]) for m in MODULES] + [(e[0], e[2]) for e in EXECUTABLES]:
        for d in deps:
            if "/" in d:
                assert d.split("/")[0] in packages, f"{name} depends on unknown package {d}"
            else:
                assert d in names, f"{name} depends on unknown {d}"
    executables = [e[0] for e in EXECUTABLES]
    assert not set(executables) & set(names + [PROJECT]), "an executable shares a module's name"
    tests = [t[0] for t in TEST_TARGETS]
    assert len(tests) == len(set(tests)), "duplicate test target"
    for name, deps in TEST_TARGETS:
        for d in deps:
            if "/" in d:
                assert d.split("/")[0] in packages, f"{name} depends on unknown package {d}"
            else:
                assert d in names + [PROJECT, TEST_SUPPORT], f"{name} depends on unknown {d}"
    for name in PERFORMANCE_TESTS:
        assert name in tests, f"PERFORMANCE_TESTS names unknown test target {name}"
    for name, deps in BENCHMARKS:
        for d in deps:
            assert d in names or (d == PROJECT and umbrella()), f"benchmark {name} imports unknown module {d}"


def spm_dep(d):
    if "/" in d:
        package, product = d.split("/")
        condition = ", condition: .when(platforms: applePlatforms)" if package in APPLE_ONLY_PACKAGES else ""
        return f'.product(name: "{product}", package: "{package}"{condition})'
    return f'"{d}"'


def requirement(version):
    """A package's version requirement in a manifest: `from:` the minimum, or `exact:` a pinned release."""
    if version.startswith("exact:"):
        return f'exact: "{version.removeprefix("exact:")}"'
    return f'from: "{version}"'


def umbrella():
    """Whether the package has a generated umbrella module: unless MODULES lists the project's name."""
    return PROJECT not in [m[0] for m in MODULES]


def apple_only(d):
    return "/" in d and d.split("/")[0] in APPLE_ONLY_PACKAGES


def bazel_deps(deps):
    """A `deps` attribute, or nothing when there are none; Apple-only products sit in a macOS `select`."""
    if not deps:
        return ""
    listed = "".join(f'        "{bazel_label(d)}",\n' for d in deps if not apple_only(d))
    text = f"    deps = [\n{listed}    ]"
    apple = "".join(f'            "{bazel_label(d)}",\n' for d in deps if apple_only(d))
    if apple:
        text += (
            " + select({\n"
            "        # Apple-only packages (APPLE_ONLY_PACKAGES in scripts/modules.py).\n"
            f'        "@platforms//os:macos": [\n{apple}        ],\n'
            '        "//conditions:default": [],\n'
            "    })"
        )
    return text + ",\n"


def bazel_label(d):
    if "/" in d:
        package, product = d.split("/")
        return f"@swiftpkg_{package.replace('-', '_')}//:{product}"
    if d == TEST_SUPPORT:
        return f"//Tests/{TEST_SUPPORT}"
    return f"//Sources/{d}"


def excluded(path):
    """Non-source files SwiftPM would otherwise warn about, for the target at `path`."""
    return [f for f in ("BUILD.bazel", "README.md", "Performance") if os.path.exists(os.path.join(ROOT, path, f))]


def exclude_arg(path):
    files = excluded(path)
    if files == ["BUILD.bazel"]:
        return ", exclude: bazelFiles"
    if files:
        return ", exclude: [" + ", ".join(f'"{f}"' for f in files) + "]"
    return ""


def package_swift():
    lines = [
        "// swift-tools-version: 6.3",
        "import PackageDescription",
        "",
        "// GENERATED by scripts/modules.py — edit the table there, then run `just modules`.",
        "//",
        "// The published package definition. Bazel is the development build system; both are generated",
        "// from the same table, and `just verify` builds and tests with both.",
        "",
        "// Every target directory holds a BUILD.bazel, which SwiftPM must be told to ignore.",
        'let bazelFiles = ["BUILD.bazel"]',
        "",
    ]
    if APPLE_ONLY_PACKAGES:
        lines += [
            "// Where the Apple-only packages' products are linked (APPLE_ONLY_PACKAGES in scripts/modules.py).",
            "let applePlatforms: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS]",
            "",
        ]
    lines += [
        "// Typed arrays of their own: as one `Package(...)` expression, a large manifest is too big for",
        "// the type checker.",
        "let products: [Product] = [",
    ]
    if umbrella():
        lines.append(f'    .library(name: "{PROJECT}", targets: ["{PROJECT}"]),')
    lines += [f'    .library(name: "{m[0]}", targets: ["{m[0]}"]),' for m in MODULES]
    lines += [f'    .executable(name: "{e[0]}", targets: ["{e[0]}"]),' for e in EXECUTABLES]
    lines += ["]", "", "let dependencies: [Package.Dependency] = ["]
    lines += [f'    .package(url: "{url}", {requirement(version)}),' for _, url, version in PACKAGES]
    lines += ["]", "", "let targets: [Target] = ["]
    group = None
    for name, g, _, deps in MODULES:
        if g != group:
            lines.append(f"    // {g}")
            group = g
        ex = exclude_arg(f"Sources/{name}")
        settings = ', swiftSettings: [.define("MOCKING", .when(configuration: .debug))]' if MOCKING in deps else ""
        if deps:
            dl = ", ".join(spm_dep(d) for d in deps)
            lines.append(f'    .target(name: "{name}", dependencies: [{dl}]{ex}{settings}),')
        else:
            lines.append(f'    .target(name: "{name}"{ex}),')
    if EXECUTABLES:
        lines += ["", "    // Executables"]
    for name, _, deps in EXECUTABLES:
        dl = ", ".join(spm_dep(d) for d in deps)
        lines.append(f'    .executableTarget(name: "{name}", dependencies: [{dl}]{exclude_arg(f"Sources/{name}")}),')
    all_deps = ", ".join(f'"{m[0]}"' for m in MODULES)
    support_deps = ", ".join(spm_dep(d) for d in TEST_SUPPORT_DEPENDENCIES)
    support_deps_arg = f"dependencies: [{support_deps}], " if TEST_SUPPORT_DEPENDENCIES else ""
    if umbrella():
        lines += [
            "",
            f"    // Umbrella: `import {PROJECT}` imports every module.",
            f'    .target(name: "{PROJECT}", dependencies: [{all_deps}], exclude: bazelFiles),',
        ]
    lines += [
        "",
        "    // Shared fixtures (data only) for every test target.",
        f'    .target(name: "{TEST_SUPPORT}", {support_deps_arg}path: "Tests/{TEST_SUPPORT}", exclude: bazelFiles),',
        "",
    ]
    for name, deps in TEST_TARGETS:
        dl = ", ".join(spm_dep(d) for d in deps)
        files = excluded(f"Tests/{name}")
        ex = "[" + ", ".join(f'"{f}"' for f in files) + "]" if files != ["BUILD.bazel"] else "bazelFiles"
        lines.append(f'    .testTarget(name: "{name}", dependencies: [{dl}], exclude: {ex}),')
    if PERFORMANCE_TESTS:
        lines += [
            "",
            "    // Speed-reliant tests, split from the target of the same module (PERFORMANCE_TESTS in scripts/modules.py).",
        ]
        for name, deps in TEST_TARGETS:
            if name in PERFORMANCE_TESTS:
                dl = ", ".join(spm_dep(d) for d in deps)
                lines.append(f'    .testTarget(name: "{performance_target(name)}", dependencies: [{dl}], path: "Tests/{name}/Performance"),')
    lines += [
        "]",
        "",
        "let package = Package(",
        f'    name: "{PROJECT}",',
        "    // Keep in step with .bazelrc's --macos_minimum_os.",
        f"    platforms: {PLATFORMS},",
        "    products: products,",
        "    dependencies: dependencies,",
        "    targets: targets",
        ")",
        "",
    ]
    return "\n".join(lines)


def dependency_manifest():
    deps = "".join(f'        .package(url: "{url}", {requirement(version)}),\n' for _, url, version in PACKAGES)
    return (
        "// swift-tools-version: 6.0\n"
        "import PackageDescription\n\n"
        "// GENERATED by scripts/modules.py. Dependency-resolution manifest for Bazel\n"
        "// (rules_swift_package_manager); it lists the same packages as the root Package.swift.\n"
        "// After changing it, run `just resolve`.\n"
        "let package = Package(\n"
        f'    name: "{PROJECT}Dependencies",\n'
        f'    platforms: [.macOS("{MACOS_MINIMUM}")],\n'
        f"    dependencies: [\n{deps}    ]\n"
        ")\n"
    )


def build_bazel(name, description, deps):
    deps_attr = bazel_deps(deps)
    defines_attr = (
        "    # Mock<Protocol> types from @Mockable, in debug builds only (MOCKING in scripts/modules.py).\n"
        '    defines = select({"//tools:debug": ["MOCKING"], "//conditions:default": []}),\n'
    ) if MOCKING in deps else ""
    doc_deps = "".join(f'        "{bazel_label(d)}:{d}Documentation",\n' for d in deps if "/" not in d)
    doc_deps_attr = f"    deps = [\n{doc_deps}    ],\n" if doc_deps else ""
    return (
        "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
        'load("//tools:docc.bzl", "docc_archive")\n'
        'load("//tools:swift_rules.bzl", "swift_library")\n\n'
        f"# {description}\n"
        "swift_library(\n"
        f'    name = "{name}",\n'
        '    srcs = glob(["**/*.swift"]),\n'
        f'    module_name = "{name}",\n'
        f"{defines_attr}"
        f"{deps_attr}"
        '    visibility = ["//visibility:public"],\n'
        ")\n\n"
        "# The module's DocC archive, merged into //:docs. `manual` keeps it out of `bazel build //...`.\n"
        "docc_archive(\n"
        f'    name = "{name}Documentation",\n'
        f'    module = ":{name}",\n'
        '    catalog = glob(["*.docc/**"], allow_empty = True),\n'
        f"{doc_deps_attr}"
        '    tags = ["manual"],\n'
        '    visibility = ["//visibility:public"],\n'
        ")\n"
    )


def executable_build_bazel(name, description, deps):
    deps_attr = bazel_deps(deps)
    return (
        "# GENERATED by scripts/modules.py — edit EXECUTABLES there, then run `just modules`.\n\n"
        'load("//tools:swift_rules.bzl", "swift_binary")\n\n'
        f"# {description}\n"
        "swift_binary(\n"
        f'    name = "{name}",\n'
        '    srcs = glob(["**/*.swift"]),\n'
        f'    module_name = "{name}",\n'
        f"{deps_attr}"
        '    visibility = ["//visibility:public"],\n'
        ")\n"
    )


def test_support_build_bazel():
    deps_attr = bazel_deps(TEST_SUPPORT_DEPENDENCIES)
    return (
        "# GENERATED by scripts/modules.py — edit TEST_SUPPORT_DEPENDENCIES there, then run `just modules`.\n\n"
        'load("//tools:swift_rules.bzl", "swift_library")\n\n'
        "# Shared fixtures for every test target: data and generators only, no assertion helpers.\n"
        "swift_library(\n"
        f'    name = "{TEST_SUPPORT}",\n'
        "    testonly = True,\n"
        '    srcs = glob(["**/*.swift"]),\n'
        f'    module_name = "{TEST_SUPPORT}",\n'
        f"{deps_attr}"
        '    visibility = ["//visibility:public"],\n'
        ")\n"
    )


def test_targets_bazel(name, deps, size, srcs, tags):
    """One test module: its library, the swift_test that `bazel test` runs, and the Xcode bundle."""
    tags_attr = f"    tags = {tags},\n".replace("'", '"') if tags else ""
    return (
        "swift_library(\n"
        f'    name = "{name}Library",\n'
        "    testonly = True,\n"
        "    # Tests are found through metadata the linker would otherwise drop, since nothing\n"
        "    # references them by name.\n"
        "    alwayslink = True,\n"
        f"    srcs = {srcs},\n"
        f'    module_name = "{name}",\n'
        f"{tags_attr}"
        "    # Read by //:package_swift_test, which checks Package.swift against the Bazel graph.\n"
        '    visibility = ["//:__pkg__"],\n'
        f"{bazel_deps(deps)}"
        ")\n\n"
        "# `bazel test` / `just test`: a standalone executable, fast to start and run in Bazel's sandbox.\n"
        "swift_test(\n"
        f'    name = "{name}",\n'
        f'    size = "{size}",\n'
        f"{tags_attr}"
        f'    deps = [":{name}Library"],\n'
        ")\n\n"
        "# The generated Xcode project: a real .xctest bundle (an MH_BUNDLE), which is what Xcode's test\n"
        "# runner loads. `manual` keeps it out of `bazel test //...`; it runs through xcodebuild, so it\n"
        "# is only for Xcode. XCTest refuses exit tests in a sandboxed host, hence `no-sandbox`.\n"
        "macos_unit_test(\n"
        f'    name = "{name}Bundle",\n'
        f'    bundle_name = "{name}",\n'
        f'    size = "{size}",\n'
        f'    minimum_os_version = "{MACOS_MINIMUM}",\n'
        '    tags = ["manual", "no-sandbox"],\n'
        "    # Visible so `//:xcodeproj` can name it as a top-level target.\n"
        '    visibility = ["//visibility:public"],\n'
        f'    deps = [":{name}Library"],\n'
        ")\n"
    )


def test_build_bazel(name, deps):
    size = TEST_SIZES.get(name, "small")
    header = (
        "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
        'load("@rules_apple//apple:macos.bzl", "macos_unit_test")\n'
        'load("//tools:swift_rules.bzl", "swift_library", "swift_test")\n\n'
    )
    excluded_note = (
        f"Tagged `{RELEASE_EXCLUDED_TAG}`: none of these relies on speed, so\n"
        "# `--config=release` neither builds nor runs them (.bazelrc).\n"
    )
    if name not in PERFORMANCE_TESTS:
        return (header + "# The tests, built once and linked into two runners.\n# " + excluded_note
                + test_targets_bazel(name, deps, size, 'glob(["**/*.swift"])', [RELEASE_EXCLUDED_TAG]))
    return (
        header
        + "# The tests, built once and linked into two runners; the speed-reliant ones, in Performance/, are\n"
        + f"# {performance_target(name)} below. " + excluded_note
        + test_targets_bazel(name, deps, size, 'glob(["**/*.swift"], exclude = ["Performance/**"])', [RELEASE_EXCLUDED_TAG])
        + "\n# The speed-reliant tests (PERFORMANCE_TESTS in scripts/modules.py): debug and `--config=release`\n"
        + "# both run them.\n"
        + test_targets_bazel(performance_target(name), deps, PERFORMANCE_TEST_SIZE, 'glob(["Performance/**/*.swift"])', [])
    )


def performance_tests_bzl():
    packages = "".join(f'    "Tests/{name}",\n' for name in PERFORMANCE_TESTS)
    return (
        '"""GENERATED by scripts/modules.py (PERFORMANCE_TESTS) — edit the list there, then run `just modules`."""\n\n'
        "# The test packages that also hold a speed-reliant target, `<Name>PerformanceTests` built from\n"
        "# Performance/, which the root BUILD.bazel cannot find from the directory layout alone.\n"
        f"PERFORMANCE_TEST_PACKAGES = [\n{packages}]\n"
    )


def executables_bzl():
    packages = "".join(f'    "Sources/{e[0]}",\n' for e in EXECUTABLES)
    return (
        '"""GENERATED by scripts/modules.py (EXECUTABLES) — edit the table there, then run `just modules`."""\n\n'
        "# The source packages that hold a swift_binary rather than a library: the root BUILD.bazel\n"
        "# leaves them out of the docs and launches them from the Xcode project.\n"
        f"EXECUTABLE_PACKAGES = [\n{packages}]\n"
    )


def library_directories():
    """Every non-test target directory the root Package.swift declares."""
    directories = [f"Sources/{m[0]}" for m in MODULES] + [f"Sources/{e[0]}" for e in EXECUTABLES]
    if umbrella():
        directories.append(f"Sources/{PROJECT}")
    return sorted(directories + [f"Tests/{TEST_SUPPORT}"])


def benchmarks_package_swift():
    url, version = BENCHMARK_PACKAGE
    targets = "".join(
        "        .executableTarget(\n"
        f'            name: "{name}",\n'
        "            dependencies: [\n"
        '                .product(name: "Benchmark", package: "benchmark"),\n'
        + "".join(f'                .product(name: "{d}", package: "{PROJECT}"),\n' for d in deps)
        + "            ],\n"
        f'            path: "Benchmarks/{name}",\n'
        '            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]\n'
        "        ),\n"
        for name, deps in BENCHMARKS
    )
    return (
        "// swift-tools-version: 6.3\n"
        "import PackageDescription\n\n"
        "// GENERATED by scripts/modules.py from BENCHMARKS: edit the table there, then run `just modules`.\n"
        "// Benchmarks live in their own package so the library and its tests never depend on the\n"
        "// benchmark framework. Run them with `just bench`; see Benchmarks/README.md.\n\n"
        "let package = Package(\n"
        f'    name: "{PROJECT}Benchmarks",\n'
        "    platforms: [.macOS(.v15)],\n"
        "    dependencies: [\n"
        "        // Named, so the identity does not depend on the checkout directory's name.\n"
        f'        .package(name: "{PROJECT}", path: ".."),\n'
        f'        .package(url: "{url}", from: "{version}"),\n'
        "    ],\n"
        f"    targets: [\n{targets}    ]\n"
        ")\n"
    )


def benchmarks_build_bazel():
    directories = "".join(f'    "{d}",\n' for d in library_directories())
    benchmarks = "".join(f'    "{name}",\n' for name, _ in BENCHMARKS)
    targets = "".join(
        "\nsimulated_benchmark(\n"
        f'    name = "{name}",\n'
        f'    srcs = glob(["Benchmarks/{name}/**"]),\n'
        "    modules = [\n"
        + "".join(f'        "{bazel_label(d)}",\n' for d in deps)
        + "    ],\n"
        "    manifests = MANIFESTS,\n"
        "    library_directories = LIBRARY_DIRECTORIES,\n"
        "    benchmarks = BENCHMARKS,\n"
        f'    project = "{PROJECT.lower()}",\n'
        '    harness = ".harness/bin/benchmark-harness",\n'
        "    # Empty until `just bench-simulated` copies the harness in; `bazel test //...` loads this anyway.\n"
        '    harness_files = glob([".harness/bin/*.bundle/**"], allow_empty = True),\n'
        '    stamp = ".harness/stamp",\n'
        "    # `manual`: measuring starts a VM, so `bazel build //...` leaves these out.\n"
        '    tags = ["manual"],\n'
        ")\n"
        for name, deps in BENCHMARKS
    )
    return (
        "# GENERATED by scripts/modules.py from BENCHMARKS: edit the table there, then run `just modules`.\n"
        "#\n"
        "# Each benchmark target's simulated counts, as a cached Bazel output (tools/benchmarks.bzl).\n"
        "# `just bench-simulated` writes .harness/ and builds these; nothing else should.\n\n"
        'load("//tools:benchmarks.bzl", "simulated_benchmark")\n\n'
        '# The root manifest, this package\'s manifest and its pins (which cover the whole graph).\n'
        'MANIFESTS = [\n    "//:Package.swift",\n    "Package.swift",\n    "Package.resolved",\n]\n\n'
        "# Every target directory SwiftPM needs to load the root manifest.\n"
        f"LIBRARY_DIRECTORIES = [\n{directories}]\n\n"
        "# Every benchmark target, each of which SwiftPM needs to load this package's manifest.\n"
        f"BENCHMARKS = [\n{benchmarks}]\n"
        + targets
    )


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def main():
    check()
    for name, _, description, deps in MODULES:
        d = os.path.join(ROOT, "Sources", name)
        write(os.path.join(d, "BUILD.bazel"), build_bazel(name, description, deps))
        # SwiftPM and Bazel both reject a module with no sources. Until a module has real
        # sources, it carries a file holding only its description.
        if not any(fn.endswith(".swift") for _, _, fns in os.walk(d) for fn in fns):
            write(os.path.join(d, f"{name}.swift"), f"// {name}: {description}\n")
    for name, deps in TEST_TARGETS:
        d = os.path.join(ROOT, "Tests", name)
        write(os.path.join(d, "BUILD.bazel"), test_build_bazel(name, deps))
        # SwiftPM rejects a target with no sources, and one left out of PERFORMANCE_TESTS would be
        # compiled into the module's own target, which release skips.
        performance = os.path.join(d, "Performance")
        has_performance = any(fn.endswith(".swift") for _, _, fns in os.walk(performance) for fn in fns)
        assert has_performance == (name in PERFORMANCE_TESTS), \
            f"{name}: Performance/ holds Swift sources exactly when the target is in PERFORMANCE_TESTS"
    for name, description, deps in EXECUTABLES:
        d = os.path.join(ROOT, "Sources", name)
        write(os.path.join(d, "BUILD.bazel"), executable_build_bazel(name, description, deps))
    write(os.path.join(ROOT, "Tests", TEST_SUPPORT, "BUILD.bazel"), test_support_build_bazel())
    write(os.path.join(ROOT, "tools", "executables.bzl"), executables_bzl())
    write(os.path.join(ROOT, "tools", "performance_tests.bzl"), performance_tests_bzl())
    names = [m[0] for m in MODULES]
    if umbrella():
        directory = os.path.join(ROOT, "Sources", PROJECT)
        write(os.path.join(directory, "BUILD.bazel"), build_bazel(PROJECT, f"Umbrella: `import {PROJECT}` imports every module.", names))
        write(os.path.join(directory, f"{PROJECT}.swift"),
              f"// GENERATED by scripts/modules.py.\n//\n// Umbrella: `import {PROJECT}` imports every module.\n\n"
              + "".join(f"@_exported import {n}\n" for n in names))
    write(os.path.join(ROOT, "swift", "Package.swift"), dependency_manifest())
    write(os.path.join(ROOT, "Benchmarks", "Package.swift"), benchmarks_package_swift())
    write(os.path.join(ROOT, "Benchmarks", "BUILD.bazel"), benchmarks_build_bazel())
    # Written last: which files each target must exclude depends on the BUILD files above.
    write(os.path.join(ROOT, "Package.swift"), package_swift())


if __name__ == "__main__":
    main()
