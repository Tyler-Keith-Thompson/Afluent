#!/usr/bin/env python3
"""Record simulated benchmark counts as an ordo-one baseline, measuring only what changed.

    scripts/bench_simulated.py <baseline> [--target <Target>]... [--fresh]

Each benchmark target (BENCHMARKS in scripts/modules.py) is a Bazel target, //Benchmarks:<Target>,
whose output is its counts from BenchmarkHarness (tools/benchmarks.bzl). Counts are deterministic,
so Bazel measures a target again only when its sources, the modules it imports, the manifests or
the harness changed, and serves the rest from the disk cache or BuildBuddy. The results are
written to Benchmarks/.benchmarkBaselines/<Target>/<baseline>/results.json, where
`swift package benchmark baseline compare` reads them: pretty-printed, keys and benchmarks sorted.
A benchmark whose instruction and malloc counts moved less than compare's threshold keeps the entry
already recorded there, so the file changes only where a benchmark did; --fresh writes every entry
as measured.

Any other option (--filter, --skip, --iterations, ...) runs the harness directly on the package,
uncached, as `benchmark-harness baseline update` would.

BENCHMARK_HARNESS names the BenchmarkHarness checkout (default ~/workspace/BenchmarkHarness).
"""

import fcntl
import importlib.util
import json
import math
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


def baseline_path(target, baseline):
    """Where ordo-one keeps a target's recorded baseline."""
    return os.path.join(BENCHMARKS_DIR, ".benchmarkBaselines", target, baseline, "results.json")


def read_json(path):
    """The JSON document at `path`, or None when there is no file."""
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


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
            # Runs in this checkout take turns copying the harness in. The lock file sits outside
            # bin/, which mirror() prunes, and outside the files Bazel hashes (tools/benchmarks.bzl:
            # the binary, its bundles and the stamp).
            os.makedirs(STAMP_DIR, exist_ok=True)
            with open(os.path.join(STAMP_DIR, "checkout.lock"), "w") as checkout_lock:
                fcntl.flock(checkout_lock, fcntl.LOCK_EX)
                stale = os.path.join(STAMP_DIR, "benchmark-harness")  # the symlink an earlier version wrote
                if os.path.islink(stale):
                    os.remove(stale)
                mirror(snapshot, bin_dir)
                # The binary and its bundles are inputs (Bazel hashes them). The stamp adds what the
                # counts depend on beyond them: the host's kind and the Swift that builds the tools.
                write_if_changed(os.path.join(STAMP_DIR, "stamp"), f"{platform.system()} {platform.machine()}\n{swift_version()}\n")
    return os.path.join(bin_dir, "benchmark-harness")


