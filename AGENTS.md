# Afluent: notes for coding agents

Afluent adds reactive operators to async/await: `DeferredTask` and the `AsynchronousUnitOfWork`
operators for one value, `AsyncSequence` operators, subjects and caches for many, with Combine's
names so code moves from Combine with little change; `AfluentTesting` helps test code built on
it. It is a published library for app and package developers on every Apple platform and Linux.
Development and the published package are on Swift 6.4 and later. Bazel is the development build; SwiftPM is the published package. `README.md` is the user-facing
overview.

This file came from a project template. Sections marked *default* describe how the owner likes
every project built; delete a rule only when it cannot apply here, and say so in the commit.

## Layout

```
Sources/<Module>/                One directory per module, each with a generated BUILD.bazel
Sources/Afluent/             The library: DeferredTask, the operators, subjects, caches, SerialTaskQueue
Plugins/<Plugin>/                SwiftPM command plugins (PLUGINS in scripts/modules.py); Bazel builds none
Tests/<Module>Tests/             One test target per module; Performance/ holds speed-reliant tests
Tests/AfluentTests/          The suite for Afluent and AfluentTesting
Tests/AfluentTestSupport/    Shared test fixtures (data only)
scripts/modules.py               The module graph
tools/                           Bazel rule wrappers (warnings as errors, Swift 6 mode), DocC rules;
                                 tools/bazel (BuildBuddy, sweeping stale output bases)
docs/agents/                     How-tos for one kind of change each, linked from below
.trunk/trunk.yaml                The checks Trunk's merge queue waits for before it merges to main
```

`Benchmarks/` is a separate SwiftPM package (ordo-one/benchmark), generated from `BENCHMARKS` in
`scripts/modules.py`. Bazel builds none of it; `Benchmarks/BUILD.bazel` only caches each target's
simulated counts (`tools/benchmarks.bzl`). See `Benchmarks/README.md`.

### Module graph

`scripts/modules.py` is the source of truth for modules, their dependencies, test targets,
external packages and platforms. `just modules` regenerates `Package.swift`, every `BUILD.bazel`,
the umbrella module and `swift/Package.swift` from it. Never edit the generated files by hand;
`//:package_swift_test` fails when `Package.swift` disagrees with the Bazel graph.
`just modules` refuses a table or function defined twice, as a template update can leave one:
keep the definition holding the project's rows.

- A module name takes a `Module` suffix only when it would otherwise equal its main type's name
  (`GreetingModule` would hold `Greeting`). No catch-all modules ("Core", "Utilities").

Before a change to the graph, read its how-to in `docs/agents/`:

- `module-graph.md`: modules, test targets, executables, external packages and mocks.
- `resources.md`: a module's resources, a test target's fixtures.
- `generated-sources.md`: Swift sources generated at build time.
- `macros.md`: macros and their compiler plugins.
- `plugins.md`: SwiftPM command plugins.
- `swift-version.md`: raising the Swift floor.

## Commands

Every shell command gets a timeout. macOS has no `timeout`; use
`perl -e 'alarm 1800; exec @ARGV' <command>`.

| Command | Does |
|---|---|
| `just build` / `just test` | Build / test everything (debug) |
| `bazel test //Tests/XTests` | One test target (`just test-one //Tests/XTests`) |
| `just filter <pattern>` | Tests whose name matches |
| `just wasi-test [-c release] [--targets X,Y]` | SwiftPM tests on wasm32-wasi under wasmtime: a 32-bit `Int` |
| `just test-release` | `--config=release`: builds and runs only the `XPerformanceTests` targets |
| `just spm-test`, `just verify` | SwiftPM tests; both build systems |
| `just modules` | Regenerate build files from `scripts/modules.py` |
| `just sources` | Rewrite the checked-in copies of generated sources (`GENERATED_SOURCES`) that SwiftPM compiles |
| `just resolve` | Re-resolve Bazel's SwiftPM dependencies after editing `PACKAGES` |
| `just bench [--target X]` | Benchmarks; `just bench-compare` against the `main` baseline |
| `just bench-simulated-compare [--target X]` | Simulated counts (Callgrind in a Linux VM, from `~/workspace/BenchmarkHarness`) against the committed `simulated` baseline; `just bench-simulated [--target X]` re-records it. Both measure only targets whose code changed |
| `just docs` | Combined DocC site into `.build/docs` |
| `just generate` | Xcode project from the Bazel graph, in `xcode/` |
| `just buildbuddy-key`, `just ci-secrets` | Store the BuildBuddy key in the Keychain (once per Mac; builds then use the remote cache); set it as this repository's Actions secret with `gh` |
| `just template-update` | Merge the project template's changes since `.template.json`'s commit; resolve conflicts, then `just modules`, `just test` |
| `bazel query 'rdeps(//Tests/..., //Sources/X)'` | Test targets affected by a change to X |

