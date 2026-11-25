#!/usr/bin/env python3
"""Builds the SwiftPM test targets for wasm32-unknown-wasi and runs them under wasmtime: the
32-bit `Int` check. See AGENTS.md ("32-bit `Int` (WebAssembly)").

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

If the swift.org toolchain crashes compiling the manifest against a newer Xcode's macOS SDK, pass
an older Xcode: `--xcode /Applications/Xcode-26.2.0.app` (or set <PROJECT>_WASI_XCODE).
"""

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import modules  # noqa: E402

SCRATCH = os.path.join(ROOT, ".build", "wasm")
# Stack sizes, in bytes, for the test binaries: see the build command in `main`.
LINEAR_MEMORY_STACK = 64 << 20
WASM_CALL_STACK = 256 << 20


def all_targets():
    names = []
    for name, _ in modules.TEST_TARGETS:
        names.append(name)
        if name in modules.PERFORMANCE_TESTS:
            names.append(modules.performance_target(name))
    return names


# Until PT-48: this, the 6.4.3 default, the stack sizes and --no-parallel differ from the template's
# copy; take the template's side on an update once PT-48 has landed.
def test_binaries(products, group):
    """The test binaries the build wrote for a group of targets.

    Swift 6.3's build links every test target into one `<Project>PackageTests.xctest`; Swift 6.4's
    writes a `<Target>-test-runner.wasm` per test target instead.
    """
    runners = [os.path.join(products, f"{target}-test-runner.wasm") for target in group]
    if all(os.path.exists(runner) for runner in runners):
        return runners
    return [os.path.join(products, f"{modules.PROJECT}PackageTests.xctest")]


def run(cmd, env, log, timeout):
    with open(log, "w") as f:
        try:
            return subprocess.run(cmd, cwd=ROOT, env=env, stdout=f, stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            f.write(f"\nTimed out after {timeout} s\n")
            return -1


def group_failed(statuses, lines, binaries):
    """Whether a group failed: a runner exited nonzero, an issue was recorded, or a runner wrote no
    summary line (it trapped or was killed before its run finished).

    Until PT-48: the template's copy excuses "Time limit was exceeded" issues and ignores exit
    codes. Here TimeLimitOnWASI.swift keeps every `.timeLimit` from reaching WASI, so a time-limit
    issue means that overload stopped winning, and it fails the run like any other issue.
    """
    summaries = [line for line in lines if re.search(r"Test run with \d+ tests", line)]
    return any(status != 0 for status in statuses) or bool(issues(lines)) or len(summaries) < len(binaries)


def issues(lines):
    return [line for line in lines if "recorded an issue" in line]


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("-c", "--configuration", default="debug", choices=["debug", "release"])
    parser.add_argument("--targets", help="comma-separated test targets (default: all)")
    parser.add_argument("--group-size", type=int, default=8)
    parser.add_argument("--swift", default="6.4.3")
    parser.add_argument("--sdk", default=None, help="default: swift-<swift>-RELEASE_wasm")
    parser.add_argument("--xcode", default=os.environ.get(f"{modules.PROJECT.upper()}_WASI_XCODE"))
    parser.add_argument("--timeout", type=int, default=3600, help="seconds per build and per run")
    args = parser.parse_args()
    sdk = args.sdk or f"swift-{args.swift}-RELEASE_wasm"
    targets = args.targets.split(",") if args.targets else all_targets()
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
        # Without WebAssembly tail calls, an async function that finishes without suspending
        # returns through its caller's continuation, so a loop of awaits that never suspend (ten
        # thousand consecutive retries) deepens both stacks until something suspends. 8 MB of
        # linear-memory stack and wasmtime's 16 MB call stack both overflow on those; these hold.
        # Afluent's own: `-enable-testing`, because suites `@testable import Afluent`, which a release
        # build otherwise refuses ("not compiled for testing").
        build = ["swiftly", "run", "swift", "build", "-c", args.configuration, "--build-tests",
                 "-Xswiftc", "-enable-testing", "--swift-sdk", sdk, "--scratch-path", SCRATCH,
                 "-Xlinker", "-z", "-Xlinker", f"stack-size={LINEAR_MEMORY_STACK}", f"+{args.swift}"]
        if run(build, env, os.path.join(logs, tag + "-build.log"), args.timeout) != 0:
            print(f"{tag} build FAILED ({', '.join(group)}): see .build/wasm/logs/{tag}-build.log")
            failed.append(tag)
            continue
        # One test at a time: on WASI a pending sleep can hold the one thread until its deadline
        # (and cancelling it doesn't end it sooner), so in parallel one test's sleep stalls the
        # tasks another is waiting on. For the same reason a time limit's timer would stall the
        # body it bounds; Tests/AfluentTests/TestHelpers/TimeLimitOnWASI.swift turns `.timeLimit`
        # off there, and `--timeout` bounds the run instead.
        log = os.path.join(logs, tag + "-test.log")
        statuses = []
        with open(log, "w"):
            pass
        binaries = test_binaries(products, group)
        for binary in binaries:
            test = ["wasmtime", "run", "-W", f"max-wasm-stack={WASM_CALL_STACK}", "--dir", ".", binary,
                    "--testing-library", "swift-testing", "--no-parallel"]
            part = log + ".part"
            statuses.append(run(test, env, part, args.timeout))
            with open(log, "a") as whole, open(part, errors="replace") as f:
                whole.write(f.read())
            os.remove(part)
        lines = open(log, errors="replace").read().splitlines()
        summary = [line.strip() for line in lines if re.search(r"Test run with \d+ tests", line)]
        recorded = issues(lines)
        print(f"{tag} exit {statuses}: {summary[-1] if summary else 'no summary'}; {len(recorded)} issues"
              f" ({', '.join(group)})")
        for line in recorded[:20]:
            print("    " + line[:300])
        # A trap ends the binary: name the test frames of its backtrace.
        frames = [line.strip() for line in lines if re.search(r"(xctest|wasm)!\S*Tests", line)]
        for line in frames[:3]:
            print("    trap: " + line[:300])
        if group_failed(statuses, lines, binaries):
            failed.append(tag)
    print("FAILED: " + ", ".join(failed) if failed else "All groups passed.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