def main(argv):
    if not argv or argv[0].startswith("-"):
        sys.exit(__doc__)
    baseline, options = argv[0], argv[1:]
    harness_checkout = os.environ.get("BENCHMARK_HARNESS", os.path.expanduser("~/workspace/BenchmarkHarness"))

    targets, uncached, fresh = [], [], False
    index = 0
    while index < len(options):
        if options[index] == "--fresh":
            fresh = True
            index += 1
        elif options[index] == "--target" and index + 1 < len(options):
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
        # The harness writes its own encoding; rewrite what it wrote the way the cached path does,
        # so a re-record with these options keeps the format and the unmoved entries too.
        paths = {target: baseline_path(target, baseline) for target in targets or benchmark_targets()}
        recorded = {} if fresh else {target: read_json(path) for target, path in paths.items()}
        returncode = subprocess.run(command).returncode
        if returncode:
            sys.exit(returncode)
        for target, path in paths.items():
            measured = read_json(path)
            if measured is not None:
                write_if_changed(path, encode(keep_unmoved(recorded.get(target), measured)) + "\n")
        sys.exit(0)

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
            measured = json.load(f)
        # The measurement records the baseline under the name "bazel"; ordo-one reads the name
        # from the file.
        measured["baselineName"] = baseline
        path = baseline_path(target, baseline)
        recorded = None if fresh else read_json(path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_if_changed(path, encode(keep_unmoved(recorded, measured)) + "\n")
        print(f"Wrote baseline '{baseline}' for {target}")


# The metrics that decide whether a benchmark moved: the counts the code determines. Cache misses,
# mispredicted branches and the cycle estimate follow them, but also vary between runs of the same
# binary, so they alone never rewrite an entry.
DECIDING_METRICS = ("instructions", "mallocCountTotal")
# ordo-one's default relative thresholds (BenchmarkThresholds.Relative.default), which
# `baseline compare` applies: a percentile moved when it differs by more than this many percent.
THRESHOLDS = {25.0: 5.0, 50.0: 5.0, 75.0: 5.0}


def histogram_values(histogram):
    """The values an HdrHistogram recorded, each at the highest value its bucket stands for."""
    half = histogram["subBucketHalfCountMagnitude"]
    unit = histogram["unitMagnitude"]
    values = []
    for index, count in enumerate(histogram["counts"]):
        if count:
            bucket, sub_bucket = (index >> half) - 1, (index & ((1 << half) - 1)) + (1 << half)
            if bucket < 0:
                bucket, sub_bucket = 0, sub_bucket - (1 << half)
            lowest = sub_bucket << (bucket + unit)
            values += [min(lowest + (1 << (bucket + unit)) - 1, histogram["maxValue"])] * count
    return values


def percentile(values, p):
    """HdrHistogram's valueAtPercentile: the smallest value at least p percent of the values reach."""
    return values[max(1, math.ceil(math.nextafter(p, 0) * len(values) / 100)) - 1]


def moved(recorded, measured):
    """Whether `baseline compare` would see a benchmark's deciding metrics change between two entries."""
    def metrics(entry):
        return {json.dumps(result["metric"], sort_keys=True): result for result in entry}
    before, after = metrics(recorded), metrics(measured)
    if before.keys() != after.keys():
        return True
    deciding = [key for key, result in after.items() if any(m in result["metric"] for m in DECIDING_METRICS)]
    if not deciding:
        return recorded != measured
    for key in deciding:
        old, new = before[key], after[key]
        if old["scalingFactor"] != new["scalingFactor"]:
            return True
        old_values = sorted(histogram_values(old["statistics"]["histogram"]))
        new_values = sorted(histogram_values(new["statistics"]["histogram"]))
        if not old_values or not new_values:
            return old_values != new_values
        for p, threshold in THRESHOLDS.items():
            base, comparison = percentile(old_values, p), percentile(new_values, p)
            if not comparison:
                # Dropping to zero (a benchmark that stopped allocating) is a move; staying at zero isn't.
                difference = 100.0 if base else 0.0
            else:
                difference = 100 - 100 * base / comparison
            if abs(difference) > threshold:
                return True
    return False


def entries(document):
    """A baseline's benchmarks: ordo-one encodes the dictionary as alternating keys and values."""
    results = document["results"]
    return {json.dumps(results[i], sort_keys=True): (results[i], results[i + 1]) for i in range(0, len(results), 2)}


def keep_unmoved(recorded, measured):
    """The measured baseline, where every benchmark that didn't move keeps its recorded entry.

    Re-recording a target measures all of its benchmarks, and the counts of one that didn't change
    still vary a little between runs. Keeping its entry leaves those lines untouched, so branches
    that each change a different benchmark of a target merge without a conflict.
    """
    kept = entries(recorded) if recorded else {}
    results = []
    for key, (identifier, entry) in sorted(entries(measured).items(), key=lambda item: (item[1][0].get("target", ""), item[1][0].get("name", ""))):
        if key in kept and not moved(kept[key][1], entry):
            entry = kept[key][1]
        results += [identifier, entry]
    return {**measured, "results": results}


def encode(value, indent=""):
    """JSON with sorted keys, one member per line, and an array of plain values on one line.

    A benchmark's entry spans its own lines, so a change to one benchmark touches none of the
    lines of another, and a histogram's counts stay on one line rather than thousands.
    """
    inner = indent + "  "
    if isinstance(value, dict):
        if not value:
            return "{}"
        members = [f"{inner}{json.dumps(key)}: {encode(value[key], inner)}" for key in sorted(value)]
        return "{\n" + ",\n".join(members) + "\n" + indent + "}"
    if isinstance(value, list) and any(isinstance(item, (dict, list)) for item in value):
        return "[\n" + ",\n".join(inner + encode(item, inner) for item in value) + "\n" + indent + "]"
    return json.dumps(value, separators=(",", ":"))


if __name__ == "__main__":
    main(sys.argv[1:])
