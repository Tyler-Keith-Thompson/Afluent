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

import fcntl
import importlib.util
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile

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


def mirror(source, destination):
    """Make `destination` hold exactly `source`'s files, rewriting only those that differ."""
    wanted = set()
    for directory, _, names in os.walk(source):
        for name in names:
            relative = os.path.relpath(os.path.join(directory, name), source)
            wanted.add(relative)
            with open(os.path.join(source, relative), "rb") as f:
                content = f.read()
            target = os.path.join(destination, relative)
            try:
                with open(target, "rb") as f:
                    if f.read() == content:
                        continue
            except FileNotFoundError:
                pass
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target + ".partial", "wb") as f:
                f.write(content)
            os.chmod(target + ".partial", os.stat(os.path.join(source, relative)).st_mode & 0o777)
            os.replace(target + ".partial", target)
    for directory, _, names in os.walk(destination):
        for name in names:
            path = os.path.join(directory, name)
            if os.path.relpath(path, destination) not in wanted:
                os.remove(path)


def prepare_harness(harness_checkout):
    """Build the harness, copy it into Benchmarks/.harness/bin, and stamp the host's toolchain.

    Building re-signs the binary in place, so checkouts building at once take turns (a lock in the
    harness's build directory), and each checkout runs its own copy: a measurement in one checkout
    never starts a binary another is rewriting. The copy keeps the signature, which is embedded,
    and takes the resource bundles beside the binary too, which hold the guest's scripts.
    """
    build = os.path.join(harness_checkout, "Harness", ".build")
    os.makedirs(build, exist_ok=True)
    bin_dir = os.path.join(STAMP_DIR, "bin")
    with open(os.path.join(build, "bench-simulated.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(["just", "--justfile", os.path.join(harness_checkout, "justfile"), "harness"], check=True)
        release = os.path.join(build, "release")
        with tempfile.TemporaryDirectory() as snapshot:
            shutil.copy2(os.path.join(release, "benchmark-harness"), snapshot)
            for name in sorted(os.listdir(release)):
                if name.endswith(".bundle"):
                    shutil.copytree(os.path.join(release, name), os.path.join(snapshot, name))
            lock.close()
            for stale in ("benchmark-harness",):  # the symlink an earlier version wrote
                if os.path.islink(os.path.join(STAMP_DIR, stale)):
                    os.remove(os.path.join(STAMP_DIR, stale))
            mirror(snapshot, bin_dir)
    # The binary and its bundles are inputs (Bazel hashes them). The stamp adds what the counts
    # depend on beyond them: the kind of host and the Swift that builds the harness's tools.
    write_if_changed(os.path.join(STAMP_DIR, "stamp"), f"{platform.system()} {platform.machine()}\n{swift_version()}\n")
    return os.path.join(bin_dir, "benchmark-harness")


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
        # from the file, so it is changed to the one asked for and nothing else. Replacing the
        # text keeps the harness's bytes and key order; the new name is encoded as a JSON string.
        marker = '"baselineName":"bazel"'
        assert results.count(marker) == 1, f"{target}: no baseline name in the harness's output"
        destination = os.path.join(BENCHMARKS_DIR, ".benchmarkBaselines", target, baseline)
        os.makedirs(destination, exist_ok=True)
        with open(os.path.join(destination, "results.json"), "w") as f:
            f.write(results.replace(marker, f'"baselineName":{json.dumps(baseline)}'))
        print(f"Wrote baseline '{baseline}' for {target}")


if __name__ == "__main__":
    main(sys.argv[1:])
