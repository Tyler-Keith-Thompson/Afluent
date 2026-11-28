"""A test written with Python's unittest, run by the host's python3.

The tests of the repository's own scripts need nothing beyond the standard library, so they run on
whatever python3 the machine has (macOS's, or the CI image's) rather than through rules_python's
toolchains, which would download an interpreter for a few hundred lines of tests. The test runs
from the runfiles root, where `data` sits at its workspace path.
"""

def _python_test_impl(ctx):
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        runner,
        '#!/bin/sh\nexec python3 -I "{}" "$@"\n'.format(ctx.file.src.short_path),
        is_executable = True,
    )
    return [DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(files = [ctx.file.src] + ctx.files.data),
    )]

python_test = rule(
    implementation = _python_test_impl,
    doc = "Runs a unittest file with the host's python3, from the runfiles root.",
    attrs = {
        "src": attr.label(allow_single_file = [".py"], mandatory = True),
        "data": attr.label_list(allow_files = True),
    },
    test = True,
)
