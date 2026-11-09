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
Sources/Afluent/             Umbrella module (@_exported imports) and the landing DocC catalog
Tests/<Module>Tests/             One test target per module; Performance/ holds speed-reliant tests
Tests/AfluentTests/          The suite for Afluent and AfluentTesting
Tests/AfluentTestSupport/    Shared test fixtures (data only)
scripts/modules.py               The module graph
tools/                           Bazel rule wrappers (warnings as errors, Swift 6 mode), DocC rules;
                                 tools/bazel turns BuildBuddy on when the Keychain holds its key
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

- Add a module: a row in `MODULES` (name, group, description, dependencies), then `just modules`.
- Add a test target: a row in `TEST_TARGETS`. A target with a `Performance/` directory of Swift
  sources must be listed in `PERFORMANCE_TESTS`, and the reverse.
- Add an executable: a row in `EXECUTABLES` (name, description, dependencies). It holds only
  `@main`; its code lives in a module, where tests reach it.
- Add an external package: a row in `PACKAGES`, its `swiftpkg_<identity>` repository in
  `MODULE.bazel`'s `use_repo`, then `just modules` and `just resolve`.
- Generate mocks: uncomment the Mockable row in `PACKAGES`, add `mockable/Mockable` to the
  module that declares the protocol and to its test target, add `swiftpkg_mockable` to
  `use_repo`, then `just modules` and `just resolve`. The generator defines `MOCKING` for that
  module in debug builds only, in both build systems.
- A module name takes a `Module` suffix only when it would otherwise equal its main type's name
  (`GreetingModule` would hold `Greeting`). No catch-all modules ("Core", "Utilities").

## Commands

Every shell command gets a timeout. macOS has no `timeout`; use
`perl -e 'alarm 1800; exec @ARGV' <command>`. A bug can make a loop run forever.

| Command | Does |
|---|---|
| `just build` / `just test` | Build / test everything (debug) |
| `bazel test //Tests/XTests` | One test target (`just test-one //Tests/XTests`) |
| `just filter <pattern>` | Tests whose name matches |
| `just test-release` | `--config=release`: builds and runs only the `XPerformanceTests` targets |
| `just spm-test`, `just verify` | SwiftPM tests; both build systems |
| `just modules` | Regenerate build files from `scripts/modules.py` |
| `just resolve` | Re-resolve Bazel's SwiftPM dependencies after editing `PACKAGES` |
| `just bench [--target X]` | Benchmarks; `just bench-compare` against the `main` baseline |
| `just bench-simulated-compare [--target X]` | Simulated counts (Callgrind in a Linux VM, from `~/workspace/BenchmarkHarness`) against the committed `simulated` baseline; `just bench-simulated [--target X]` re-records it. Both measure only targets whose code changed |
| `just docs` | Combined DocC site into `.build/docs` |
| `just generate` | Xcode project from the Bazel graph |
| `just buildbuddy-key`, `just ci-secrets` | Store the BuildBuddy key in the Keychain (once per Mac; builds then use the remote cache); set it as this repository's Actions secret with `gh` |
| `just template-update` | Merge the project template's changes since `.template.json`'s commit; resolve conflicts, then `just modules`, `just test` |
| `bazel query 'rdeps(//Tests/..., //Sources/X)'` | Test targets affected by a change to X |

- Debug is the default configuration. Every test target except the `XPerformanceTests` ones is
  tagged `debug-only`, which `--config=release` filters out.
- A test that bounds wall-clock time, or runs a large input under `.timeLimit`, belongs in
  `Tests/X/Performance/`.
- Release builds use their own output base (see the justfile). Don't create other output bases
  or copies of the repo, and shut down any extra Bazel server you start.
- Run suites through Bazel, not `swift test --filter`.
- First-party warnings are errors (`tools/swift_rules.bzl`); dependencies build quietly. Fix the
  warning, never suppress it. DocC's are too: `just docs` fails on a link that doesn't resolve.
- CI's Bazel jobs run in `ghcr.io/tyler-keith-thompson/swift-bazel:<swift>-<bazel>`, Swift with
  the Bazel in `.bazelversion` already in it, built by the project template's `ci-image/build.sh`.
  Changing `.bazelversion` or the workflows' Swift version means a new tag from there.
  The package is private; a repository pulls it once added under its Manage Actions access.
- Exit tests (`#expect(processExitsWith:)`) go in files of their own, apart from the other tests:
  builds for platforms that cannot start a child process leave those files out.

## Afluent

- **CI is Bazel**, cached by BuildBuddy, with one SwiftPM test job (CI.yml). Compatibility.yml
  adds `bazel test //Platforms` on macOS: Afluent built for each Apple platform at its minimum version
  (`Platforms/BUILD.bazel`, `just platforms`; keep it in step with `PLATFORMS`). Trunk's merge
  queue waits for every job (`.trunk/trunk.yaml`); a job renamed in a workflow is renamed there.
