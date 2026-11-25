"""Swift sources a generator writes at build time, with a checked-in copy for SwiftPM.

Bazel compiles the generator's output directly, so it never goes stale there. SwiftPM cannot run
the generator, so the published package compiles a copy kept under the module's `Generated/`
directory. `generated_swift_source` declares both halves: a genrule running `generator`, and a
test that fails when the checked-in copy differs from what the generator writes now. `just
modules` writes the calls from GENERATED_SOURCES in scripts/modules.py, and `just sources`
refreshes every copy.
"""

GeneratedSwiftSourcesInfo = provider(
    doc = "Sources a generator writes at build time, each with the path of the checked-in copy SwiftPM compiles in its place.",
    fields = {"destinations": "dict from each generated File to its copy's path from the workspace root"},
)

def _generated_swift_sources_impl(ctx):
    package = ctx.label.package + "/" if ctx.label.package else ""
    files = ctx.files.generated
    return [
        DefaultInfo(files = depset(files)),
        GeneratedSwiftSourcesInfo(destinations = {
            file: package + "Generated/" + file.short_path.removeprefix(package)
            for file in files
        }),
    ]

# The genrule's outputs, with the paths of their checked-in copies, so the simulated benchmarks
# (tools/benchmarks.bzl) stage the generator's output where SwiftPM reads the copy. A genrule can't
# return a provider, and `just sources` finds the genrules by kind, so this wraps one.
_generated_swift_sources = rule(
    implementation = _generated_swift_sources_impl,
    doc = "A genrule's Swift sources, carrying GeneratedSwiftSourcesInfo.",
    attrs = {"generated": attr.label(mandatory = True)},
)

_SCRIPT = """#!/bin/sh
set -eu
stale=0
while [ $# -gt 0 ]; do
    if ! diff -u "$1" "$2"; then
        echo
        echo "$1 is stale (- checked in, + generated)."
        stale=1
    fi
    shift 2
done
if [ "$stale" -ne 0 ]; then
    echo "Run \\`just sources\\` and commit the result."
    exit 1
fi
"""

def _generated_source_test_impl(ctx):
    checker = ctx.actions.declare_file(ctx.label.name + ".check.sh")
    ctx.actions.write(checker, _SCRIPT, is_executable = True)
    checked_in = {f.basename: f for f in ctx.files.checked_in}
    generated = {f.basename: f for f in ctx.files.generated}
    if sorted(checked_in) != sorted(generated):
        fail("checked-in copies {} differ from generated files {}; run `just sources`".format(sorted(checked_in), sorted(generated)))
    pairs = " ".join(['"{}" "{}"'.format(checked_in[n].short_path, generated[n].short_path) for n in sorted(generated)])
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        runner,
        '#!/bin/sh\nexec "{}" {}\n'.format(checker.short_path, pairs),
        is_executable = True,
    )
    return [DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(files = [checker] + ctx.files.checked_in + ctx.files.generated),
    )]

_generated_source_test = rule(
    implementation = _generated_source_test_impl,
    doc = "Fails when a checked-in generated source differs from the generator's output.",
    attrs = {
        "checked_in": attr.label_list(allow_files = True, mandatory = True),
        "generated": attr.label(mandatory = True),
    },
    test = True,
)

def generated_swift_source(name, generator, srcs = [], outs = [], tags = []):
    """Sources written by `generator`, and `name`_test, comparing them with their copies under Generated/.

    With no `outs`, the generator writes one source, `name`.swift, to standard output, checked in
    as Generated/`name`.swift. With `outs`, it writes `name`/`out`.swift for each of them, getting
    their paths as arguments before a `--`, checked in under Generated/`name`/. The genrule is
    `name`_generator; `name` holds its sources with GeneratedSwiftSourcesInfo.

    Args:
      name: The source's name, without `.swift`, or the directory of the sources.
      generator: An executable that writes the sources.
      srcs: Files the generator reads, passed to it as arguments (their paths from the workspace root).
      outs: The names of the sources, without `.swift`, when there are several.
      tags: Tags for the test.
    """
    if outs:
        files = [name + "/" + out + ".swift" for out in outs]
        cmd = "$(execpath {}) $(OUTS) -- $(SRCS)".format(generator)
        checked_in = ["Generated/" + f for f in files]
    else:
        files = [name + ".swift"]
        cmd = "$(execpath {}) $(SRCS) > $@".format(generator) if srcs else "$(execpath {}) > $@".format(generator)
        checked_in = ["Generated/" + name + ".swift"]
    native.genrule(
        name = name + "_generator",
        srcs = srcs,
        outs = files,
        cmd = cmd,
        tools = [generator],
    )
    _generated_swift_sources(
        name = name,
        generated = ":" + name + "_generator",
    )
    _generated_source_test(
        name = name + "_test",
        size = "small",
        checked_in = checked_in,
        generated = ":" + name,
        tags = tags,
    )
