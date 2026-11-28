# Macros

Add a macro: its compiler plugin is a row in `MACROS` (name, group, description, and as
dependencies swift-syntax's products, with `swift-syntax` in `PACKAGES`, and modules), its sources
in `Sources/<Plugin>/` (an `@main` `CompilerPlugin` listing the macro types), then `just modules`
and `just resolve`. The module that declares the macros (`#externalMacro(module: "<Plugin>",
type: ...)`) lists the plugin among its dependencies: Package.swift gets a `.macro` target, Bazel
a `swift_compiler_plugin` in that module's `plugins`. The plugin has no product, docs or umbrella
import; adopters import the declaring module, and build swift-syntax with it (seconds in debug,
minutes in release). Unless the macro is the package's main job, the declaring module is its own
module in `NON_UMBRELLA_MODULES`, so adopters who don't use the macro never build swift-syntax.
A macro takes swift-syntax as a range of majors, `range:<lower>..<<upper>` in `PACKAGES`
(`range:602.0.0..<604.0.0`). A plain minimum admits one major, and two packages that need
different majors can't be used together in one graph, so list every major the plugin builds
with. When a new major ships and the plugin builds and passes its tests on it, widen the upper
bound and release. Where the API differs between majors, keep the older one and branch on the
empty marker module swift-syntax ships for each release up to its own
(`#if canImport(SwiftSyntax603)`); a feature only a newer major supports sits under that check.
Bazel and CI build only the version `swift/Package.resolved` pins (usually the newest in range),
so test the lower bound after a change to the plugin and before raising it: set the row to
`exact:<lower>`, run `just modules`, `just resolve` and `just test`, then restore the range and
resolve again. A test target that lists the plugin tests
its expansions (`assertMacroExpansion` from `SwiftSyntaxMacrosGenericTestSupport`, with
`Issue.record` as its failure handler); one that lists the declaring module tests the expanded
code. A source that must not compile (a macro's diagnostic as the compiler reports it) is a
`swift_compile_failure_test` (`tools/compile_failure_test.bzl`) in `Tests/CompileFailures`, a
hand-written BUILD.bazel no Package.swift target holds, with a control that compiles.
`copts` type-checks a fixture under the flags of the target it stands for
(`["-default-isolation", "MainActor"]`), and `error_count` pins how many errors it reports.
Expansion code that several plugins share (the package's own and adopters' `.macro` targets)
lives in a library module in `MODULES` that the plugins list among their dependencies; it keeps
its product, so adopters' plugins can depend on it. It runs inside the compiler (SwiftPM builds it
for the host as well, Bazel in the exec configuration), so `check()` refuses one that is an iOS
module, in `TESTING_MODULES`, or reaches a plugin through its own dependencies, and a plugin that
depends on another plugin. A plugin that an example module uses, or that depends on one, goes
in `EXAMPLE_MODULES` too.
