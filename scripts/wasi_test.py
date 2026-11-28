#!/usr/bin/env python3
"""Builds the SwiftPM test targets for wasm32-unknown-wasi and runs them under wasmtime: the
32-bit `Int` check. See docs/agents/wasm.md.

    python3 scripts/wasi_test.py                     # every test target, debug
    python3 scripts/wasi_test.py -c release          # every test target, release
    python3 scripts/wasi_test.py --targets GreetingsTests

Needs swiftly with the Swift toolchain `--swift` (default 6.4.3), its Swift SDK for WebAssembly
`--sdk` (`swift sdk list`; the install command is on swift.org, "Getting Started with Swift SDKs
for WebAssembly"), and wasmtime (`brew install wasmtime`). One binary of every test target can
pass wasmtime's limit of a million functions, so the targets run in groups of `--group-size`:
<PROJECT>_WASI_TESTS (the project's name in capitals) names a group, and
Package.swift then declares only its test targets and leaves out each test file with an exit test
(WASI cannot start a child process). Builds go to .build/wasm, logs to .build/wasm/logs.

The toolchain writes one `<Target>-test-runner.wasm` per test target, or, if older, one
`<Project>PackageTests.xctest` for the group; each runs in turn. Without wasm tail calls,
every await that doesn't suspend deepens both stacks, so the binaries link a 64 MB stack and run
with a 256 MB wasm stack, enough for a 10,000-deep chain of such awaits. `--serial` runs a binary's
tests one at a time (Swift Testing's `--no-parallel`).

If the swift.org toolchain crashes compiling the manifest against a newer Xcode's macOS SDK, pass
an older Xcode: `--xcode /Applications/Xcode-26.2.0.app` (or set <PROJECT>_WASI_XCODE).
"""

import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import modules  # noqa: E402

SCRATCH = os.path.join(ROOT, ".build", "wasm")


def all_targets():
    names = []
    for name, _ in modules.TEST_TARGETS:
        names.append(name)
        if name in modules.PERFORMANCE_TESTS:
            names.append(modules.performance_target(name))
    return names