- Debug is the default configuration. Every test target except the `XPerformanceTests` ones is
  tagged `debug-only`, which `--config=release` filters out.
- A test that bounds wall-clock time, or runs a large input under `.timeLimit`, belongs in
  `Tests/X/Performance/`.
- Release builds use their own output base (see the justfile). Don't create other output bases
  or copies of the repo, and shut down any extra Bazel server you start.
- `tools/load-gate` (a Claude Code hook) holds a command that builds or tests while the machine
  is busy, and says how long it waited. `LOAD_GATE=off` turns it off; its docstring has the rest.
- Run suites through Bazel, not `swift test --filter`.
- First-party warnings are errors (`tools/swift_rules.bzl`); dependencies build quietly. Fix the
  warning, never suppress it. DocC's are too: `just docs` fails on a link that doesn't resolve.
- CI's Bazel jobs run in the project template's `swift-bazel` image: a new `.bazelversion` or
  Swift needs a new tag of it (`docs/agents/swift-version.md`).
- Exit tests (`#expect(processExitsWith:)`) go in files of their own, apart from the other tests:
  builds for platforms that cannot start a child process leave those files out.

### 32-bit `Int` (WebAssembly)

watchOS's arm64_32 and wasm32 have a 32-bit `Int`; `just wasi-test` runs the suites there. Before
changing what runs on WASI, or when a test fails only there, read `docs/agents/wasm.md`: how the
script builds and runs, and what WASI can't do (exit tests, threads, time limits, resource lookups
in subdirectories, packages on NIOPosix). Its time-limit bullet holds Afluent's own WASI changes
(`--serial`, the `.timeLimit` overload, the stricter failure); keep them on `just template-update`.

## Afluent

- **CI is Bazel**, cached by BuildBuddy, with one SwiftPM test job (CI.yml). Compatibility.yml
  adds `bazel test //Platforms` on macOS: Afluent built for each Apple platform at its minimum version
  (`Platforms/BUILD.bazel`, `just platforms`; keep it in step with `PLATFORMS`). Trunk's merge
  queue waits for every job (`.trunk/trunk.yaml`); a job renamed in a workflow is renamed there.
- **OHHTTPStubs** is Objective-C and Apple-only (`APPLE_ONLY_PACKAGES`): tests that use it sit
  under `#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)`.
- **WASI** has no Dispatch, no URLSession and no signals. `QueueExecutor` sits under
  `#if canImport(Dispatch)`, the URLSession additions under
  `#if canImport(Darwin) || canImport(FoundationNetworking)`, and the breakpoint operators trap
  there instead of raising `SIGTRAP` (`debugTrap()`). Tests that use those APIs, Dispatch or
  `Thread` carry the same guards, so `just wasi-test` builds; swift-concurrency-extras has no
  `withMainSerialExecutor` there, and `TestHelpers/MainSerialExecutorOnWASI.swift` stands in.
- **Documentation addresses.** The combined site is at `/Afluent/documentation/<module>/`. Each
  module was once published at `/Afluent/<Module>/documentation/<module>/`;
  `scripts/docs_redirects.sh` writes a redirect at every old address when the DocC workflow
  publishes, so links into the old sites keep working. A new module needs no entry there.
- **Greptile** reviews a pull request once when it opens, and only when asked after that. Its
  findings are inline threads, even beside an approval: answer each one, fix it or say why not,
  and resolve it. After pushing fixes, comment `@greptile review` once per head commit. Batch fixes
  into one push, since each review costs the owner.
- **Tests that move time** use `Tests/AfluentTests/TestHelpers/TrackedTestClock.swift`. Its
  `advance(by:whenSleeping:)` waits until that many sleeps are registered before moving time.
  swift-clocks' `TestClock.advance` only yields a fixed number of times first, so a late sleep
  misses the advance.

