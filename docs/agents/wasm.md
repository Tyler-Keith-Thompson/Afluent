# 32-bit `Int` (WebAssembly)

watchOS's arm64_32 and wasm32 have a 32-bit `Int`. `just wasi-test` (`scripts/wasi_test.py`)
builds the SwiftPM test targets with `swift build --build-tests --swift-sdk
swift-6.4.3-RELEASE_wasm` through swiftly into `.build/wasm`, then runs each test binary (one
`<Target>-test-runner.wasm` per target, or an older toolchain's one `<Project>PackageTests.xctest`)
with `wasmtime run --dir . --dir <checkout>::<checkout> --argv0 <binary's path> <binary>
--testing-library swift-testing`, logs in `.build/wasm/logs`. The checkout at its own path and the
binary's path as `argv[0]` are where SwiftPM's `Bundle.module` looks for a module's resource bundle
(an absolute build path with the `.xctest`, beside `Bundle.main` with the per-target runners, which
WASI's Foundation takes from `argv[0]`). `-c release` builds with `-enable-testing`, so suites that
`@testable import` build in release too. A `--targets` name that isn't a test target is refused
before anything builds, and a group fails when its build wrote no runner for one of its targets.
Needs swiftly's 6.4.3 toolchain, its WebAssembly SDK (`swift sdk list`; swift.org's "Getting
Started with Swift SDKs for WebAssembly" has the install command) and `brew install wasmtime`. If
the toolchain crashes on the manifest against a newer Xcode's SDK, pass `--xcode
/Applications/Xcode-<older>.app`.

- One binary of every target can pass wasmtime's limit of a million functions, so targets run in
  groups (`<PROJECT>_WASI_TESTS`, the project's name in capitals, makes `Package.swift` declare
  only those).
- Not run on WASI: files with exit tests (no child processes; the manifest leaves them out), and
  anything needing threads or Dispatch (`#if canImport(Dispatch)`). `//:package_swift_test` fails
  when a target's `wasi: [...]` list names a file that no longer holds an exit test, or misses one
  that does; run `just modules` after adding, renaming or deleting one.
- WASI runs every task on one thread, and a sleep that is cancelled still holds it until its
  deadline. In parallel, one test's sleep stalls the tasks another is waiting on, so
  `just wasi-test` passes `--serial` (Swift Testing's `--no-parallel`). A time limit's timer is
  such a sleep: run one at a time, each would cost its whole limit, so
  `Tests/AfluentTests/TestHelpers/TimeLimitOnWASI.swift` turns `.timeLimit` off there. The script
  then fails a run on a runner's exit code and on any issue, a time limit's included (one means
  that overload stopped winning), where the template's copy excuses time limits. These three
  (`--serial`, the overload, the stricter failure in `group_failed`) are Afluent's own; keep them
  on `just template-update`. A test that sleeps on the real clock while waiting on other work sits
  under `#if !os(WASI)`; one that cancels a real-clock sleep waits it out, which is one more reason
  code takes its clock from `Container` and tests advance a `TestClock`.
- Without wasm tail calls, an await that doesn't suspend deepens both stacks. The script links a
  64 MB stack and gives wasmtime a 256 MB one, enough for a 10,000-deep chain of such awaits; a
  deeper one traps or hangs on WASI alone.
- Foundation on WASI drops the last character of a resource's file name when the lookup names a
  subdirectory: `Bundle.module.url(forResource: "sample", withExtension: "txt", subdirectory:
  "Fixtures")` returns `Fixtures/sample.tx`, which doesn't exist, and so do
  `path(forResource:ofType:inDirectory:)`, `urls(forResourcesWithExtension:subdirectory:)` and a
  name holding the directory. Look up the directory itself, then append the file:
  `Bundle.module.url(forResource: "Fixtures", withExtension: nil)?.appending(path: "sample.txt")`.
- A dependency that doesn't build for WASI (NIOPosix and what sits on it) fails the whole build.
  List its package in `NON_WASI_PACKAGES` (`scripts/modules.py`), and put the code and tests that
  use it under `#if canImport(<its module>)`.