def run(cmd, env, log, timeout):
    with open(log, "w") as f:
        try:
            return subprocess.run(cmd, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            f.write(f"\nTimed out after {timeout} s\n")
            return -1


def group_failed(status, lines):
    """Whether a binary's run failed: it exited nonzero, recorded an issue, or wrote no summary line
    (it trapped or was killed before the run finished).

    Afluent's own: the template's copy excuses "Time limit was exceeded" issues and so ignores the
    exit status. Here Tests/AfluentTests/TestHelpers/TimeLimitOnWASI.swift keeps every `.timeLimit`
    from reaching WASI (`just wasi-test` runs `--serial`, where each timer would cost its whole
    limit), so a time-limit issue means that overload stopped winning, and fails the run like any
    other issue.
    """
    summary = any(re.search(r"Test run with \d+ tests?", line) for line in lines)
    return status != 0 or bool(issues(lines)) or not summary


def issues(lines):
    return [line for line in lines if "recorded an issue" in line]


# The stacks a deep chain of non-suspending awaits needs: the linear-memory stack the binary links
# with, and wasmtime's call stack.
LINEAR_STACK = 64 * 1024 * 1024
WASM_STACK = 256 * 1024 * 1024


class TestBinaries:
    """The test binaries a group's build wrote, and the group's targets it wrote none for."""

    def __init__(self, binaries, missing):
        self.binaries = binaries
        self.missing = missing


def stack_toolset():
    """The path of a toolset file, written under .build/wasm, that links wasm binaries with
    LINEAR_STACK, the linear-memory stack deep chains of non-suspending awaits overrun.

    A toolset applies to the target's tools alone. `-Xlinker` would also reach the host link of a
    macro's compiler plugin (MACROS in scripts/modules.py), and the macOS linker has no `-z`."""
    path = os.path.join(SCRATCH, "stack-toolset.json")
    os.makedirs(SCRATCH, exist_ok=True)
    with open(path, "w") as file:
        json.dump({"schemaVersion": "1.0", "linker": {"extraCLIOptions": ["-z", f"stack-size={LINEAR_STACK}"]}}, file)
    return path


def test_binaries(products, group):
    """The test binaries a group's build wrote: one `<Target>-test-runner.wasm` per target, else (an
    older toolchain) the one `<Project>PackageTests.xctest`. Once any target has its runner, every
    target must: one without would otherwise go untested while the group passes."""
    runners = {target: os.path.join(products, f"{target}-test-runner.wasm") for target in group}
    written = [target for target in group if os.path.isfile(runners[target])]
    if written:
        return TestBinaries([runners[target] for target in written], [t for t in group if t not in written])
    bundle = os.path.join(products, f"{modules.PROJECT}PackageTests.xctest")
    return TestBinaries([bundle], []) if os.path.isfile(bundle) else TestBinaries([], list(group))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("-c", "--configuration", default="debug", choices=["debug", "release"])
    parser.add_argument("--targets", help="comma-separated test targets (default: all)")
    parser.add_argument("--group-size", type=int, default=8)
    parser.add_argument("--swift", default="6.4.3")
    parser.add_argument("--sdk", default=None, help="default: swift-<swift>-RELEASE_wasm")
    parser.add_argument("--xcode", default=os.environ.get(f"{modules.PROJECT.upper()}_WASI_XCODE"))
    parser.add_argument("--timeout", type=int, default=3600, help="seconds per build and per run")
    parser.add_argument("--serial", action="store_true", help="run each binary's tests one at a time")
    args = parser.parse_args()
    sdk = args.sdk or f"swift-{args.swift}-RELEASE_wasm"
    targets = args.targets.split(",") if args.targets else all_targets()
    # A name Package.swift doesn't declare would build nothing and run nothing, and the run would
    # still pass.
    unknown = [target for target in targets if target not in all_targets()]
    if unknown:
        print(f"Unknown test targets: {', '.join(unknown)} (TEST_TARGETS in scripts/modules.py: {', '.join(all_targets())})")
        return 2
    env = dict(os.environ)
    if args.xcode:
        env["DEVELOPER_DIR"] = os.path.join(args.xcode, "Contents", "Developer")
        env["SDKROOT"] = os.path.join(env["DEVELOPER_DIR"], "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")
    logs = os.path.join(SCRATCH, "logs")
    os.makedirs(logs, exist_ok=True)
    products = os.path.join(SCRATCH, args.configuration)
    failed = []
    for start in range(0, len(targets), args.group_size):
        group = targets[start:start + args.group_size]
        env[f"{modules.PROJECT.upper()}_WASI_TESTS"] = ",".join(group)
        tag = f"{args.configuration}-{start // args.group_size:02}"
        # Debug builds are testable already; a release one must be too, for `@testable import`.
        testable = ["-Xswiftc", "-enable-testing"] if args.configuration == "release" else []
        build = ["swiftly", "run", "swift", "build", "-c", args.configuration, "--build-tests",
                 "--swift-sdk", sdk, "--scratch-path", SCRATCH, *testable,
                 "--toolset", stack_toolset(), f"+{args.swift}"]
        if run(build, env, os.path.join(logs, tag + "-build.log"), args.timeout) != 0:
            print(f"{tag} build FAILED ({', '.join(group)}): see .build/wasm/logs/{tag}-build.log")
            failed.append(tag)
            continue
        found = test_binaries(products, group)
        if found.missing:
            print(f"{tag} FAILED: the build wrote no test binary for {', '.join(found.missing)} to .build/wasm/{args.configuration}")
            failed.append(tag)
            continue
        for binary in found.binaries:
            name = os.path.basename(binary).removesuffix(".wasm").removesuffix(".xctest")
            # In parallel by default: on WASI a time limit's timer holds the one thread until it
            # expires, so every time-limited test reports its limit as exceeded. In parallel the
            # timers overlap; one at a time (--serial), each costs its whole limit.
            # The checkout also at its own path, and the binary's real path as argv[0]: SwiftPM's
            # `Bundle.module` finds a module's resource bundle (RESOURCES in scripts/modules.py) by
            # its absolute path in the build directory (with the .xctest layout), or beside
            # Bundle.main (with -test-runner.wasm), which Foundation on WASI takes from argv[0]'s
            # directory. wasmtime passes the file's
            # name alone, and Bundle.main is then the guest's `/`.
            root = os.path.realpath(ROOT)
            test = ["wasmtime", "run", "-W", f"max-wasm-stack={WASM_STACK}", "--dir", ".", "--dir", f"{root}::{root}",
                    "--argv0", os.path.realpath(binary), binary,
                    "--testing-library", "swift-testing"] + (["--no-parallel"] if args.serial else [])
            log = os.path.join(logs, f"{tag}-{name}-test.log")
            status = run(test, env, log, args.timeout)
            lines = open(log, errors="replace").read().splitlines()
            summary = [line.strip() for line in lines if re.search(r"Test run with \d+ tests?", line)]
            recorded = issues(lines)
            print(f"{tag} {name} exit {status}: {summary[-1] if summary else 'no summary'}; {len(recorded)} issues")
            for line in recorded[:20]:
                print("    " + line[:300])
            # A trap ends the binary: name the test frames of its backtrace.
            frames = [line.strip() for line in lines if re.search(r"(\.xctest|-test-runner\.wasm)!\S*Tests", line)]
            for line in frames[:3]:
                print("    trap: " + line[:300])
            if group_failed(status, lines):
                failed.append(f"{tag} {name}")
    print("FAILED: " + ", ".join(failed) if failed else "All groups passed.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
