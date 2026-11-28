# Resources and test fixtures

Give a module resources (data files, Apple's privacy manifest): put them under `Sources/<Module>/`
and list each in `RESOURCES` (`{"<Module>": [("process", "Data/x.json"), ("copy", "Fixtures")]}`,
paths relative to the module, rules as SwiftPM's `.process` and `.copy`), then `just modules`.
Package.swift gets `resources:`, and Bazel the same `Afluent_<Module>.bundle`
(`tools/resources.bzl`): nested in an app's or test bundle's resources on Apple platforms, in the
runfiles of `bazel test` and `bazel run` on macOS and Linux, found by a generated `Bundle.module`.
The module reads them through `Bundle.module` under either build system, and its tests read them
through the module. Bazel processes `process` files only inside Apple bundles (strings, asset
catalogs); elsewhere they are copied as they are, as SwiftPM does off Apple platforms. A module
that calls a required-reason API or collects data ships `PrivacyInfo.xcprivacy`, listed as
`("copy", "PrivacyInfo.xcprivacy")` so it sits at the bundle's root; `check()` refuses one left
out, a listed path that doesn't exist, and one inside another listed directory.

Give a test target fixture files (JSON to compare byte for byte, a sample input): put them under
`Tests/<Target>/` and list them in `RESOURCES` under the target's name
(`{"<Target>": [("copy", "Fixtures")]}`, paths relative to `Tests/<Target>`), then `just modules`.
The target gets its own `Afluent_<Target>.bundle` the same way, in its swift_test, its
simulator ios_unit_test and its SwiftPM test target, and its tests read the files through
`Bundle.module`. Not under `Performance/`, which the target leaves out: the speed-reliant tests
of a `PERFORMANCE_TESTS` target list theirs under `<X>PerformanceTests`, paths relative to
`Tests/<X>/Performance`, and read them through `Bundle.module` in debug and release alike.
