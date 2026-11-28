#!/usr/bin/env python3
"""The module graph, written once.

Package.swift, swift/Package.swift, every Sources/*/BUILD.bazel and Tests/*/BUILD.bazel, the
umbrella module, tools/performance_tests.bzl, tools/executables.bzl, tools/examples.bzl,
tools/macros.bzl and tools/swift_version.bzl are generated from the tables below, so SwiftPM
and Bazel cannot drift. Run `just modules` after editing them. `//:package_swift_test` fails when
Package.swift disagrees with the Bazel graph.

Modules are named after the concept they hold, with a `Module` suffix only where the module
would otherwise share a name with its main type (`GreetingModule` would hold `Greeting`). No
catch-all modules ("Core", "Utilities").
"""

import ast
import collections
import glob
import os
import re
import sys

# The package, umbrella module and test-support module take the project's name. A package whose
# main module takes the project's name (`import Afluent` is that module, not an umbrella) lists
# it in MODULES like any other, and then has no umbrella.
PROJECT = "Afluent"
TEST_SUPPORT = f"{PROJECT}TestSupport"

# External packages: (identity, url, minimum version). A dependency written "identity/Product"
# in the tables below refers to a product of one of these. A version written "exact:1.2.3" pins
# that release, for a package whose later releases resolve differently on different toolchains
# (Bazel resolves on each machine with its own swift). One written "minor:0.1.3" takes patch
# releases only, for a 0.x package whose minor releases break its API. One written
# "range:603.0.0..<605.0.0" admits every release from the first version up to, not including, the
# second, for a package whose next major releases still work (swift-syntax for a macro, beside a
# package capped below its newest major). After adding one:
# `just modules`, add `swiftpkg_<identity>` (hyphens as underscores) to use_repo in MODULE.bazel,
# `just resolve`.
PACKAGES = [
    # Lock-free counters and flags behind the operators.
    ("swift-atomics", "https://github.com/apple/swift-atomics.git", "1.2.0"),
    # Tests only: controllable clocks (TestClock, ImmediateClock). Pinned: 1.1.1's manifests name
    # its IssueReporting dependency differently for Swift 6.4 and for 6.0-6.3, so Bazel's
    # resolution here (Xcode's Swift) breaks on CI's Linux Swift 6.3.
    ("swift-clocks", "https://github.com/pointfreeco/swift-clocks.git", "exact:1.1.0"),
    # Tests only: LockIsolated and withMainSerialExecutor.
    ("swift-concurrency-extras", "https://github.com/pointfreeco/swift-concurrency-extras.git", "1.1.0"),
    # Tests only: seeded generators that reproduce on every platform and Swift release.
    ("swiftprng", "https://github.com/Tyler-Keith-Thompson/SwiftPRNG.git", "0.0.6"),
    # Tests only: property tests against naive references (`propertyCheck`).
    ("swift-property-based", "https://github.com/x-sheep/swift-property-based", "2.0.1"),
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

# Packages that build everywhere but WebAssembly (those on NIOPosix, such as Hummingbird or Vapor), by
# identity. SwiftPM links their products on every other platform (`.when(platforms:)`), so the
# package still builds for wasm32-wasi, where the code using them is left out by `#if canImport`.
# Bazel never builds for WASI, so it links them everywhere, and //:package_swift_test leaves their
# products out of its comparison.
NON_WASI_PACKAGES = []

# Test targets with nothing to run off Apple platforms (all their tests under `#if os(macOS)`), by
# name. Bazel runs them on macOS alone: elsewhere they are incompatible, so `bazel test //...` skips
# them, where a test binary that ran no tests would fail. SwiftPM still builds them, empty, on Linux.
APPLE_ONLY_TESTS = []

# Test targets that also run in the iOS simulator, by name: tests of a module every platform builds
# that holds code for UIKit alone (`#if canImport(UIKit)`). Each stays in Package.swift and keeps
# its swift_test on the Mac (and Linux), and gains `<name>Simulator`, an ios_unit_test of the same
# test library hosted by tools/test_host, which Bazel runs on macOS alone. A target that depends on
# an iOS module or a Bazel label runs in the simulator alone already and isn't listed. Needs the
# test host and .bazelrc's simulator settings, which the app type, --ios and --simulator ship.
SIMULATOR_TESTS = []

# Environment variables a test target's tests read, by test target name: Bazel runs a test with
# almost none of the caller's environment, so each name listed is handed through to that target's
# runners alone (`env_inherit` on its swift_test, its Performance/ one and its simulator
# ios_unit_test), and only those targets' cached results depend on the variable's value. For an
# integration test that runs only when a variable is set, such as one naming a database the
# developer starts. `--test_env` in .bazelrc would hand it to every test instead. SwiftPM passes the
# whole environment already, so Package.swift is unchanged.
# {"GreetingsTests": ["TEST_DATABASE_URL"]}
TEST_ENVIRONMENT = {}

# The product whose macro generates mocks. A module that depends on it is compiled with the
# MOCKING condition in debug builds only (SwiftPM's debug configuration, Bazel's
# --compilation_mode=dbg), so `@Mockable` emits Mock<Protocol> types for tests and release
# builds carry none.
MOCKING = "mockable/Mockable"

# (name, group, description, dependencies)
MODULES = [
    ("Afluent", "Library", "Reactive operators over async/await: DeferredTask, AsyncSequence operators, subjects and caches.", []),
    ("AfluentTesting", "Testing", "Helpers for testing code built on Afluent: waiting until a condition holds or work is scheduled.", ["Afluent"]),
]

# Modules only iOS builds: SwiftUI views and what they draw with. Bazel builds them for the
# simulator; Package.swift, the umbrella and the docs leave them out, and a module that depends on
# one must be one too. A test target that depends on one, or on a Bazel label (`//tools/...`), runs
# in the simulator as an ios_unit_test, and Package.swift leaves it out as well.
IOS_MODULES = []
IOS_MINIMUM = "18.0"

# Example modules, by name from MODULES: code that shows the library in use (a demo app's views, a
# sample server's routes) rather than part of it. They build and test like any module, but
# Package.swift offers no library product for them, and the umbrella and the docs leave them out,
# so neither they nor their dependencies ship in `import Afluent`. Only executables, test
# targets and other example modules may depend on one.
EXAMPLE_MODULES = []

# Modules offered as products of their own but left out of the umbrella, by name from MODULES:
# ones an adopter imports on purpose rather than with `import Afluent`, such as a test-support
# back end (an in-memory store for their tests). Each keeps its library product, its DocC archive
# and its place in the docs; only the generated umbrella doesn't import it.
NON_UMBRELLA_MODULES = []

# Library modules that import Swift Testing, by name from MODULES: test helpers adopters add to
# their test targets (a custom Trait, an assertion that records an Issue). Bazel finds Testing only
# on the developer search paths, which rules_swift gives testonly targets alone, so these get them
# too (`always_include_developer_search_paths`), as does their symbol graph extraction for the docs.
# Not `testonly`: their docs and anything shipped that depends on them would have to be as well.
# A module that depends on one is one too, and the umbrella leaves them out (NON_UMBRELLA_MODULES),
# so `import Afluent` never needs Testing.
TESTING_MODULES = []

# Resources, by target name: a module from MODULES, a test target from TEST_TARGETS, or the
# <X>PerformanceTests target of one in PERFORMANCE_TESTS. Each is a list of (rule, path), the path
# relative to Sources/<name>, Tests/<name> or Tests/<X>/Performance (a file or a directory), and
# the rule SwiftPM's: "process" flattens the files into the bundle's root (keeping a
# localization's `.lproj`), and processes them on Apple platforms as Xcode does; "copy" keeps the
# entry whole, by its last path component. Package.swift gets `resources: [.process(path),
# .copy(path)]`, and Bazel the same `<PROJECT>_<name>.bundle` and a `Bundle.module` that finds it
# (tools/resources.bzl): in an app's or a test bundle's resources on Apple platforms, in the
# runfiles of `bazel test` and `bazel run` on macOS and Linux. So a module reads its resources
# through `Bundle.module` under either build system, and a test target its fixtures the same way
# (in its swift_test, its simulator ios_unit_test and its SwiftPM test target alike).
# Apple's privacy manifest is ("copy", "PrivacyInfo.xcprivacy"), at the bundle's root where Apple
# reads it: a module holding one must list it. Firmware modules have none: Embedded Swift has no
# Foundation and no bundles.
# {"Greetings": [("process", "Data/greetings.json"), ("copy", "PrivacyInfo.xcprivacy")],
#  "GreetingsTests": [("copy", "Fixtures")], "GreetingsPerformanceTests": [("copy", "Fixtures")]}
RESOURCES = {}

# Swift sources a generator writes at build time: {module or test target: [(name, generator label,
# input labels, output names)]}. Bazel compiles the generator's output, so it never goes stale
# there; SwiftPM can't run the generator, so it compiles a checked-in copy, at
# <target directory>/Generated/<name>.swift, or with output names Generated/<name>/<output>.swift
# for each. `just sources` refreshes the copies, and <name>_test fails while one differs from what
# the generator writes (tools/generated_sources.bzl). The generator gets the inputs' paths as
# arguments; with no output names it writes the one source to standard output, with them it gets
# the outputs' paths first, before a `--`. Simulated benchmarks stage the generator's output at the
# copy's path (tools/benchmarks.bzl).
# {"Greetings": [("Phrases", "//tools/phrases", ["//Sources/Greetings:phrases.txt"], [])]}
GENERATED_SOURCES = {}

# Compiler plugins holding macros: (name, group, description, dependencies), whose dependencies
# are packages' products only (swift-syntax's). A module lists one among its dependencies to offer its
# macros: SwiftPM takes it as a dependency of a `.macro` target, Bazel as a `plugins` entry of a
# swift_compiler_plugin, which rules_swift loads for that module and the modules that depend on it
# directly. A plugin is no library: it has no product, no docs and no place in the umbrella, so the
# module that declares the macros is what adopters import. A test target lists one to test its
# expansions: SwiftPM links the plugin's module into the tests, and Bazel links `<name>Library`,
# the same sources compiled as a library in the test's package, since rules_swift builds a
# test's plugin dependency for the host and loads it as a plugin, not as a module. (In the
# plugin's own package that library's swiftmodule would collide with the plugin's.)
MACROS = []

# SwiftPM command plugins: (name, verb, description, reason), run with `swift package <verb>`.
# Each is a `.plugin` target with a product of the same name, its sources in Plugins/<name>
# (SwiftPM's default). `reason` is why the plugin writes to the package directory, which SwiftPM
# shows when asking for it (`--allow-writing-to-package-directory` grants it up front); None asks
# for no permissions. Bazel builds none of them: PackagePlugin is SwiftPM's alone, so Plugins/ holds
# no BUILD.bazel, and the docs and //:package_swift_test leave them out. Keep a plugin thin, and
# prove it by running it.
PLUGINS = []

# Executables: (name, description, dependencies). Each is an `.executableTarget` and product in
# Package.swift and a swift_binary in Bazel (`bazel run //Sources/<name>`). Keep them thin: the
# code lives in MODULES, where tests can reach it. They are left out of the umbrella and the docs.
EXECUTABLES = [
]

# Test targets. SwiftPM rejects a target with no sources, so list a target only once its directory
# holds tests. (name, dependencies)
TEST_TARGETS = [
    ("AfluentTests", ["Afluent", "AfluentTesting", "ohhttpstubs/OHHTTPStubs", "ohhttpstubs/OHHTTPStubsSwift",
                      "swift-concurrency-extras/ConcurrencyExtras", "swift-clocks/Clocks", "swift-atomics/Atomics", "swiftprng/Generators",
                      "swift-property-based/PropertyBased"]),
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
    "AfluentTests",
]

# Performance tests run up to their one-minute limits each, so their targets get "medium" (300 s).
PERFORMANCE_TEST_SIZE = "medium"

# The tag .bazelrc's release config filters out of builds and tests (see PERFORMANCE_TESTS).
RELEASE_EXCLUDED_TAG = "debug-only"

# The tag every simulator test carries: one unit of the `simulator` resource, of which .bazelrc
# declares one (--local_resources=simulator=1), so simulator tests run one at a time while compiles
# and Mac tests run beside them. Each boots a simulator of its own, and run all at once they swamp
# the machine. Rejected: `exclusive`, which also runs each alone but after every other action, so
# the run turns serial.
SIMULATOR_TEST_TAG = "resources:simulator:1"

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

# The Swift the project builds with. SWIFT is the floor: every manifest's swift-tools-version, CI's
# swift:<SWIFT> and swift-bazel:<SWIFT>-<bazel> images, the Docker image's base and the minimum the
# docs state. SWIFT_TOOLCHAIN is the swift.org release swiftly installs where Xcode's toolchain falls
# short.
# just wasi-test builds with it and its WebAssembly SDK.
# To raise the floor, change both and run `just modules`: it writes them into the generated
# manifests and replaces the previous ones in SWIFT_SITES. CI needs a swift-bazel image of the new
# version (the project template's ci-image/build.sh publishes them).
SWIFT = "6.4"
SWIFT_TOOLCHAIN = "6.4.3"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The files that name SWIFT or SWIFT_TOOLCHAIN besides the ones generated here, as globs from the
# root; each is also looked for under templates/<piece>/, where the project template keeps the
# optional pieces' files. A missing one is skipped.
SWIFT_SITES = [
    "Fuzz/Package.swift", "Explore/Package.swift", "Examples/Package.swift",
    ".github/workflows/*.yml", "Dockerfile", "justfile",
    "scripts/wasi_test.py", "scripts/fuzz.py", "Explore/build.sh", "tools/embedded-swift", "tools/swift_rules.bzl",
    "README.md", "AGENTS.md", ".github/README.md", ".github/docs/*.md", "Fuzz/README.md", "Explore/README.md", "Examples/README.md",
]


def swift_version_bzl():
    return (
        '"""GENERATED by scripts/modules.py (SWIFT, SWIFT_TOOLCHAIN) — edit them there, then run `just modules`."""\n\n'
        "# The Swift versions the files in SWIFT_SITES name: the next `just modules` replaces these there\n"
        "# when scripts/modules.py declares others.\n"
        f'SWIFT = "{SWIFT}"\n'
        f'SWIFT_TOOLCHAIN = "{SWIFT_TOOLCHAIN}"\n'
    )


def recorded_swift(root):
    """The (SWIFT, SWIFT_TOOLCHAIN) that tools/swift_version.bzl under `root` records, or None."""
    path = os.path.join(root, "tools", "swift_version.bzl")
    if not os.path.isfile(path):
        return None
    with open(path) as file:
        values = dict(re.findall(r'^(SWIFT|SWIFT_TOOLCHAIN) = "([^"]*)"$', file.read(), re.MULTILINE))
    return values.get("SWIFT"), values.get("SWIFT_TOOLCHAIN")


def swift_sites(root):
    paths = set()
    for site in SWIFT_SITES:
        paths.update(glob.glob(os.path.join(root, site)))
        paths.update(glob.glob(os.path.join(root, "templates", "*", site)))
    return sorted(paths)


def replace_swift(root, old, new):
    """Replaces the versions `old` with `new`, both (SWIFT, SWIFT_TOOLCHAIN), in every file of
    SWIFT_SITES under `root`, in one pass, so a replacement is never matched again. A version matches
    only whole, never inside a longer one (1.2 isn't replaced in 1.2.3 or 11.2).

    Returns the paths it changed."""
    replacements = {o: n for o, n in zip(old, new) if o and n and o != n}
    if not replacements:
        return []
    versions = "|".join(re.escape(o) for o in sorted(replacements, key=len, reverse=True))
    pattern = re.compile(rf"(?<![\w.])(?:{versions})(?!\w|\.\d)")
    changed = []
    for path in swift_sites(root):
        with open(path) as file:
            text = file.read()
        replaced = pattern.sub(lambda match: replacements[match.group(0)], text)
        if replaced != text:
            with open(path, "w") as file:
                file.write(replaced)
            changed.append(path)
    return changed


def performance_target(name):
    """The speed-reliant target split from test target `name`: FlowsTests -> FlowsPerformanceTests."""
    return name.removesuffix("Tests") + "PerformanceTests"


def duplicate_definitions():
    """The top-level names this file assigns or defines more than once, sorted.

    A template update merges a table the template adds (`MACROS = []`) as a clean insertion even
    when the project already defines it elsewhere in the file, and the later assignment wins, so
    the check reads the source rather than the values.
    """
    with open(__file__) as file:
        tree = ast.parse(file.read())
    counts = collections.Counter()
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            counts[node.name] += 1
        elif isinstance(node, ast.Assign):
            counts.update(target.id for target in node.targets if isinstance(target, ast.Name))
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            counts[node.target.id] += 1
    return sorted(name for name, count in counts.items() if count > 1)


# Apple's privacy manifest, which a module that calls a required-reason API or collects data ships
# at the root of its resource bundle (RESOURCES).
PRIVACY_MANIFEST = "PrivacyInfo.xcprivacy"


def performance_parent(name):
    """The PERFORMANCE_TESTS target whose speed-reliant target is `name`, or None."""
    return next((test for test in PERFORMANCE_TESTS if performance_target(test) == name), None)


def resources_directory(name):
    """Where RESOURCES' paths for target `name` start: Tests/<X>/Performance for X's speed-reliant
    target, Tests/<name> for a test target, else Sources/<name>."""
    if performance_parent(name):
        return f"Tests/{performance_parent(name)}/Performance"
    return f"Tests/{name}" if name in [t[0] for t in TEST_TARGETS] else f"Sources/{name}"


def resources_target(name):
    """The name of target `name`'s module_resources call in its package's BUILD.bazel: a
    speed-reliant target's sits in its test target's package, beside that one's."""
    return "PerformanceResources" if performance_parent(name) else "Resources"


def check_resources(names):
    """RESOURCES names modules by `names`, test targets or their speed-reliant targets, each entry a
    "process" or "copy" of a path that exists under the target, none listed twice or inside
    another, a test target's none under Performance/; and a module holding a privacy manifest
    lists it."""
    tests = [t[0] for t in TEST_TARGETS]
    for name, entries in RESOURCES.items():
        if name.endswith("PerformanceTests") and name not in names + tests:
            assert performance_parent(name), \
                f"RESOURCES names {name}, but no test target in PERFORMANCE_TESTS has a speed-reliant target of that name"
        else:
            assert name in names or name in tests, f"RESOURCES names {name}, which is neither a module nor a test target"
        directory = resources_directory(name)
        paths = [path for _, path in entries]
        for rule, path in entries:
            assert rule in ("process", "copy"), f"RESOURCES gives {directory}/{path} the rule {rule!r}: use \"process\" or \"copy\""
            assert path == os.path.normpath(path) and not os.path.isabs(path) and not path.startswith(".."), \
                f"RESOURCES lists {path!r} for {name}: give a path inside {directory}, without ./, ../ or a trailing /"
            assert os.path.exists(os.path.join(ROOT, directory, path)), \
                f"RESOURCES lists {directory}/{path}, which doesn't exist"
            assert not (name in tests and (path == "Performance" or path.startswith("Performance/"))), \
                f"RESOURCES lists {directory}/{path}, in the speed-reliant tests' directory, which the test target leaves out"
            assert paths.count(path) == 1, f"RESOURCES lists {directory}/{path} more than once"
            outer = [other for other in paths if path.startswith(other + "/")]
            assert not outer, f"RESOURCES lists {directory}/{path} inside {directory}/{outer[0]}, which it lists too"
    for name in names:
        if os.path.isfile(os.path.join(ROOT, "Sources", name, PRIVACY_MANIFEST)):
            assert PRIVACY_MANIFEST in [path for _, path in RESOURCES.get(name, [])], (
                f"Sources/{name} holds a {PRIVACY_MANIFEST} that RESOURCES doesn't list, so it would ship in no bundle: "
                f"add (\"copy\", \"{PRIVACY_MANIFEST}\") to RESOURCES[\"{name}\"]")


def generated_copies(name):
    """The checked-in copies of target `name`'s generated sources (GENERATED_SOURCES), each path
    relative to the target's directory."""
    return [f"Generated/{source}/{out}.swift" for source, _, _, outs in GENERATED_SOURCES.get(name, []) for out in outs] \
        + [f"Generated/{source}.swift" for source, _, _, outs in GENERATED_SOURCES.get(name, []) if not outs]


def check_generated_sources(names, tests):
    for name, sources in GENERATED_SOURCES.items():
        assert name in names + tests, f"GENERATED_SOURCES names {name}, which is neither a module nor a test target"
        assert name not in PERFORMANCE_TESTS, \
            f"GENERATED_SOURCES names {name}, whose Performance/ target would compile the copies: generate them into a module"
        assert name not in IOS_MODULES, f"GENERATED_SOURCES names the iOS module {name}, which only the simulator builds"
        assert sources, f"GENERATED_SOURCES gives {name} no sources: list at least one, or leave {name} out"
        given = [source for source, _, _, _ in sources]
        assert len(given) == len(set(given)), f"GENERATED_SOURCES names a source of {name} twice"
        for source, generator, _, outs in sources:
            assert re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", source), \
                f"GENERATED_SOURCES gives {name} the source {source!r}, which isn't a Bazel target's plain name"
            assert generator.startswith("//") or generator.startswith(":"), \
                f"GENERATED_SOURCES gives {source} the generator {generator!r}, which isn't a Bazel label"
            assert len(outs) == len(set(outs)), f"GENERATED_SOURCES names an output of {source} twice"
        directory = ("Sources/" if name in names else "Tests/") + name
        for copy in generated_copies(name):
            assert os.path.isfile(os.path.join(ROOT, directory, copy)), (
                f"GENERATED_SOURCES declares {directory}/{copy}, SwiftPM's copy, which doesn't exist: create it "
                "(an empty file will do), then `just modules` and `just sources`")


def generated_bazel(name):
    """Target `name`'s generated sources in its BUILD.bazel (GENERATED_SOURCES): the load and the
    generated_swift_source calls, or nothing."""
    sources = GENERATED_SOURCES.get(name, [])
    if not sources:
        return "", ""
    rules = ""
    for source, generator, inputs, outs in sources:
        inputs_attr = "    srcs = [\n" + "".join(f'        "{i}",\n' for i in inputs) + "    ],\n" if inputs else ""
        outs_attr = "    outs = [\n" + "".join(f'        "{o}",\n' for o in outs) + "    ],\n" if outs else ""
        copy = f"Generated/{source}/" if outs else f"Generated/{source}.swift"
        rules += (
            f"# {copy} is SwiftPM's copy (GENERATED_SOURCES in scripts/modules.py); Bazel compiles the\n"
            "# generator's output, and `just sources` refreshes the copy.\n"
            f'generated_swift_source(\n    name = "{source}",\n    generator = "{generator}",\n{inputs_attr}{outs_attr}'
            f'    tags = ["{RELEASE_EXCLUDED_TAG}"],\n)\n\n'
        )
    return 'load("//tools:generated_sources.bzl", "generated_swift_source")\n', rules


def swift_srcs(name, pattern='glob(["**/*.swift"])'):
    """The `srcs` expression of target `name`'s sources: with generated sources (GENERATED_SOURCES),
    the generators' outputs in place of the checked-in copies under Generated/."""
    sources = GENERATED_SOURCES.get(name, [])
    if not sources:
        return pattern
    return pattern[:-1] + ', exclude = ["Generated/**"])' + " + [" + ", ".join(f'":{s}"' for s, _, _, _ in sources) + "]"


def check():
    names = [m[0] for m in MODULES]
    # A plugin is a dependency like a module, but no list of modules below may name one.
    plugins = macro_names()
    assert len(names + plugins) == len(set(names + plugins)), "duplicate module"
    for name in APPLE_ONLY_TESTS:
        assert name in dict(TEST_TARGETS), f"APPLE_ONLY_TESTS names unknown test target {name}"
    for name in SIMULATOR_TESTS:
        assert name in dict(TEST_TARGETS), f"SIMULATOR_TESTS names unknown test target {name}"
        assert not simulator_only(name), \
            f"{name} depends on an iOS module or a Bazel label, so it runs in the simulator alone already: leave it out of SIMULATOR_TESTS"
    for name, variables in TEST_ENVIRONMENT.items():
        assert name in dict(TEST_TARGETS), f"TEST_ENVIRONMENT names unknown test target {name}"
        assert variables, f"TEST_ENVIRONMENT gives {name} no variables: list at least one, or leave {name} out"
        for variable in variables:
            assert re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", variable), \
                f"TEST_ENVIRONMENT gives {name} {variable!r}, which isn't an environment variable's name"
            assert variables.count(variable) == 1, f"TEST_ENVIRONMENT lists {variable} for {name} more than once"
    # The root BUILD.bazel leaves iOS modules out of the docs and //:package_swift_test through
    # tools/ios.bzl, which only the app type, --ios and --simulator write.
    assert not IOS_MODULES, (
        "IOS_MODULES needs tools/ios.bzl, the iOS test host and the simulator settings the app type, --ios "
        "and --simulator ship: from the project template's checkout, ./template.py add <project> --ios for "
        "an iOS app, or --simulator for the modules and their tests alone")
    simulator_tests = sorted(name for name, _ in TEST_TARGETS if simulator_test(name))
    if simulator_tests:
        with open(os.path.join(ROOT, ".bazelrc")) as file:
            settings = "--local_resources=simulator=" in file.read()
        assert os.path.isfile(os.path.join(ROOT, "tools", "test_host", "BUILD.bazel")) and settings, (
            f"{', '.join(simulator_tests)} run in the iOS simulator (SIMULATOR_TESTS, or a dependency on an iOS "
            "module or a Bazel label), which needs the test host (tools/test_host) and the simulator settings "
            "in .bazelrc (--ios_minimum_os, --ios_simulator_device, --ios_simulator_version, "
            "--local_resources=simulator=1) that the app type, --ios and --simulator ship: from the project "
            "template's checkout, ./template.py add <project> --simulator (or --ios, for an iOS app too)")
    packages = [p[0] for p in PACKAGES]
    for name, _, version in PACKAGES:
        if version.startswith("range:"):
            lower, upper = version_range(version)
            assert "..<" in version and semantic_version(lower) and semantic_version(upper), (
                f"PACKAGES gives {name} {version!r}: write a range as range:<lower>..<<upper>, two versions "
                "such as range:603.0.0..<605.0.0")
            assert semantic_version(lower) < semantic_version(upper), \
                f"PACKAGES gives {name} {version!r}, whose lower bound isn't below its upper"
    for name in NON_WASI_PACKAGES:
        assert name in packages, f"NON_WASI_PACKAGES names unknown package {name}"
        assert name not in APPLE_ONLY_PACKAGES, f"{name} is Apple-only, which already leaves WASI out"
    for name, deps in [(m[0], m[3]) for m in MODULES + MACROS] + [(e[0], e[2]) for e in EXECUTABLES]:
        for d in deps:
            if "/" in d:
                assert d.split("/")[0] in packages, f"{name} depends on unknown package {d}"
            else:
                assert d in names + plugins, f"{name} depends on unknown {d}"
    for name, _, _, deps in MACROS:
        assert all("/" in d for d in deps), f"the plugin {name} may depend on packages only"
    executables = [e[0] for e in EXECUTABLES]
    assert not set(executables) & set(names + plugins + [PROJECT]), "an executable shares a module's name"
    tests = [t[0] for t in TEST_TARGETS]
    assert len(tests) == len(set(tests)), "duplicate test target"
    for name, deps in TEST_TARGETS:
        for d in deps:
            if d.startswith("//"):
                continue
            if "/" in d:
                assert d.split("/")[0] in packages, f"{name} depends on unknown package {d}"
            else:
                assert d in names + plugins + [PROJECT, TEST_SUPPORT], f"{name} depends on unknown {d}"
        assert not (simulator_test(name) and any(is_macro(d) for d in deps)), \
            f"{name} tests a compiler plugin, which only tests on the Mac can link"
    # A command plugin shares SwiftPM's namespace of targets and products.
    taken = {**{t: "a test target" for t in tests + [TEST_SUPPORT]}, **{e: "an executable" for e in executables},
             **{m: "a macro" for m in plugins}, **{m: "a module" for m in names + [PROJECT]}}
    commands = [p[0] for p in PLUGINS]
    assert len(commands) == len(set(commands)), "duplicate command plugin"
    verbs = [p[1] for p in PLUGINS]
    assert len(verbs) == len(set(verbs)), "two command plugins share a verb"
    for name, _, _, _ in PLUGINS:
        assert name not in taken, f"the command plugin {name} has the name of {taken.get(name)}"
        assert glob.glob(os.path.join(ROOT, "Plugins", name, "**", "*.swift"), recursive=True), \
            f"the command plugin {name} has no Swift sources in Plugins/{name}"
    for name in PERFORMANCE_TESTS:
        assert name in tests, f"PERFORMANCE_TESTS names unknown test target {name}"
        assert not simulator_test(name), f"{name} runs in the simulator, which PERFORMANCE_TESTS doesn't support"
    for name in IOS_MODULES:
        assert name in names, f"IOS_MODULES names unknown module {name}"
    for name in EXAMPLE_MODULES:
        assert name in names, f"EXAMPLE_MODULES names unknown module {name}"
    for name in NON_UMBRELLA_MODULES:
        assert name in names, f"NON_UMBRELLA_MODULES names unknown module {name}"
        assert name != PROJECT and umbrella(), f"NON_UMBRELLA_MODULES lists {name}, but the package has no umbrella to leave it out of"
        assert name not in EXAMPLE_MODULES, f"{name} is an example module, which the umbrella already leaves out"
        assert name not in IOS_MODULES, f"{name} is an iOS module, which the umbrella already leaves out"
    for name, _, _, deps in MODULES:
        if name not in EXAMPLE_MODULES:
            for d in deps:
                assert d not in EXAMPLE_MODULES, f"{name} depends on the example module {d}, so it must be in EXAMPLE_MODULES"
    for name, _, _, deps in MODULES:
        if name not in IOS_MODULES:
            for d in deps:
                assert d not in IOS_MODULES, f"{name} depends on the iOS module {d}, so it must be in IOS_MODULES"
    for name in TESTING_MODULES:
        assert name in names, f"TESTING_MODULES names unknown module {name}"
        assert name not in IOS_MODULES, f"{name} is an iOS module, which the app ships, so it can't import Testing"
        assert not umbrella() or name in NON_UMBRELLA_MODULES + EXAMPLE_MODULES, \
            f"{name} imports Testing, so the umbrella must leave it out: list it in NON_UMBRELLA_MODULES"
    for name, _, _, deps in MODULES:
        if name not in TESTING_MODULES:
            for d in deps:
                assert d not in TESTING_MODULES, f"{name} depends on {d}, which imports Testing, so it must be in TESTING_MODULES"
    for name, _, deps in EXECUTABLES:
        for d in deps:
            assert d not in TESTING_MODULES, f"the executable {name} depends on {d}, which imports Testing, a test-only library"
    check_resources(names)
    check_generated_sources(names, tests)
    for name, deps in BENCHMARKS:
        for d in deps:
            assert d in names or (d == PROJECT and umbrella()), f"benchmark {name} imports unknown module {d}"
            assert d not in EXAMPLE_MODULES, f"benchmark {name} imports the example module {d}, which has no product"


def macro_names():
    """The compiler plugins' names (MACROS)."""
    return [m[0] for m in MACROS]


def is_macro(d):
    """Whether dependency `d` names a compiler plugin (MACROS)."""
    return d in macro_names()


def simulator_only(name):
    """Whether test target `name` runs in the iOS simulator alone: it depends on an iOS module or a Bazel
    label, so Package.swift leaves it out."""
    deps = dict(TEST_TARGETS)[name]
    return any(d in IOS_MODULES or d.startswith("//") for d in deps)


def simulator_test(name):
    """Whether test target `name` runs in the iOS simulator: alone, or on the Mac too (SIMULATOR_TESTS)."""
    return name in SIMULATOR_TESTS or simulator_only(name)


def simulator_label(name):
    """The ios_unit_test that runs simulator test target `name`: the package's own target, or
    `<name>Simulator` beside the Mac tests for one in SIMULATOR_TESTS."""
    return f"//Tests/{name}" + (f":{name}Simulator" if name in SIMULATOR_TESTS else "")


def spm_dep(d):
    if "/" in d:
        package, product = d.split("/")
        condition = (", condition: .when(platforms: applePlatforms)" if package in APPLE_ONLY_PACKAGES
                     else ", condition: .when(platforms: nonWASIPlatforms)" if package in NON_WASI_PACKAGES else "")
        return f'.product(name: "{product}", package: "{package}"{condition})'
    return f'"{d}"'


def requirement(version):
    """A package's version requirement in a manifest: `from:` the minimum, `exact:` a pinned release,
    `.upToNextMinor(from:)` for `minor:`, patch releases only, or a half-open range
    (`"603.0.0"..<"605.0.0"`) for `range:603.0.0..<605.0.0`. check() refuses a malformed range."""
    if version.startswith("exact:"):
        return f'exact: "{version.removeprefix("exact:")}"'
    if version.startswith("minor:"):
        return f'.upToNextMinor(from: "{version.removeprefix("minor:")}")'
    if version.startswith("range:"):
        lower, upper = version_range(version)
        return f'"{lower}"..<"{upper}"'
    return f'from: "{version}"'


def version_range(version):
    """The (lower, upper) bounds of a `range:<lower>..<<upper>` version, as written."""
    lower, _, upper = version.removeprefix("range:").partition("..<")
    return lower, upper


def semantic_version(text):
    """`text`'s (major, minor, patch) when it is a semantic version (a pre-release or build suffix
    allowed), else None."""
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", text)
    return tuple(int(part) for part in match.groups()) if match else None


def umbrella():
    """Whether the package has a generated umbrella module: unless MODULES lists the project's name."""
    return PROJECT not in [m[0] for m in MODULES]


def package_modules():
    """MODULES that Package.swift declares: every one but the iOS modules."""
    return [m for m in MODULES if m[0] not in IOS_MODULES]


def library_modules():
    """MODULES that the package offers as products and the umbrella imports: every one Package.swift
    declares but the example modules."""
    return [m for m in package_modules() if m[0] not in EXAMPLE_MODULES]


def umbrella_modules():
    """MODULES the generated umbrella imports: every library product but NON_UMBRELLA_MODULES."""
    return [m for m in library_modules() if m[0] not in NON_UMBRELLA_MODULES]


def package_tests():
    """TEST_TARGETS that Package.swift declares: every one but those run in the simulator alone."""
    return [t for t in TEST_TARGETS if not simulator_only(t[0])]


def package_dependencies():
    """PACKAGES that Package.swift declares: those a target it declares uses, or every one when no
    module is iOS-only. A package only iOS modules and simulator tests use is Bazel's alone
    (swift/Package.swift), as SwiftPM warns about a dependency no target uses."""
    if not IOS_MODULES:
        return PACKAGES
    used = {d.split("/")[0] for _, deps in [(m[0], m[3]) for m in package_modules() + MACROS] + [(e[0], e[2]) for e in EXECUTABLES] + package_tests()
            for d in deps if "/" in d and not d.startswith("//")}
    return [p for p in PACKAGES if p[0] in used]


def apple_only(d):
    return "/" in d and d.split("/")[0] in APPLE_ONLY_PACKAGES


def bazel_deps(deps, testing=False, ios=False):
    """A `deps` attribute, or nothing when there are none; Apple-only products sit in a macOS `select`,
    but for a target only iOS builds (`ios`), which lists them with the rest.
    A compiler plugin (MACROS) goes in a `plugins` attribute instead, but for a test library
    (`testing`), which links the plugin's `<name>Library` in its own package (see MACROS)."""
    if testing:
        return _bazel_deps([f":{d}Library" if is_macro(d) else d for d in deps], ios)
    plugins = "".join(f'        "{bazel_label(d)}",\n' for d in deps if is_macro(d))
    return _bazel_deps([d for d in deps if not is_macro(d)]) + (f"    plugins = [\n{plugins}    ],\n" if plugins else "")


# The Apple operating systems Bazel's platforms name, for APPLE_ONLY_PACKAGES' select.
APPLE_OSES = ["macos", "ios", "tvos", "watchos", "visionos"]


def _bazel_deps(deps, ios=False):
    if not deps:
        return ""
    listed = "".join(f'        "{bazel_label(d)}",\n' for d in deps if ios or not apple_only(d))
    text = f"    deps = [\n{listed}    ]"
    apple = "".join(f'            "{bazel_label(d)}",\n' for d in deps if not ios and apple_only(d))
    if apple:
        # Every Apple OS, as Package.swift's applePlatforms: a module built for the simulator (an iOS
        # module's dependency, a SIMULATOR_TESTS target) would otherwise compile out, without an
        # error, the code it holds under `#if canImport` of these products.
        keys = "".join(f'        "@platforms//os:{os_name}": [\n{apple}        ],\n' for os_name in APPLE_OSES)
        text += (
            " + select({\n"
            "        # Apple-only packages (APPLE_ONLY_PACKAGES in scripts/modules.py).\n"
            f"{keys}"
            '        "//conditions:default": [],\n'
            "    })"
        )
    return text + ",\n"


def bazel_label(d):
    if d.startswith("//") or d.startswith(":"):
        return d
    if "/" in d:
        package, product = d.split("/")
        return f"@swiftpkg_{package.replace('-', '_')}//:{product}"
    if d == TEST_SUPPORT:
        return f"//Tests/{TEST_SUPPORT}"
    return f"//Sources/{d}"


def excluded(path):
    """Non-source files SwiftPM would otherwise warn about, for the target at `path`."""
    return [f for f in ("BUILD.bazel", "README.md", "Performance", "__Snapshots__") if os.path.exists(os.path.join(ROOT, path, f))]


def swift_string(text):
    """`text` as a Swift string literal."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def resources_arg(name):
    """Target `name`'s `resources:` argument in Package.swift (RESOURCES), or nothing."""
    entries = RESOURCES.get(name, [])
    if not entries:
        return ""
    return ", resources: [" + ", ".join(f".{rule}({swift_string(path)})" for rule, path in entries) + "]"


def resources_bazel(name):
    """Target `name`'s resources in its BUILD.bazel (RESOURCES): the load, the swift_library's `srcs`
    and `data`, and the module_resources call (tools/resources.bzl). Without resources, the plain
    `srcs` and nothing else."""
    entries = RESOURCES.get(name, [])
    if not entries:
        return "", f"    srcs = {swift_srcs(name)},\n", "", ""
    what = ("speed-reliant tests' fixtures" if performance_parent(name)
            else "tests' fixtures" if resources_directory(name).startswith("Tests/") else "module's resources")
    target = resources_target(name)
    # The speed-reliant target's SwiftPM path is the package's Performance/, which its entries are
    # relative to.
    directory = '    directory = "Performance",\n' if performance_parent(name) else ""
    lists = "".join(
        f"    {rule} = [\n" + "".join(f'        "{path}",\n' for r, path in entries if r == rule) + "    ],\n"
        for rule in ("process", "copy") if any(r == rule for r, _ in entries)
    )
    return (
        'load("//tools:resources.bzl", "module_resources", "module_resources_data")\n',
        '    # `Bundle.module`, as SwiftPM generates it, for the resources below.\n'
        f'    srcs = {swift_srcs(name)} + [":{target}Accessor"],\n',
        f'    data = module_resources_data("{target}"),\n',
        f"\n# The {what} (RESOURCES in scripts/modules.py), in the bundle SwiftPM builds for them.\n"
        "module_resources(\n"
        f'    name = "{target}",\n'
        f'    bundle_name = "{PROJECT}_{name}",\n'
        f'    bundle_id = "{PROJECT.lower()}.{name}.resources",\n'
        f"{directory}"
        f"{lists}"
        ")\n",
    )


def exclude_arg(path):
    files = excluded(path)
    if files == ["BUILD.bazel"]:
        return ", exclude: bazelFiles"
    if files:
        return ", exclude: [" + ", ".join(f'"{f}"' for f in files) + "]"
    return ""


def exit_test_files(directory, excludes):
    """Swift files under `directory` (outside `excludes`) holding an exit test, as a Swift array literal."""
    root = os.path.join(ROOT, directory)
    found = []
    for folder, _, files in sorted(os.walk(root)):
        for file in sorted(files):
            rel = os.path.relpath(os.path.join(folder, file), root)
            if not file.endswith(".swift") or any(rel.startswith(e) for e in excludes):
                continue
            with open(os.path.join(folder, file), encoding="utf-8") as f:
                if "processExitsWith" in f.read():
                    found.append(rel)
    return "[" + ", ".join(f'"{f}"' for f in found) + "]"


def package_swift():
    lines = [
        f"// swift-tools-version: {SWIFT}",
    ] + (["import CompilerPluginSupport"] if MACROS else []) + [
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
        f"// The WebAssembly test run (scripts/wasi_test.py) sets {PROJECT.upper()}_WASI_TESTS to a comma-separated",
        "// list of test targets: the package then declares only those, as one binary of every target",
        "// can pass wasmtime's limit of a million functions, and leaves out each test file with an exit",
        "// test, since WASI cannot start a child process. Unset, nothing changes.",
        f'let wasiTests = Context.environment["{PROJECT.upper()}_WASI_TESTS"].map {{ Set($0.split(separator: ",").map(String.init)) }}',
        "",
        "func testExcludes(_ excludes: [String], wasi exitTestFiles: [String]) -> [String] {",
        "    wasiTests == nil ? excludes : excludes + exitTestFiles",
        "}",
        "",
    ]
    if APPLE_ONLY_PACKAGES:
        lines += [
            "// Where the Apple-only packages' products are linked (APPLE_ONLY_PACKAGES in scripts/modules.py).",
            "let applePlatforms: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS]",
            "",
        ]
    if NON_WASI_PACKAGES:
        lines += [
            "// Where the packages that don't build for WebAssembly have their products linked: every",
            "// platform but WASI (NON_WASI_PACKAGES in scripts/modules.py).",
            "let nonWASIPlatforms: [Platform] = [",
            "    .macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS, .driverKit,",
            "    .linux, .windows, .android, .openbsd,",
            "]",
            "",
        ]
    lines += [
        "// Typed arrays of their own: as one `Package(...)` expression, a large manifest is too big for",
        "// the type checker.",
        "let products: [Product] = [",
    ]
    if umbrella():
        lines.append(f'    .library(name: "{PROJECT}", targets: ["{PROJECT}"]),')
    lines += [f'    .library(name: "{m[0]}", targets: ["{m[0]}"]),' for m in library_modules()]
    lines += [f'    .executable(name: "{e[0]}", targets: ["{e[0]}"]),' for e in EXECUTABLES]
    lines += [f'    .plugin(name: "{p[0]}", targets: ["{p[0]}"]),' for p in PLUGINS]
    lines += ["]", "", "let dependencies: [Package.Dependency] = ["]
    lines += [f'    .package(url: "{url}", {requirement(version)}),' for _, url, version in package_dependencies()]
    lines += ["]", "", "let targets: [Target] = ["]
    group = None
    for name, g, _, deps in package_modules():
        if g != group:
            lines.append(f"    // {g}")
            group = g
        ex = exclude_arg(f"Sources/{name}")
        settings = ', swiftSettings: [.define("MOCKING", .when(configuration: .debug))]' if MOCKING in deps else ""
        resources = resources_arg(name)
        if deps:
            dl = ", ".join(spm_dep(d) for d in deps)
            lines.append(f'    .target(name: "{name}", dependencies: [{dl}]{ex}{resources}{settings}),')
        else:
            lines.append(f'    .target(name: "{name}"{ex}{resources}),')
    for name, g, _, deps in MACROS:
        lines.append(f"    // {g}: compiler plugin")
        dl = ", ".join(spm_dep(d) for d in deps)
        lines.append(f'    .macro(name: "{name}", dependencies: [{dl}]{exclude_arg(f"Sources/{name}")}),')
    if EXECUTABLES:
        lines += ["", "    // Executables"]
    for name, _, deps in EXECUTABLES:
        dl = ", ".join(spm_dep(d) for d in deps)
        lines.append(f'    .executableTarget(name: "{name}", dependencies: [{dl}]{exclude_arg(f"Sources/{name}")}),')
    if PLUGINS:
        lines += ["", "    // Command plugins (PLUGINS in scripts/modules.py), which Bazel doesn't build"]
    for name, verb, description, reason in PLUGINS:
        intent = f".custom(verb: {swift_string(verb)}, description: {swift_string(description)})"
        permissions = "" if reason is None else f", permissions: [.writeToPackageDirectory(reason: {swift_string(reason)})]"
        lines.append(f'    .plugin(name: "{name}", capability: .command(intent: {intent}{permissions}){exclude_arg(f"Plugins/{name}")}),')
    all_deps = ", ".join(f'"{m[0]}"' for m in umbrella_modules())
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
    for name, deps in package_tests():
        dl = ", ".join(spm_dep(d) for d in deps)
        files = excluded(f"Tests/{name}")
        ex = "[" + ", ".join(f'"{f}"' for f in files) + "]" if files != ["BUILD.bazel"] else "bazelFiles"
        lines.append(f'    .testTarget(name: "{name}", dependencies: [{dl}], exclude: testExcludes({ex}, wasi: {exit_test_files(f"Tests/{name}", files)}){resources_arg(name)}),')
    if PERFORMANCE_TESTS:
        lines += [
            "",
            "    // Speed-reliant tests, split from the target of the same module (PERFORMANCE_TESTS in scripts/modules.py).",
        ]
        for name, deps in TEST_TARGETS:
            if name in PERFORMANCE_TESTS:
                dl = ", ".join(spm_dep(d) for d in deps)
                lines.append(f'    .testTarget(name: "{performance_target(name)}", dependencies: [{dl}], path: "Tests/{name}/Performance", exclude: testExcludes([], wasi: {exit_test_files(f"Tests/{name}/Performance", [])}){resources_arg(performance_target(name))}),')
    lines += [
        "]",
        "",
        "let package = Package(",
        f'    name: "{PROJECT}",',
        "    // Keep in step with .bazelrc's --macos_minimum_os.",
        f"    platforms: {PLATFORMS},",
        "    products: products,",
        "    dependencies: dependencies,",
        "    targets: targets.filter { $0.type != .test || wasiTests?.contains($0.name) ?? true }",
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


def build_bazel(name, description, deps, linked=()):
    """A module's BUILD.bazel. `linked` names modules its catalog links to without importing them:
    their archives join its docs' dependencies alone."""
    resources_load, srcs_attr, data_attr, resources = resources_bazel(name)
    generated_load, generated = generated_bazel(name)
    deps_attr = bazel_deps(deps)
    defines_attr = (
        "    # Mock<Protocol> types from @Mockable, in debug builds only (MOCKING in scripts/modules.py).\n"
        '    defines = select({"//tools:debug": ["MOCKING"], "//conditions:default": []}),\n'
    ) if MOCKING in deps else ""
    testing_attr = (
        "    # Imports Testing, found on the developer search paths (TESTING_MODULES in scripts/modules.py).\n"
        "    always_include_developer_search_paths = True,\n"
    ) if name in TESTING_MODULES else ""
    if name in IOS_MODULES:
        return (
            "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
            f"{resources_load}"
            'load("//tools:swift_rules.bzl", "swift_library")\n\n'
            f"# {description}\n"
            "# iOS only (IOS_MODULES in scripts/modules.py): built for the simulator through the app and the\n"
            "# simulator tests, skipped by `bazel build //...` on the Mac.\n"
            "swift_library(\n"
            f'    name = "{name}",\n'
            f"{srcs_attr}"
            f"{data_attr}"
            f'    module_name = "{name}",\n'
            f"{defines_attr}"
            f"{deps_attr}"
            '    target_compatible_with = ["@platforms//os:ios"],\n'
            '    visibility = ["//visibility:public"],\n'
            ")\n"
            f"{resources}"
        )
    if name in EXAMPLE_MODULES:
        return (
            "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
            f"{generated_load}"
            f"{resources_load}"
            'load("//tools:swift_rules.bzl", "swift_library")\n\n'
            f"{generated}"
            f"# {description}\n"
            "# An example (EXAMPLE_MODULES in scripts/modules.py): no product, umbrella import or docs.\n"
            "swift_library(\n"
            f'    name = "{name}",\n'
            f"{srcs_attr}"
            f"{data_attr}"
            f'    module_name = "{name}",\n'
            f"{defines_attr}"
            f"{deps_attr}"
            f"{testing_attr}"
            '    visibility = ["//visibility:public"],\n'
            ")\n"
            f"{resources}"
        )
    doc_deps = "".join(f'        "{bazel_label(d)}:{d}Documentation",\n' for d in [*deps, *linked] if "/" not in d and not is_macro(d))
    doc_deps_attr = f"    deps = [\n{doc_deps}    ],\n" if doc_deps else ""
    docs_testing_attr = "    always_include_developer_search_paths = True,\n" if name in TESTING_MODULES else ""
    return (
        "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
        'load("//tools:docc.bzl", "docc_archive")\n'
        f"{generated_load}"
        f"{resources_load}"
        'load("//tools:swift_rules.bzl", "swift_library")\n\n'
        f"{generated}"
        f"# {description}\n"
        "swift_library(\n"
        f'    name = "{name}",\n'
        f"{srcs_attr}"
        f"{data_attr}"
        f'    module_name = "{name}",\n'
        f"{defines_attr}"
        f"{deps_attr}"
        f"{testing_attr}"
        '    visibility = ["//visibility:public"],\n'
        ")\n"
        f"{resources}"
        "\n"
        "# The module's DocC archive, merged into //:docs. `manual` keeps it out of `bazel build //...`.\n"
        "docc_archive(\n"
        f'    name = "{name}Documentation",\n'
        f'    module = ":{name}",\n'
        '    catalog = glob(["*.docc/**"], allow_empty = True),\n'
        f"{doc_deps_attr}"
        f"{docs_testing_attr}"
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


def macro_build_bazel(name, description, deps):
    return (
        "# GENERATED by scripts/modules.py — edit MACROS there, then run `just modules`.\n\n"
        'load("//tools:swift_rules.bzl", "swift_compiler_plugin")\n\n'
        f"# {description}\n"
        "swift_compiler_plugin(\n"
        f'    name = "{name}",\n'
        '    srcs = [":srcs"],\n'
        f'    module_name = "{name}",\n'
        f"{bazel_deps(deps)}"
        '    visibility = ["//visibility:public"],\n'
        ")\n\n"
        "# The sources, which the plugin's tests also compile as a library (MACROS in scripts/modules.py).\n"
        "filegroup(\n"
        '    name = "srcs",\n'
        '    srcs = glob(["**/*.swift"]),\n'
        '    visibility = ["//Tests:__subpackages__"],\n'
        ")\n"
    )


def macro_library_bazel(name):
    """The testonly library of plugin `name`'s sources that a test package links (see MACROS)."""
    deps = dict((m[0], m[3]) for m in MACROS)[name]
    return (
        f"# {name}'s sources as a library of the same module, for these tests to link (MACROS in\n"
        "# scripts/modules.py). Its `@main` entry point is renamed, as swift_compiler_plugin renames\n"
        "# the plugin's, so it doesn't clash with the test runner's.\n"
        "swift_library(\n"
        f'    name = "{name}Library",\n'
        "    testonly = True,\n"
        f'    srcs = ["//Sources/{name}:srcs"],\n'
        f'    module_name = "{name}",\n'
        "    copts = [\n"
        '        "-Xfrontend",\n'
        '        "-entry-point-function-name",\n'
        '        "-Xfrontend",\n'
        f'        "{name}_main",\n'
        "    ],\n"
        f'    tags = ["{RELEASE_EXCLUDED_TAG}"],\n'
        f"{bazel_deps(deps)}"
        ")\n\n"
    )


def macros_bzl():
    packages = "".join(f'    "Sources/{name}",\n' for name in macro_names())
    return (
        '"""GENERATED by scripts/modules.py (MACROS) — edit the table there, then run `just modules`."""\n\n'
        "# The source packages that hold a compiler plugin rather than a library: the root BUILD.bazel\n"
        "# leaves them out of the docs and the products.\n"
        f"MACRO_PACKAGES = [\n{packages}]\n"
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


def env_inherit_attr(name):
    """The `env_inherit` line for test target `name`'s runners (TEST_ENVIRONMENT), or nothing."""
    variables = TEST_ENVIRONMENT.get(name)
    if not variables:
        return ""
    return "    env_inherit = [" + ", ".join(f'"{v}"' for v in variables) + "],\n"


def test_targets_bazel(name, deps, size, srcs, tags, simulator=False, environment=None):
    """One test module: its library, the swift_test that `bazel test` runs, and the Xcode bundle; with
    `simulator`, the ios_unit_test that runs the same library in the simulator too (SIMULATOR_TESTS).
    `environment` names the TEST_ENVIRONMENT entry its runners inherit, `name` by default."""
    env_attr = env_inherit_attr(environment or name)
    tags_attr = f"    tags = {tags},\n".replace("'", '"') if tags else ""
    # SnapshotTesting finds a reference beside the test file through #filePath, which Bazel makes
    # relative to the workspace, and a test runs from its runfiles: so the references go in them.
    # A test target's fixtures (RESOURCES) are a bundle of their own, found by `Bundle.module`.
    resources = bool(RESOURCES.get(name))
    srcs += f' + [":{resources_target(name)}Accessor"]' if resources else ""
    data = (['glob(["__Snapshots__/**"], allow_empty = True)'] if "swift-snapshot-testing/SnapshotTesting" in deps else []) \
        + ([f'module_resources_data("{resources_target(name)}")'] if resources else [])
    data_attr = f"    data = {' + '.join(data)},\n" if data else ""
    compatible_attr = ('    target_compatible_with = select({\n'
                       '        # APPLE_ONLY_TESTS in scripts/modules.py: nothing to run elsewhere.\n'
                       '        "@platforms//os:macos": [],\n'
                       '        "//conditions:default": ["@platforms//:incompatible"],\n'
                       '    }),\n'
                       if name in APPLE_ONLY_TESTS else "")
    return (
        "swift_library(\n"
        f'    name = "{name}Library",\n'
        "    testonly = True,\n"
        "    # Tests are found through metadata the linker would otherwise drop, since nothing\n"
        "    # references them by name.\n"
        "    alwayslink = True,\n"
        f"    srcs = {srcs},\n"
        f"{data_attr}"
        f'    module_name = "{name}",\n'
        f"{tags_attr}"
        "    # Read by //:package_swift_test, which checks Package.swift against the Bazel graph.\n"
        '    visibility = ["//:__pkg__"],\n'
        f"{bazel_deps(deps, testing=True)}"
        ")\n\n"
        "# `bazel test` / `just test`: a standalone executable, fast to start and run in Bazel's sandbox.\n"
        "swift_test(\n"
        f'    name = "{name}",\n'
        f"{env_attr}"
        f'    size = "{size}",\n'
        f"{tags_attr}"
        f"{compatible_attr}"
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
    ) + (simulator_half_bazel(name, deps, srcs, tags, env_attr) if simulator else "")


def simulator_half_bazel(name, deps, srcs, tags, env_attr):
    """The same tests as test target `name`'s library, built for iOS and run in the simulator as well
    (SIMULATOR_TESTS): a library of their own, without the Mac's snapshot references, which
    rules_apple would flatten into the bundle as resources, but with its fixtures' bundle (RESOURCES),
    which it nests; and the ios_unit_test."""
    tags_attr = f"    tags = {tags},\n".replace("'", '"') if tags else ""
    data_attr = '    data = module_resources_data("Resources"),\n' if RESOURCES.get(name) else ""
    return (
        "\n# The same tests in the iOS simulator (SIMULATOR_TESTS in scripts/modules.py), where the code\n"
        "# under `#if canImport(UIKit)` compiles. iOS only, so `bazel build //...` builds it through the\n"
        "# bundle below alone.\n"
        "swift_library(\n"
        f'    name = "{name}SimulatorLibrary",\n'
        "    testonly = True,\n"
        "    alwayslink = True,\n"
        f"    srcs = {srcs},\n"
        f"{data_attr}"
        f'    module_name = "{name}",\n'
        f"{tags_attr}"
        '    target_compatible_with = ["@platforms//os:ios"],\n'
        f"{bazel_deps(deps, testing=True, ios=True)}"
        ")\n\n"
        # rules_apple's default runner, with no pre-action to uninstall the host as the UI
        # tests' has (tools/ui_test). It reuses a booted simulator and installs over the earlier
        # install, keeping files whose size and time match, but the host never changes and the
        # test bundle is installed fresh on every run: same-size changes to a test and to the
        # module under test both ran on the next run.
        "# Run inside the test host (tools/test_host), which gives windows a scene.\n"
        f"# `{SIMULATOR_TEST_TAG}` runs one simulator test at a time (.bazelrc).\n"
        "ios_unit_test(\n"
        f'    name = "{name}Simulator",\n'
        # rules_apple's runner hands the simulator only the variables listed here.
        f"{env_attr}"
        f'    size = "{TEST_SIZES.get(name, "medium")}",\n'
        f'    minimum_os_version = "{IOS_MINIMUM}",\n'
        "    tags = [\n" + "".join(f'        "{t}",\n' for t in tags + [SIMULATOR_TEST_TAG]) + "    ],\n"
        "    # The simulator is the Mac's alone, so elsewhere `bazel test //...` skips the bundle.\n"
        "    target_compatible_with = select({\n"
        '        "@platforms//os:macos": [],\n'
        '        "//conditions:default": ["@platforms//:incompatible"],\n'
        "    }),\n"
        '    test_host = "//tools/test_host",\n'
        '    visibility = ["//visibility:public"],\n'
        f'    deps = [":{name}SimulatorLibrary"],\n'
        ")\n"
    )


def simulator_test_build_bazel(name, deps, size):
    """A test module run in the iOS simulator: its library, its snapshot references, its fixtures
    (RESOURCES) and the ios_unit_test."""
    resources_load, srcs_attr, _, resources = resources_bazel(name)
    generated_load, generated = generated_bazel(name)
    data_attr = ('    data = [":Snapshots"] + module_resources_data("Resources"),\n' if resources
                 else '    data = [":Snapshots"],\n')
    return (
        "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
        'load("@rules_apple//apple:ios.bzl", "ios_unit_test")\n'
        'load("@rules_apple//apple:resources.bzl", "apple_resource_bundle")\n'
        f"{generated_load}"
        f"{resources_load}"
        'load("//tools:swift_rules.bzl", "swift_library")\n\n'
        f"{generated}"
        "# The tests, run in the iOS simulator: the target depends on an iOS module (IOS_MODULES in\n"
        f"# scripts/modules.py). Tagged `{RELEASE_EXCLUDED_TAG}`, like every target but the speed-reliant ones.\n"
        "swift_library(\n"
        f'    name = "{name}Library",\n'
        "    testonly = True,\n"
        f"{srcs_attr}"
        f"{data_attr}"
        f'    module_name = "{name}",\n'
        f'    tags = ["{RELEASE_EXCLUDED_TAG}"],\n'
        '    target_compatible_with = ["@platforms//os:ios"],\n'
        f"{bazel_deps(deps)}"
        ")\n\n"
        "# The snapshot references under __Snapshots__, which the tests read from their bundle\n"
        "# (tools/snapshots; `just record-snapshots` rewrites them).\n"
        "apple_resource_bundle(\n"
        '    name = "Snapshots",\n'
        "    testonly = True,\n"
        '    structured_resources = glob(["__Snapshots__/**"], allow_empty = True),\n'
        f'    tags = ["{RELEASE_EXCLUDED_TAG}"],\n'
        ")\n\n"
        # The default runner, with no uninstall: simulator_half_bazel says why.
        "# `bazel test` and the generated Xcode project both run this bundle in the simulator, inside the\n"
        "# test host (tools/test_host), which gives windows a scene.\n"
        f"# `{SIMULATOR_TEST_TAG}` runs one simulator test at a time (.bazelrc).\n"
        "ios_unit_test(\n"
        f'    name = "{name}",\n'
        f"{env_inherit_attr(name)}"
        f'    size = "{size}",\n'
        f'    minimum_os_version = "{IOS_MINIMUM}",\n'
        f'    tags = [\n        "{RELEASE_EXCLUDED_TAG}",\n        "{SIMULATOR_TEST_TAG}",\n    ],\n'
        "    # The simulator is the Mac's alone, so elsewhere `bazel test //...` skips the bundle.\n"
        "    target_compatible_with = select({\n"
        '        "@platforms//os:macos": [],\n'
        '        "//conditions:default": ["@platforms//:incompatible"],\n'
        "    }),\n"
        '    test_host = "//tools/test_host",\n'
        '    visibility = ["//visibility:public"],\n'
        f'    deps = [":{name}Library"],\n'
        ")\n"
        f"{resources}"
    )


def test_build_bazel(name, deps):
    size = TEST_SIZES.get(name, "small")
    if simulator_only(name):
        # Booting a simulator takes much of a minute on its own.
        return simulator_test_build_bazel(name, deps, TEST_SIZES.get(name, "medium"))
    simulator = name in SIMULATOR_TESTS
    resources_load, _, _, resources = resources_bazel(name)
    performance_load, _, _, performance_resources = resources_bazel(performance_target(name)) if name in PERFORMANCE_TESTS else ("", "", "", "")
    resources_load = resources_load or performance_load
    generated_load, generated = generated_bazel(name)
    header = (
        "# GENERATED by scripts/modules.py — edit the table there, then run `just modules`.\n\n"
        + ('load("@rules_apple//apple:ios.bzl", "ios_unit_test")\n' if simulator else "")
        + 'load("@rules_apple//apple:macos.bzl", "macos_unit_test")\n'
        + generated_load
        + resources_load
        + 'load("//tools:swift_rules.bzl", "swift_library", "swift_test")\n\n'
        + generated
    )
    excluded_note = (
        f"Tagged `{RELEASE_EXCLUDED_TAG}`: none of these relies on speed, so\n"
        "# `--config=release` neither builds nor runs them (.bazelrc).\n"
    )
    header += "".join(macro_library_bazel(d) for d in deps if is_macro(d))
    if name not in PERFORMANCE_TESTS:
        return (header + "# The tests, built once and linked into two runners.\n# " + excluded_note
                + test_targets_bazel(name, deps, size, swift_srcs(name), [RELEASE_EXCLUDED_TAG], simulator)
                + resources)
    return (
        header
        + "# The tests, built once and linked into two runners; the speed-reliant ones, in Performance/, are\n"
        + f"# {performance_target(name)} below. " + excluded_note
        + test_targets_bazel(name, deps, size, 'glob(["**/*.swift"], exclude = ["Performance/**"])', [RELEASE_EXCLUDED_TAG], simulator)
        + "\n# The speed-reliant tests (PERFORMANCE_TESTS in scripts/modules.py): debug and `--config=release`\n"
        + "# both run them.\n"
        + test_targets_bazel(performance_target(name), deps, PERFORMANCE_TEST_SIZE, 'glob(["Performance/**/*.swift"])', [],
                             environment=name)
        + resources
        + performance_resources
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


def examples_bzl():
    packages = "".join(f'    "Sources/{name}",\n' for name in EXAMPLE_MODULES)
    return (
        '"""GENERATED by scripts/modules.py (EXAMPLE_MODULES) — edit the table there, then run `just modules`."""\n\n'
        "# The source packages of example modules, which have no DocC archive: the root BUILD.bazel\n"
        "# leaves them out of the docs.\n"
        f"EXAMPLE_PACKAGES = [\n{packages}]\n"
    )


def library_directories():
    """Every non-test target directory the root Package.swift declares."""
    directories = [f"Sources/{m[0]}" for m in package_modules()] + [f"Sources/{e[0]}" for e in EXECUTABLES] + [f"Sources/{name}" for name in macro_names()]
    directories += [f"Plugins/{p[0]}" for p in PLUGINS]
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
        f"// swift-tools-version: {SWIFT}\n"
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
    duplicates = duplicate_definitions()
    if duplicates:
        sys.exit(f"scripts/modules.py defines {', '.join(duplicates)} more than once (a template update "
                 "can merge a second copy in); keep one, holding this project's rows, and delete the other")
    check()
    # Before the record is rewritten: it names the versions the sites hold now.
    for path in replace_swift(ROOT, recorded_swift(ROOT) or (SWIFT, SWIFT_TOOLCHAIN), (SWIFT, SWIFT_TOOLCHAIN)):
        if not path.endswith(".yml"):
            continue
        with open(path) as file:
            if "WASM_SDK_SHA256" in file.read():
                # A checksum can't be derived from the version; swift.org publishes it with the SDK.
                print(f"{os.path.relpath(path, ROOT)}: WASM_SDK_URL now names Swift {SWIFT_TOOLCHAIN}'s WebAssembly SDK; "
                      "set WASM_SDK_SHA256 to its checksum (swift.org's install page lists it)", file=sys.stderr)
    write(os.path.join(ROOT, "tools", "swift_version.bzl"), swift_version_bzl())
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
    for name, _, description, deps in MACROS:
        write(os.path.join(ROOT, "Sources", name, "BUILD.bazel"), macro_build_bazel(name, description, deps))
    write(os.path.join(ROOT, "Tests", TEST_SUPPORT, "BUILD.bazel"), test_support_build_bazel())
    write(os.path.join(ROOT, "tools", "executables.bzl"), executables_bzl())
    write(os.path.join(ROOT, "tools", "examples.bzl"), examples_bzl())
    write(os.path.join(ROOT, "tools", "macros.bzl"), macros_bzl())
    write(os.path.join(ROOT, "tools", "performance_tests.bzl"), performance_tests_bzl())
    names = [m[0] for m in umbrella_modules()]
    if umbrella():
        directory = os.path.join(ROOT, "Sources", PROJECT)
        write(os.path.join(directory, "BUILD.bazel"), build_bazel(PROJECT, f"Umbrella: `import {PROJECT}` imports every module.", names,
                                                             # The landing catalog may link a module left out of the umbrella.
                                                             linked=NON_UMBRELLA_MODULES))
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