## Building blocks

The owner's own libraries come first under "Don't reinvent the wheel" (House rules), before
hand-written code or a third-party package for the same job: Grafluent (graphs and their
algorithms), GrafluentCollections (sorted and prefix-sum collections), SwiftPRNG (seeded
randomness), DependencyInjection and Afluent (async pipelines).
`docs/agents/building-blocks.md` says what each holds, its products and how to add one.

Their conventions carry over: value types, typed errors, tests with Swift Testing.

## Workflow

### Adding a feature

A feature is done when it has all of these. Copy what its sibling features in the module already
have.

1. **Code and docs.** The implementation, with doc comments per "Docs" below. A new module gets a
   row in `scripts/modules.py`, then `just modules`.
2. **Tests** in `Tests/<Module>Tests`:
   - hand-worked cases;
   - edge cases: empty input, one element, the boundaries of every range;
   - every error the code throws, each from the input that causes it;
   - a property test against a naive reference (`swift-property-based`).
3. **A README example**, if the feature changes how the package is introduced, copied verbatim
   into `Tests/AfluentTests`.
4. **A benchmark** in `Benchmarks/Benchmarks/<Module>Benchmarks` (a row in `BENCHMARKS`, then
   `just modules`) where speed matters, starting with a `BASELINE` entry: the hand-written form the code must keep pace with. Measure in
   release, and add a ratio test in `Tests/<Module>Tests/Performance/` where siblings have one.
   Use small inputs in debug builds, because the timing only runs in release.
   Judge a speed change by `just bench-simulated-compare --target <Module>Benchmarks`, and
   re-record the `simulated` baseline it touches (`docs/agents/benchmarks.md`).

Watch for these:

- A closure inside `#expect` nested in another closure can run the wrong body, or crash the
  Linux compiler. Put the body in a nested `func`.
- Hoist literals to typed `let`s rather than writing them inline in `#expect`.
- Iterate dictionary keys sorted wherever order is visible.

### What to run

| Change | Run |
|---|---|
| Any library code | `bazel test` for every target in `bazel query 'rdeps(//Tests/..., //Sources/X)'`, then `just test-release` |
| `scripts/modules.py` | `just modules`, `just test` (which runs `//:package_swift_test`), `just spm` |
| Integer arithmetic that could overflow, or anything platform-conditional | `just wasi-test -c release --targets XTests` (a 32-bit `Int`) |
| `Benchmarks/`, or an API the benchmarks call | `cd Benchmarks && env -u TOOLCHAINS xcrun --toolchain default swift build -c release` |
| A change meant to be faster | `just bench-simulated-compare --target <Module>Benchmarks`, not `just bench-compare` |

### Pushing

Ship finished work yourself; don't wait to be asked, and never end a task with finished work
unmerged. `main` takes changes only through Trunk's merge queue, and every merge releases a patch
version, so ship once per unit of work: each backlog item on a branch of its own, and a request
from outside the backlog on one branch once it is all done.

1. Verify the committed state in a clean worktree: `bazel test //...` in debug, then
   `--config=release`.
2. Push the branch and open a pull request (`gh pr create`). The owner reviews it and queues it
   with a `/trunk merge` comment; that comment is their approval, so never post it yourself.
   Trunk tests it on a `trunk-merge/` branch against the current `main` and merges it once the
   checks `.trunk/trunk.yaml` names pass. If Trunk drops a PR the owner queued for a GitHub-side
   reason (checks stuck as expected, an incident), queue it again.
3. Watch it merge (`gh pr view --json state`), then the Release and DocC workflows to green, and
   fix anything that breaks in a new pull request.
4. Don't add CI steps that rebuild without the owner's approval. A job that must pass before a
   merge goes in `.trunk/trunk.yaml`'s `required_statuses` by its name, and in branch
   protection's required checks.

## House rules

### Code (*default*)

- **Declarative and composable.** Describe what a value is, not the steps that build it. Prefer
  small types and functions that compose (modifiers returning a new value, result builders,
  protocol extensions) over flags, configuration objects and long imperative bodies. A caller
  should be able to read an expression top to bottom and know the result.
