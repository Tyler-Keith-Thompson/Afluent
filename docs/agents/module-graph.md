# Changing the module graph

How to add each kind of target or package to `scripts/modules.py`. After any change:
`just modules`, `just test` (which runs `//:package_swift_test`) and `just spm`.

## Modules and test targets

- Add a module: a row in `MODULES` (name, group, description, dependencies), then `just modules`.
- Add a test target: a row in `TEST_TARGETS`. A target with a `Performance/` directory of Swift
  sources must be listed in `PERFORMANCE_TESTS`, and the reverse.
- Run a test target in the iOS simulator as well (the tests of a module every platform builds that
  holds code under `#if canImport(UIKit)`): its name in `SIMULATOR_TESTS`, then `just modules`. It
  stays in Package.swift and keeps its run on the Mac and Linux, and gains
  `//Tests/<Target>:<Target>Simulator`, an `ios_unit_test` of the same tests inside
  `tools/test_host`, which `just test` runs on a Mac and Linux skips. Its UIKit tests sit under
  `#if canImport(UIKit)`, and its exit tests under `#if !os(iOS)`, as iOS has none. At least one
  test must run on the Mac, since Bazel's runner fails a run of none; a target whose Mac tests are
  Apple's alone goes in `APPLE_ONLY_TESTS` too. A target that depends on an iOS module or a Bazel
  label runs in the simulator alone already, so it isn't listed. A target in `PERFORMANCE_TESTS`
  too takes only its debug tests into the simulator; its `Performance/` tests stay on the Mac and
  Linux. A target that runs in the simulator alone can't be in `PERFORMANCE_TESTS`.
  It needs the test host and the simulator settings in `.bazelrc`, which the app type and the
  `--simulator` and `--ios` options ship (`just modules` refuses the table without them).
  From the project template's checkout, `./template.py add <project> --simulator` brings them
  without an app.
- Add an iOS app to this project: from the project template's checkout,
  `./template.py add <project> --ios` (after `just template-update`, if the stamp predates the
  option). It brings `Apps/Afluent`, the test host, the simulator settings and `tools/ios.bzl`;
  until then `just modules` refuses `IOS_MODULES` and simulator tests.
- Give a test target an environment variable under `bazel test` (an integration test that runs
  only when `TEST_DATABASE_URL` is set, say): its name and the variables in `TEST_ENVIRONMENT`
  (`{"<Target>Tests": ["TEST_DATABASE_URL"]}`), then `just modules`. Bazel strips the test
  environment; the generator writes the names as `env_inherit` on that target's `swift_test`, its
  Performance one and its simulator `ios_unit_test`, so only those targets see the variable and
  only their cached results depend on it. Not `--test_env` in `.bazelrc`, which hands it to every
  test. SwiftPM passes the whole environment already. `check()` refuses a name that isn't a test
  target.
- Compile a target with a Swift language feature (`@_extern(c)` needs `Extern` on Swift 6.4): the
  module or test target's name and the features in `EXPERIMENTAL_FEATURES` or `UPCOMING_FEATURES`
  (`{"<Module>": ["Extern"]}`), then `just modules`. Package.swift gets
  `.enableExperimentalFeature` or `.enableUpcomingFeature` in the target's `swiftSettings`, beside
  MOCKING's define, and never `unsafeFlags`, which would stop other packages depending on this
  one. Bazel gets the matching `-enable-experimental-feature` or `-enable-upcoming-feature` in
  `copts`,
  and `//:package_swift_test` fails while the two disagree. A test target's speed-reliant target
  takes its features. Only the target named compiles with them, so a module that uses one in its
  implementation alone asks nothing of its dependents. `check()` refuses a name that isn't a module
  or test target, and a feature listed twice or under both tables. A release compiler refuses an
  experimental feature that isn't available in production, so build with Xcode's toolchain after
  adding one.
- Add an executable: a row in `EXECUTABLES` (name, description, dependencies). It holds only
  `@main`; its code lives in a module, where tests reach it.
- Add an example module (a demo app's views, a sample server's routes): a row in `MODULES` and its
  name in `EXAMPLE_MODULES`, then `just modules`. It builds and tests like any module, but has no
  library product, umbrella import or DocC archive, so neither it nor its dependencies ship. Only
  executables, test targets and other example modules may depend on it (`check()` enforces it).
- Offer a module on its own but not through `import Afluent` (a test-support back end, such as
  an in-memory store adopters use in their tests): its name in `NON_UMBRELLA_MODULES` too, then
  `just modules`. It keeps its library product and DocC archive; only the umbrella leaves it out.
  The umbrella catalog's topic list is hand-written: list it there under a heading of its own, not
  among the production modules.
- A library module that imports Swift Testing (a helper adopters add to their test targets: a
  custom `Trait`, an assertion that records an `Issue`): its name in `TESTING_MODULES` and
  `NON_UMBRELLA_MODULES` too, then `just modules`. Bazel finds Testing only on the developer search
  paths, which rules_swift gives testonly targets alone; the generator gives them to its
  `swift_library` and its docs' symbol graph. A module that depends on it must be listed too, and no
  executable may (`check()` enforces both).

## Packages

- Add an external package: a row in `PACKAGES`, its `swiftpkg_<identity>` repository in
  `MODULE.bazel`'s `use_repo`, then `just modules` and `just resolve`.
- Generate mocks: uncomment the Mockable row in `PACKAGES`, add `mockable/Mockable` to the
  module that declares the protocol and to its test target, add `swiftpkg_mockable` to
  `use_repo`, then `just modules` and `just resolve`. The generator defines `MOCKING` for that
  module in debug builds only, in both build systems.
- A package whose main module takes the project's name (`import Afluent` is the library
  itself) lists it in `MODULES`; the generator then writes no umbrella.
- A package only Apple platforms build (Objective-C, a wrapper of an Apple framework) goes in
  `APPLE_ONLY_PACKAGES` too: its products are linked on Apple platforms only, so the targets still
  build on Linux, and the code that uses them sits under `#if canImport(...)`.
- A package that builds everywhere but WebAssembly (one on NIOPosix: Hummingbird, Vapor) goes in
  `NON_WASI_PACKAGES` too: its products are linked on every other platform, so the package still
  builds for wasm32-wasi, and the code that uses them sits under `#if canImport(...)`.
