"""First-party Swift rule wrappers.

Every first-party `swift_library` / `swift_test` / `swift_binary` loads from here instead of
`@rules_swift//swift:swift.bzl`. The wrappers flip rules_swift features so our
own code is held to a stricter warnings policy than third-party code:

  * `.bazelrc` enables `swift.suppress_warnings` globally, so swiftc gets
    `-suppress-warnings` and dependencies build without noise.
  * Each first-party target disables that feature and enables
    `swift.treat_warnings_as_errors`, so swiftc gets `-warnings-as-errors`
    for our modules.

Net effect: dependencies build quietly, our own warnings fail the build.
"""

load(
    "@rules_swift//swift:swift.bzl",
    _swift_binary = "swift_binary",
    _swift_library = "swift_library",
    _swift_test = "swift_test",
)

_FIRST_PARTY_FEATURES = [
    "-swift.suppress_warnings",
    "swift.treat_warnings_as_errors",
    # Hands swiftc an exact map of module name to path instead of a list of directories to
    # search. rules_swift otherwise passes one `-I` per Bazel package, so a module could import
    # something it never declared a dependency on, and SwiftPM (which is strict about this)
    # would then fail where Bazel passed.
    "swift.use_explicit_swift_module_map",
    # Tracks each module's .swiftsourceinfo as an output, so //:docs can read source locations
    # from it (see docc.bzl). The file holds absolute paths; nothing but the docs reads it.
    "swift.emit_swiftsourceinfo",
]

# Package.swift uses tools version 6.3, so SwiftPM compiles in the Swift 6 language mode.
# rules_swift defaults to Swift 5, under which concurrency checking differs, so first-party
# targets are pinned to match the published package.
_FIRST_PARTY_COPTS = ["-swift-version", "6"]

# All first-party modules belong to one Swift package. SwiftPM knows this from the manifest;
# Bazel has to be told, or `package` access level and retroactive-conformance checks disagree
# between the two build systems.
_PACKAGE_NAME = "afluent"

def swift_library(name, features = [], copts = [], **kwargs):
    _swift_library(
        name = name,
        features = features + _FIRST_PARTY_FEATURES,
        copts = copts + _FIRST_PARTY_COPTS,
        package_name = _PACKAGE_NAME,
        **kwargs
    )

def swift_test(name, features = [], copts = [], **kwargs):
    _swift_test(
        name = name,
        features = features + _FIRST_PARTY_FEATURES,
        copts = copts + _FIRST_PARTY_COPTS,
        package_name = _PACKAGE_NAME,
        **kwargs
    )

def swift_binary(name, features = [], copts = [], **kwargs):
    _swift_binary(
        name = name,
        features = features + _FIRST_PARTY_FEATURES,
        copts = copts + _FIRST_PARTY_COPTS,
        package_name = _PACKAGE_NAME,
        **kwargs
    )