- **Don't reinvent the wheel.** If the Swift ecosystem already has it, use it. Before writing a
  data structure, algorithm, parser, concurrency primitive or test tool, look in this order:
  1. The owner's libraries (Building blocks above).
  2. Apple: the standard library and Foundation, then Apple's open-source packages
     (swift-collections, swift-algorithms, swift-async-algorithms, swift-log, swift-nio, …), then
     the platform frameworks where every target, Linux CI included, has them.
  3. Well-maintained community packages (Mockable and swift-property-based are already the
     picks for mocks and property tests).

  Write it yourself only when nothing fits: the package can't support the platforms, can't meet
  a measured performance need, or would pull in far more than the job needs. Say which package
  was rejected and why in the commit message.
- Public types are value types. Mutation returns a new value or is a clearly named `mutating`
  method; no shared mutable state reached through globals.
- Use the standard library's `Atomic`/`Mutex` or swift-atomics for shared state. No hand-rolled
  atomics.
- Names come from established libraries or the literature, familiar programmer terms first.
  Never invent names. No synonym typealiases; one name per concept. Spell names out.
- Delete unused API rather than keeping it.
- Small files, one main type each. Vocabulary a body needs goes in a `fileprivate` extension on
  the type it describes (`extension User { fileprivate func matches(_ term: String) -> Bool }`),
  so the body reads as a sentence.
- No hooks or SPI added only for tests.
- Underscored Swift features (`@_spi`, `_modify`, `@_effects`, `@_exported`) are fine where they
  help. Apple private API is not (undocumented symbols, private selectors or frameworks, anything
  App Review rejects).

### Seams and composition (*default*)

How code that reaches past the process is split: networks, disks, clocks, other services. A pure
library with none of that can skip this section.

- **Layers with one job each.** A transport (HTTP, a file) knows nothing of the domain. A service
  built on it speaks one API. Persistence and features build on services. A module depends only
  on layers below it. Where two modules' models meet, an adapter in the module that imports both
  translates between them, rather than one importing the other. A few lines duplicated across
  modules cost less than coupling them; say so in a comment where it happens.
- **A protocol at every seam.** Anything a test must replace is a protocol marked `@Mockable`.
  Its production conformer is internal and takes the protocol's name with a leading underscore
  (`_SearchService`), so autocomplete offers the protocol. Beside it, a `Factory` on `Container`
  (DependencyInjection) returns it as the protocol, scoped on purpose: `.cached` for one instance
  that holds state, `.shared` for one instance while anyone holds it, unique otherwise. Callers
  resolve it with `@Injected`, `@LazyInjected` or `@ConstructorInjected`, never by naming the
  conformer.
- **The executable is the composition root.** Modules ship working defaults (an in-memory store);
  the executable registers what production swaps in (the store on disk) at startup.
- **Async work is a pipeline of values.** With Afluent, a call returns a lazy unit of work
  (`DeferredTask`) built from operators (`flatMap`, `tryMap`, `decode`, `handleEvents`,
  `tryCatch`, and `shareFromCache` so identical simultaneous requests make one call). Nothing runs
  until `execute()`, so callers compose, retry and cancel it freely.
- **Time is a dependency.** Code that waits, debounces or times out takes a clock registered on
  `Container` (`AnyClock<Duration>`), never an inline `Task.sleep` or `ContinuousClock()`. Tests
  register a `TestClock` (swift-clocks) and advance it.
- **State is an enum of what can be true.** A screen, a response or a load is an enum with a case
  per state (`prompt`, `loading`, `results([User])`, `noResults(String)`, `failed`), mapped once
  from the outcome, not optionals and flags that can disagree.
- **Isolation states its reason.** Mutable state reached from async callers lives in an actor, or
  behind `Mutex` where the hops would cost too much; a comment says which and when to switch.
- **Literals checked at compile time.** A literal URL is `#URL("…")` (the URL macro), not
  `URL(string:)!`. A force unwrap or trap that remains has a comment proving it can't fire and
  why a crash beats a thrown error no caller could handle.
- **Logging.** A type that logs has one `private static let logger`: swift-log's
  `Logger(label: "<module>.<Type>")`, or `os.Logger(subsystem:category:)` in Apple-only code,
  keeping user data private. Levels: `debug` a path taken, `info` a notable event, `notice` a
  degraded result (cached data served), `error` a failure; cancellation is not a failure. Tests
  don't pin logs.

### Tests (*default*)

- Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`). Never XCTest.
- Each test is self-contained and portable: no assertion or setup helpers, not DRY; a test
  copied to another file still works. Shared fixture data in `AfluentTestSupport` is tolerated;
  shared assertions are not.
- Test names state the rule they pin ("An empty name throws EmptyName").
- **Sociable.** A test runs the real code under test and its real collaborators wherever they are
  fast and deterministic, and mocks only the seams that reach out (network, disk, clock) or that
  it must steer. Inside `withTestContainer { }`, `Container.x.useProduction()` resolves the real
  subject; its seams get mocks.
- **Shape.** Arrange; then act on `sut`; then assert, with a blank line between. Name the values
  `expected…` and `actual`. Where the call itself is the rule, `verify(mock)` pins it:
  `.called(.once)`, or `.called(.never)` for one that must not happen.
- **Deterministic concurrency.** Never sleep to let something happen. Order concurrent work with
  gates the test opens (a stub that awaits a `SingleValueSubject` the test sends), advance a
  `TestClock`, and run main-actor tests under `withMainSerialExecutor` (swift-concurrency-extras).
  A suite that awaits carries `.timeLimit(.minutes(1))`, so a hang fails rather than stalls.
- **Unhappy paths.** Every failure a seam can produce (a timeout, no network, a malformed
  response, a missing resource) has a test of what the caller sees.
- Tests may call underscored and `package` API.
- Test doubles come from [Mockable](https://github.com/Kolos65/Mockable): mark the protocol at the
  seam `@Mockable` and use the generated `Mock<Protocol>` (`given`, `when`, `verify`), registered
  in the test's `withTestContainer { }`, never a hand-written double. Mocks exist only in debug
  builds, so a `PerformanceTests` target never uses one.
- Property tests use swift-property-based (`import PropertyBased`, `propertyCheck`).
- Randomized tests are seeded so a failure reproduces from its seed alone: a SwiftPRNG generator
  drawn through its platform-stable `uniform(in:)`, `integer(in:)` and `bernoulli(_:)`, never the
  standard library's `random(in:using:)`, whose answers may change between Swift releases.

### Docs (*default*)

- Describe the current API. No history ("previously", "renamed"), design debates, comparisons
  with other libraries, or benchmark numbers in doc comments or READMEs. Complexity bounds are
  fine.
- Doc comments: a one-line summary, then parameters, return value, complexity, and what traps or
  throws.
- `//` comments say why, where the code makes a choice a reader would question: the data
  structure, an actor over a `Mutex`, deliberate duplication, a force unwrap, the package rejected
  and when it would become the right one. Doc comments describe the API; these record decisions. A
  comment that restates the code is deleted.
- The README's examples are tests (`Tests/AfluentTests`).
- The README is the front page: what the project is, how to install or run it, one short example,
  and links. Everything else (guides, every option, reference) goes in the DocC catalogs, which
  the README links to. A section that grows past a screen moves out there.
- Run prose docs (READMEs, DocC articles, doc comments, this file and `docs/agents/`) through the
  `humanizer` skill (`/humanizer`) before committing them; not code, `//` comments, commit
  messages or backlog items.

### Git (*default*)

- Commit message style: `[main] - <summary>`, no trailers (no co-author or session lines).
- One commit per finished feature or fix, after its suites pass.
- Never file bugs with third-party projects; record them locally.

## API conventions (*default*)

### Errors

- **Everything that can fail throws** a typed, payload-free error from its one spelling
  (`Greeting(name:)` throws `EmptyName`). There are no second throwing spellings, no nil-returning
  variants and no traps that can fire at run time; `try?` gives `nil`. Spellings that trap, each
  with a throwing twin, suit only a benchmarked library whose API runs in its callers' hot loops
  (graphs, collections, numeric kernels), which the project template renders with
  `--performance`; its README says when that fits. Anywhere else, and wherever input comes from
  users, the network or files, keep throwing: a caller can ignore an error, but not a crash.
- **Invariant-breaking mutations throw on the plain spelling** and change nothing, with one typed
  error per invariant whose cases make a single `catch` exhaustive.
- **Queries whose failure is the answer return a witness** (`findCycle() -> Cycle?`), not an
  error.

### Shapes

- Results are dedicated types, not tuples.
- Lazy views end in `View`; the materialized form drops the suffix.
- Materializing operations are static factories on a target the caller picks.