- **OHHTTPStubs** is Objective-C and Apple-only (`APPLE_ONLY_PACKAGES`): tests that use it sit
  under `#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)`.
- **Documentation addresses.** The combined site is at `/Afluent/documentation/<module>/`. Each
  module was once published at `/Afluent/<Module>/documentation/<module>/`;
  `scripts/docs_redirects.sh` writes a redirect at every old address when the DocC workflow
  publishes, so links into the old sites keep working. A new module needs no entry there.

## Building blocks

The owner's own libraries, first in line under "Don't reinvent the wheel" (House rules). Reach
for them before writing a graph, a container or an operator chain by hand, and before adding a
third-party package for the same job. Add one as a row in `PACKAGES` (`scripts/modules.py`).

| Library | What it is | Use it for |
|---|---|---|
| [Grafluent](https://github.com/Tyler-Keith-Thompson/Grafluent) | A generic, high-performance graph library: copy-on-write representations (`AdjacencyList`, `CompressedSparseRow`, `AdjacencyMatrix`, pseudographs, stable graphs), graph classes with invariants (`DirectedAcyclicGraph`, `BipartiteGraph`, `Tree`) and algorithms (traversal, shortest paths, flows, matching, connectivity, isomorphism, layout) | Anything shaped like a graph or DAG: dependency orderings, scheduling, routing, state machines, reachability. Products are per module (`.product(name: "ShortestPaths", package: "Grafluent")`); the umbrella is `Grafluent`. |
| [GrafluentCollections](https://github.com/Tyler-Keith-Thompson/GrafluentCollections) | Graph-shaped collections as copy-on-write values with the standard library's and swift-collections' API shape: balanced search trees (`AVLTree`/`AVLDictionary`, `RedBlackTree`, `Treap`, `SplayTree`) and `FenwickTree` so far; tries, suffix structures, decision diagrams, B-trees, segment, interval and spatial trees, ropes, persistent trees and an LRU cache planned. Tree- and graph-shaped ones convert to the matching Grafluent type | Sorted sets and dictionaries that take inserts and removals, prefix and range sums with updates; check its backlog before hand-writing a planned structure. Products are per module (`.product(name: "BinarySearchTrees", package: "GrafluentCollections")`); the umbrella is `GrafluentCollections`. |
| [DependencyInjection](https://github.com/Tyler-Keith-Thompson/DependencyInjection) | Swift 6 dependency injection: `Factory` values on `Container`, `@Injected` / `@LazyInjected` / `@ConstructorInjected`, unique, cached and shared scopes, hierarchical containers, and `withTestContainer` so concurrent tests never share state | Any seam a test needs to replace (clocks, network, storage). Tests wrap their body in `withTestContainer { }` and register doubles there. Product `DependencyInjection`. |
| [Afluent](https://github.com/Tyler-Keith-Thompson/Afluent) | Reactive operators over async/await: `DeferredTask` (a unit of work that yields one value) and `AsyncSequence` extensions with Combine's names (`map`, `flatMap`, `catch`, `retry`, `debounce`, `share`, …), plus `AfluentTesting` | Pipelines over async work where Combine would once have been used; a Combine replacement in new code. Products `Afluent` and, for test targets, `AfluentTesting`. |

Their conventions carry over: value types, typed errors, `checked:` spellings that throw where
the plain spelling traps, tests with Swift Testing.

## Workflow

### Adding a feature

A feature is done when it has all of these. Copy what its sibling features in the module already
have.

1. **Code and docs.** The implementation, with doc comments per "Docs" below. A new module gets a
   row in `scripts/modules.py`, then `just modules`.
2. **Tests** in `Tests/<Module>Tests`:
   - hand-worked cases;
   - edge cases: empty input, one element, the boundaries of every range;
   - `checked:` spellings and their errors;
   - exit tests for every trap;
   - a property test against a naive reference (`swift-property-based`).
3. **A README example**, if the feature changes how the package is introduced, copied verbatim
   into `Tests/AfluentTests`.
4. **A benchmark** in `Benchmarks/Benchmarks/<Module>Benchmarks` (a row in `BENCHMARKS`, then
   `just modules`) where speed matters, starting with a `BASELINE` entry: the hand-written form the code must keep pace with. Measure in
   release, and add a ratio test in `Tests/<Module>Tests/Performance/` where siblings have one.
   Use small inputs in debug builds, because the timing only runs in release.
   Judge a speed change by `just bench-simulated-compare --target <Module>Benchmarks`: its
   instruction, cache-miss and branch counts don't move when the machine is busy, as wall clock
   does. Allocation counts and absolute times still come from `just bench`, on a quiet machine.
   Re-record the `simulated` baseline for the targets a change touches
   (`just bench-simulated --target X`) and commit it with the change. Its `results.json` is
   pretty-printed with sorted keys, one benchmark's entry on lines of its own, and a benchmark
   whose instruction and malloc counts moved less than compare's 5% threshold keeps its recorded
   entry. So the file changes only where a benchmark did, and pull requests that change different
   benchmarks of one target merge without a conflict. Resolve a conflict by re-recording after
   the merge, never by hand. To rewrite every entry (a change aimed at cache misses alone), delete
   the file first.

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
| `Benchmarks/`, or an API the benchmarks call | `cd Benchmarks && env -u TOOLCHAINS xcrun --toolchain default swift build -c release` |
| A change meant to be faster | `just bench-simulated-compare --target <Module>Benchmarks`, not `just bench-compare` |

### Pushing

Ship finished work yourself; don't wait to be asked, and never end a task with finished work
unmerged. `main` takes changes only through Trunk's merge queue, and every merge releases a patch
version, so ship once per batch: when the work the owner gave you is done (the whole request, or
Ready is empty when working the backlog), put everything it produced on one branch.

1. Verify the committed state in a clean worktree: `bazel test //...` in debug, then
   `--config=release`.
2. Push the branch, open a pull request (`gh pr create`) and queue it with a `/trunk merge`
   comment (`gh pr comment --body "/trunk merge"`). Trunk tests it on a `trunk-merge/` branch
   against the current `main` and merges it once the checks `.trunk/trunk.yaml` names pass.
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
     (swift-collections, swift-algorithms, swift-async-algorithms, swift-numerics, swift-atomics,
     swift-system, swift-argument-parser, swift-log, swift-crypto, swift-nio), then
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
- No hooks or SPI added only for tests.
- Underscored Swift features (`@_spi`, `_modify`, `@_effects`, `@_exported`) are fine where they
  help. Apple private API is not: undocumented framework symbols, private selectors, private
  frameworks, anything App Review rejects.

### Tests (*default*)

- Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`). Never XCTest.
- Each test is self-contained and portable: no assertion or setup helpers, not DRY; a test
  copied to another file still works. Shared fixture data in `AfluentTestSupport` is tolerated;
  shared assertions are not.
- Test names state the rule they pin ("The checked spelling throws EmptyName for an empty name").
- Tests may call underscored and `package` API.
- Test doubles come from [Mockable](https://github.com/Kolos65/Mockable): mark the protocol at the
  seam `@Mockable` and use the generated `Mock<Protocol>` with `given`, `when` and `verify`
  inside the test, rather than hand-writing doubles. With DependencyInjection, register the mock
  inside the test's `withTestContainer { }`. Mocks exist only in debug builds, so a
  `PerformanceTests` target never uses one.
- Property tests use swift-property-based (`import PropertyBased`, `propertyCheck`).
- Randomized tests are seeded (`SeededRandomNumberGenerator`) so a failure reproduces from its
  seed alone.

### Docs (*default*)

- Describe the current API. No history ("previously", "renamed"), design debates, comparisons
  with other libraries, or benchmark numbers in doc comments or READMEs. Complexity bounds are
  fine.
- Doc comments: a one-line summary, then parameters, return value, complexity, and what traps or
  throws.
- The README's examples are tests (`Tests/AfluentTests`).

### Git (*default*)

- Commit message style: `[main] - <summary>`, no trailers (no co-author or session lines).
- One commit per finished feature or fix, after its suites pass.
- Never file bugs with third-party projects; record them locally.

## API conventions (*default*)

### Errors

- **Plain spellings trap** on a precondition failure, like an `Array` subscript. They are the
  fast path.
- **`checked:` spellings throw** a typed, payload-free error (`Greeting(checkedName:)` throws
  `EmptyName`). There are no nil-returning variants; `try?` gives `nil`.
- **Invariant-breaking mutations throw on the plain spelling** and change nothing, with one typed
  error per invariant whose cases make a single `catch` exhaustive.
- **Queries whose failure is the answer return a witness** (`findCycle() -> Cycle?`), not an
  error.

### Shapes

- Results are dedicated types, not tuples.
- Lazy views end in `View`; the materialized form drops the suffix.
- Materializing operations are static factories on a target the caller picks.

### Performance patterns

- Public types are copy-on-write structs, `@frozen`, with `@usableFromInline` internals.
  Hot generic code is `@inlinable`; parameters are `some` generics, never `any`.
- Copy-on-write: the uniqueness check is inlined and the reallocation slow path is
  `@inline(never)`. Bulk mutations check uniqueness once, outside the loop.
- Traps measured in past projects: nested functions capturing mutable locals (boxed, retained
  per step); generic iterators stored in arrays (use integer cursors); reading a struct out of a
  class property (copies and retains); lazy maps capturing `self`.
- Write overflow guards as comparisons (`x <= Int.max / 4`), not a discarded
  `multipliedReportingOverflow` result.
