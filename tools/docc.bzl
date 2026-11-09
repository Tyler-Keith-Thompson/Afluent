"""DocC rules: one documentation archive per module, merged into one static site.

`docc_archive` extracts a module's symbol graph (with rules_swift's `extract_symbol_graph`) and
runs `docc convert` on it, with the archives of the module's dependencies passed as
`--dependency` so cross-module links resolve. `docc_site` runs `docc merge` over the archives.
Each module is its own action, so an unchanged module is a cache hit.

This is what the swift-docc-plugin does for `generate-documentation
--enable-experimental-combined-documentation`, with the same flags.
"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "@rules_swift//swift:providers.bzl",
    "SwiftInfo",
    "create_swift_module_context",
    "create_swift_module_inputs",
)
load("@rules_swift//swift:swift_common.bzl", "swift_common")

DoccArchiveInfo = provider(
    doc = "A module's DocC archive.",
    fields = {
        "archive": "The `.doccarchive` directory.",
        "symbol_graphs": "The directory of symbol graphs the archive was built from.",
    },
)

# The flags every `docc convert` gets; they have to agree across archives for `docc merge`.
_HOSTING_BASE_PATH = "Afluent"
_SOURCE_SERVICE_BASE_URL = "https://github.com/Tyler-Keith-Thompson/Afluent/blob/main"

# Where symbol graph source locations are rooted (see `_extract_symbol_graph`).
_CHECKOUT_ROOT = "/checkout"

def _docc(ctx):
    """The `docc` command and the environment and execution requirements to run it with.

    rules_swift's Xcode toolchain has no root directory; there `xcrun` finds docc in the Xcode
    that Bazel selected (Bazel sets DEVELOPER_DIR from the toolchain's environment). A Swift.org
    toolchain on Linux has a root directory, and docc is installed beside swiftc.
    """
    toolchain = swift_common.get_toolchain(ctx)
    config = toolchain.tool_configs["SwiftSymbolGraphExtract"]
    root_dir = getattr(toolchain, "root_dir", None)
    if root_dir:
        command = root_dir + "/bin/docc"
    else:
        command = "xcrun docc"
    return struct(
        command = command,
        env = config.env,
        execution_requirements = config.execution_requirements,
    )

def _catalog_path(files):
    """The `.docc` directory the catalog files are in, or None for a module without one."""
    for f in files:
        parts = f.path.split("/")
        for i, part in enumerate(parts):
            if part.endswith(".docc"):
                return "/".join(parts[:i + 1])
    return None

def _extract_symbol_graph(ctx, module_name):
    """Extracts the module's symbol graph into a directory, with source locations."""
    target = ctx.attr.module
    swift_info = target[SwiftInfo]
    swift_module = swift_info.direct_modules[0].swift
    swift_toolchain = swift_common.get_toolchain(ctx)
    feature_configuration = swift_common.configure_features(
        ctx = ctx,
        swift_toolchain = swift_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Source locations (for DocC's links to GitHub) come from the module's .swiftsourceinfo,
    # which the extractor finds beside the .swiftmodule. rules_swift makes only the
    # .swiftmodule and .swiftdoc inputs, so the .swiftsourceinfo rides along as the .swiftdoc of
    # a second entry for the same module.
    source_info = SwiftInfo(modules = [create_swift_module_context(
        name = module_name,
        swift = create_swift_module_inputs(
            swiftdoc = swift_module.swiftsourceinfo,
            swiftmodule = swift_module.swiftmodule,
        ),
    )])

    extracted = ctx.actions.declare_directory(module_name + ".extracted.symbolgraphs")
    swift_common.extract_symbol_graph(
        actions = ctx.actions,
        compilation_contexts = [target[CcInfo].compilation_context] if CcInfo in target else [],
        # Matches the swift-docc-plugin's defaults.
        emit_extension_block_symbols = "1",
        feature_configuration = feature_configuration,
        include_dev_srch_paths = False,
        minimum_access_level = "public",
        module_name = module_name,
        output_dir = extracted,
        swift_infos = [swift_info, source_info],
        swift_toolchain = swift_toolchain,
    )

    # The source locations are absolute paths into whichever execution root compiled the
    # module. Rewritten relative to a fixed checkout root, the symbol graphs (and everything
    # built from them) are the same on every machine.
    output_dir = ctx.actions.declare_directory(module_name + ".symbolgraphs")
    ctx.actions.run_shell(
        command = """\
for f in "$1"/*.json; do
  sed -E 's#"file://[^"]*/execroot/_main/#"file://{root}/#g' "$f" > "$2/${{f##*/}}"
done
""".format(root = _CHECKOUT_ROOT),
        arguments = [extracted.path, output_dir.path],
        inputs = [extracted],
        outputs = [output_dir],
        mnemonic = "DoccRelocateSymbolGraph",
        progress_message = "Relocating symbol graph for " + module_name,
    )
    return output_dir

def _generate_catalog(ctx, module_name, catalog_path, catalog):
    """Copies the catalog and runs `catalog_generator` to add generated pages to the copy.

    The generator is run as `python3 <script> --symbol-graph-dir <dir> --catalog <dir>`, with
    the symbol graphs of every module in `deps` in one directory.
    """
    generated = ctx.actions.declare_directory(module_name + ".docc")
    symbol_graphs = [dep[DoccArchiveInfo].symbol_graphs for dep in ctx.attr.deps]
    ctx.actions.run_shell(
        command = """\
set -e
script="$1"; source="$2"; catalog="$3"; shift 3
if [ -n "$source" ]; then cp -RL "$source"/. "$catalog"; fi
graphs="$(mktemp -d)"
for dir in "$@"; do cp "$dir"/*.json "$graphs"; done
python3 "$script" --symbol-graph-dir "$graphs" --catalog "$catalog" > /dev/null
rm -rf "$graphs"
""",
        arguments = [
            ctx.file.catalog_generator.path,
            catalog_path or "",
            generated.path,
        ] + [d.path for d in symbol_graphs],
        inputs = depset(catalog + symbol_graphs + ctx.files.catalog_generator_srcs + [ctx.file.catalog_generator]),
        outputs = [generated],
        env = {"PYTHONDONTWRITEBYTECODE": "1"},
        mnemonic = "DoccGenerateCatalog",
        progress_message = "Generating documentation pages for " + module_name,
    )
    return generated.path, [generated]

def _docc_archive_impl(ctx):
    module_name = ctx.attr.module[SwiftInfo].direct_modules[0].name
    symbol_graph_dir = _extract_symbol_graph(ctx, module_name)

    catalog = ctx.files.catalog
    catalog_path = _catalog_path(catalog)
    if ctx.file.catalog_generator:
        catalog_path, catalog = _generate_catalog(ctx, module_name, catalog_path, catalog)
    dependencies = [dep[DoccArchiveInfo].archive for dep in ctx.attr.deps]
    archive = ctx.actions.declare_directory(module_name + ".doccarchive")

    args = ctx.actions.args()
    args.add("convert")
    if catalog_path:
        args.add(catalog_path)
    args.add("--fallback-display-name", module_name)
    args.add("--fallback-bundle-identifier", module_name)
    args.add("--additional-symbol-graph-dir", symbol_graph_dir.path)
    args.add("--output-path", archive.path)
    args.add("--enable-experimental-external-link-support")
    for dependency in dependencies:
        args.add("--dependency", dependency.path)
    args.add("--transform-for-static-hosting")
    args.add("--hosting-base-path", _HOSTING_BASE_PATH)
    args.add("--source-service", "github")
    args.add("--source-service-base-url", _SOURCE_SERVICE_BASE_URL)
    args.add("--checkout-path", _CHECKOUT_ROOT)

    # Any warning (a link that doesn't resolve, a missing symbol) fails the action, as
    # first-party compiler warnings do. docc writes its diagnostics to standard output, with its
    # progress, so the output is shown only when the action fails.
    args.add("--warnings-as-errors")

    docc = _docc(ctx)
    ctx.actions.run_shell(
        command = 'output="$(' + docc.command + ' "$@" 2>&1)" || { printf "%s\\n" "$output"; exit 1; }',
        arguments = [args],
        inputs = depset([symbol_graph_dir] + catalog + dependencies),
        outputs = [archive],
        env = docc.env,
        execution_requirements = docc.execution_requirements,
        mnemonic = "DoccConvert",
        progress_message = "Building documentation for " + module_name,
    )
    return [
        DefaultInfo(files = depset([archive])),
        DoccArchiveInfo(archive = archive, symbol_graphs = symbol_graph_dir),
    ]

docc_archive = rule(
    implementation = _docc_archive_impl,
    doc = "Builds a static-hosting DocC archive for one Swift module.",
    attrs = {
        "module": attr.label(
            mandatory = True,
            providers = [SwiftInfo],
            doc = "The swift_library to document.",
        ),
        "catalog": attr.label_list(
            allow_files = True,
            doc = "The files of the module's `.docc` catalog, if it has one.",
        ),
        "deps": attr.label_list(
            providers = [DoccArchiveInfo],
            doc = "The archives of the module's first-party dependencies, for cross-module links.",
        ),
        "catalog_generator": attr.label(
            allow_single_file = [".py"],
            doc = "A script that adds generated pages to the catalog; see `_generate_catalog`.",
        ),
        "catalog_generator_srcs": attr.label_list(
            allow_files = [".py"],
            doc = "Modules the generator imports.",
        ),
    },
    fragments = ["cpp"],
    toolchains = swift_common.use_toolchain(),
)

def _docc_site_impl(ctx):
    archives = [a[DoccArchiveInfo].archive for a in ctx.attr.archives]
    site = ctx.actions.declare_directory(ctx.label.name)

    docc = _docc(ctx)
    ctx.actions.run_shell(
        # The inputs are symlinks in a sandbox, and `docc merge` copies symlinks as they are, so
        # it is given real, writable copies.
        command = """\
set -e
site="$1"; name="$2"; shift 2
copies="$(mktemp -d)"
for archive in "$@"; do cp -RL "$archive" "$copies"; done
chmod -R u+w "$copies"
# `docc merge` takes no --warnings-as-errors, so a warning in its output fails the action here.
status=0
output="$({docc} merge "$copies"/*.doccarchive --output-path "$site" \\
  --synthesized-landing-page-name "$name" --synthesized-landing-page-kind Package 2>&1)" || status=$?
rm -rf "$copies"
if [ "$status" -ne 0 ] || printf "%s\\n" "$output" | grep -q "warning:"; then
  printf "%s\\n" "$output"
  exit 1
fi
""".format(docc = docc.command),
        arguments = [site.path, ctx.attr.landing_page_name] + [a.path for a in archives],
        inputs = archives,
        outputs = [site],
        env = docc.env,
        execution_requirements = docc.execution_requirements,
        mnemonic = "DoccMerge",
        progress_message = "Merging documentation into " + ctx.label.name,
    )
    return [DefaultInfo(files = depset([site]))]

docc_site = rule(
    implementation = _docc_site_impl,
    doc = "Merges DocC archives into one static site with a synthesized landing page.",
    attrs = {
        "archives": attr.label_list(mandatory = True, providers = [DoccArchiveInfo]),
        "landing_page_name": attr.string(mandatory = True),
    },
    toolchains = swift_common.use_toolchain(),
)
