#!/usr/bin/env python3
"""Record simulated benchmark counts as an ordo-one baseline, measuring only what changed.

    scripts/bench_simulated.py <baseline> [--target <Target>]...

Each benchmark target (BENCHMARKS in scripts/modules.py) is a Bazel target, //Benchmarks:<Target>,
whose output is its counts from BenchmarkHarness (tools/benchmarks.bzl). Counts are deterministic,
so Bazel measures a target again only when its sources, the modules it imports, the manifests or
the harness changed, and serves the rest from the disk cache or BuildBuddy. The results are
written to Benchmarks/.benchmarkBaselines/<Target>/<baseline>/results.json, where
`swift package benchmark baseline compare` reads them.

Any other option (--filter, --skip, --iterations, ...) runs the harness directly on the package,
uncached, as `benchmark-harness baseline update` would.

BENCHMARK_HARNESS names the BenchmarkHarness checkout (default ~/workspace/BenchmarkHarness).
"""

import importlib.util
import os
import platform
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BENCHMARKS_DIR = os.path.join(ROOT, "Benchmarks")
STAMP_DIR = os.path.join(BENCHMARKS_DIR, ".harness")


def benchmark_targets():
    spec = importlib.util.spec_from_file_location("modules", os.path.join(ROOT, "scripts", "modules.py"))
    modules = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modules)
    return [name for name, _ in modules.BENCHMARKS]


def swift_version():
    command = ["swift", "--version"]
    if platform.system() == "Darwin":
        command = ["env", "-u", "TOOLCHAINS", "xcrun", "--toolchain", "default", "swift", "--version"]
    return subprocess.run(command, capture_output=True, text=True, check=True).stdout.strip()


def write_if_changed(path, text):
    """Leaves an unchanged file alone, so its timestamp doesn't move."""
    try:
        with open(path) as f:
            if f.read() == text:
                return
    except FileNotFoundError:
        pass
    with open(path, "w") as f:
        f.write(text)


def prepare_harness(harness_checkout):
    """Build the harness, then point Benchmarks/.harness at it with a stamp of the host's toolchain."""
    subprocess.run(["just", "--justfile", os.path.join(harness_checkout, "justfile"), "harness"], check=True)
    binary = os.path.join(harness_checkout, "Harness", ".build", "release", "benchmark-harness")
    os.makedirs(STAMP_DIR, exist_ok=True)
    link = os.path.join(STAMP_DIR, "benchmark-harness")
    if not os.path.islink(link) or os.readlink(link) != binary:
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(binary, link)
    # The binary itself is an input too (Bazel hashes what the link points to). The stamp adds what
    # the counts depend on beyond it: the kind of host and the Swift that builds the harness's tools.
    write_if_changed(os.path.join(STAMP_DIR, "stamp"), f"{platform.system()} {platform.machine()}\n{swift_version()}\n")
    return binary


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    baseline, options = argv[0], argv[1:]
    harness_checkout = os.environ.get("BENCHMARK_HARNESS", os.path.expanduser("~/workspace/BenchmarkHarness"))

    targets, uncached = [], []
    index = 0
    while index < len(options):
        if options[index] == "--target" and index + 1 < len(options):
            targets.append(options[index + 1])
            index += 2
        else:
            uncached.append(options[index])
            index += 1

    binary = prepare_harness(harness_checkout)
    if uncached:
        print("Measuring without the cache: only --target selects cached results.", file=sys.stderr)
        command = [binary, "baseline", "update", baseline, "--package-path", BENCHMARKS_DIR]
        command += [arg for target in targets for arg in ("--target", target)] + uncached
        sys.exit(subprocess.run(command).returncode)

    known = benchmark_targets()
    unknown = [t for t in targets if t not in known]
    if unknown:
        sys.exit(f"Not in BENCHMARKS (scripts/modules.py): {', '.join(unknown)}")
    targets = targets or known
    labels = [f"//Benchmarks:{t}" for t in targets]
    subprocess.run(["bazel", "build", *labels], cwd=ROOT, check=True)
    bin_dir = subprocess.run(["bazel", "info", "bazel-bin"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()

    for target in targets:
        with open(os.path.join(bin_dir, "Benchmarks", f"{target}.json")) as f:
            results = f.read()
        # The measurement records the baseline under the name "bazel"; ordo-one reads the name
        # from the file, so it is changed to the one asked for and nothing else.
        marker = '"baselineName":"bazel"'
        assert results.count(marker) == 1, f"{target}: no baseline name in the harness's output"
        destination = os.path.join(BENCHMARKS_DIR, ".benchmarkBaselines", target, baseline)
        os.makedirs(destination, exist_ok=True)
        with open(os.path.join(destination, "results.json"), "w") as f:
            f.write(results.replace(marker, f'"baselineName":"{baseline}"'))
        print(f"Wrote baseline '{baseline}' for {target}")


if __name__ == "__main__":
    main(sys.argv[1:])
