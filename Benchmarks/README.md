# Benchmarks

A separate SwiftPM package built on [ordo-one/benchmark](https://github.com/ordo-one/benchmark),
so the library and its tests never depend on the benchmark framework. Bazel ignores its SwiftPM
build (`.bazelignore`) and loads only `BUILD.bazel`, which caches the simulated counts.

Requires `brew install jemalloc`.

| Command | Does |
|---|---|
| `just bench` | Run every benchmark (`--target X` for one) |
| `just bench-baseline` | Save the current results as the `main` baseline |
| `just bench-compare` | Compare the current results against `main` |
| `just bench-simulated [--target X]` | Record simulated counts as the `simulated` baseline |
| `just bench-simulated-compare [--target X]` | Record simulated counts as `simulated-current` and compare them against `simulated` |

`Package.swift` and `BUILD.bazel` are generated from `BENCHMARKS` in `scripts/modules.py`: a row
per target, with the library modules it imports. Add a target there, then `just modules`.

Each module's benchmarks live in `Benchmarks/<Module>Benchmarks/` and start with a `BASELINE`
entry: the hand-written form the library must keep pace with. The `main` and `simulated`
baselines are committed; other names are local before/after comparisons.

The `bench-simulated` recipes run the same benchmarks, unchanged, in a Linux virtual machine under
Callgrind (the `benchmark-harness` tool from `~/workspace/BenchmarkHarness`, or `$BENCHMARK_HARNESS`)
and record instructions, cache misses, mispredicted branches and an estimated cycle count instead of
time. Those counts come from a fixed simulated machine, so they don't move when the host is busy.
Wall-clock results (`just bench`) only mean something on a quiet machine.

Simulated counts are deterministic, so each target's are a cached Bazel output
(`//Benchmarks:<Target>`, `tools/benchmarks.bzl`): `just bench-simulated` measures again only the
targets whose sources, imported modules, manifests or harness changed, and takes the rest from the
disk cache or BuildBuddy. Each measurement stages the package under
`~/Library/Caches/<project>-benchmarks/<checkout>/<Target>` (`~/.cache` on Linux; one per checkout,
so worktrees don't share one) and runs outside Bazel's sandbox, which can't start a VM.
`Benchmarks/.harness/` (untracked) holds this checkout's copy of the harness binary and its resource
bundles, and a stamp of the host and Swift version, all inputs. `--filter`, `--skip` and the
harness's other options measure directly, uncached.
