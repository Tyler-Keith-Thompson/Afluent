"""Source locations for the DocC rules (tools/docc.bzl), independent of where a module compiled.

`swift-symbolgraph-extract` takes each symbol's location from the module's `.swiftsourceinfo`,
which records every source file by the absolute path it was compiled at. A compile that came from
a cache (`--disk_cache`, BuildBuddy) ran in another checkout, and when that checkout is gone the
extractor drops every location. DocC reports doc-comment problems only for symbols with a
location, so a link that doesn't resolve would pass `--warnings-as-errors` unseen.

    source-info IN OUT SRC...
        Copies the `.swiftsourceinfo` with each source's directory prefix rewritten to a relative
        one of the same length (`././…/`), so the extractor, run from the execution root with the
        sources as inputs, reads this checkout's copy of each file. The prefix sits in a string
        table between NUL bytes, so a replacement of the same length leaves every offset intact.

    symbol-graph MODULE ROOT IN OUT
        Copies each `.symbols.json` with locations rooted at ROOT (the `--checkout-path` given to
        `docc convert`), so the archives are the same on every machine, and fails when a symbol
        the module documents has no location, naming the first few. The `Mock<Protocol>` doubles
        `@Mockable` generates (under MOCKING, defined in the debug builds `//:docs` extracts from)
        are left out with their members: they are test doubles, not API, and code a macro expands
        has no location to check.
"""

import json
import os
import re
import sys


def relative_prefix(length):
    """A relative path prefix of `length` bytes that names the current directory."""
    if length < 2:
        raise ValueError(f"no relative prefix is {length} byte(s) long")
    if length % 2 == 0:
        return b"./" * (length // 2)
    return b"./" * ((length - 3) // 2) + b".//"


def relocate_source_info(data, sources):
    """`data` with the directory prefix of every path ending in one of `sources` made relative.

    Returns the new bytes and how many paths were rewritten.
    """
    count = 0
    for source in sources:
        pattern = re.compile(rb"(?<=\x00)/[^\x00]*/(?=" + re.escape(source.encode()) + rb"\x00)")

        def replace(match):
            nonlocal count
            count += 1
            return relative_prefix(len(match.group(0)))

        data = pattern.sub(replace, data)
    return data, count


# A `file://` URI whose path is relative (`file://./././/Sources/…`), or absolute into an
# execution root, as the extractor writes them for symbol and doc-comment locations.
_PREFIX = re.compile(r'"file://(?:\./(?:\./|/)*(?=[^./"])|[^"]*/execroot/_main/)')


def relocated(text, root):
    """The symbol graph's text with every source URI rooted at `root`."""
    return _PREFIX.sub(f'"file://{root}/', text)


def documented_without_location(graph, module):
    """The precise identifiers of symbols the module documents that have no location.

    Synthesized members (default implementations reached through a protocol) never have a
    location, and a doc comment inherited from another module is that module's to check.
    """
    missing = []
    for symbol in graph.get("symbols", []):
        identifier = symbol["identifier"]["precise"]
        comment = symbol.get("docComment")
        if comment is None or "location" in symbol or "::SYNTHESIZED::" in identifier:
            continue
        if comment.get("module", module) != module:
            continue
        missing.append(identifier)
    return missing


def generated_mocks(graphs):
    """The precise identifiers of the `@Mockable` doubles in `graphs`, and of their members.

    A double is a top-level type with no location (a macro expanded it) named `Mock` and the name
    of a protocol it conforms to, as Mockable names the one it generates for a protocol. A
    hand-written `MockX` has a location, so it stays in the docs.
    """
    symbols = [symbol for graph in graphs for symbol in graph.get("symbols", [])]
    protocols = {
        symbol["identifier"]["precise"]: symbol["pathComponents"][-1]
        for symbol in symbols
        if symbol.get("kind", {}).get("identifier") == "swift.protocol"
    }
    roots = {
        symbol["identifier"]["precise"]: symbol["pathComponents"][0]
        for symbol in symbols
        if len(symbol.get("pathComponents", [])) == 1 and "location" not in symbol
    }
    mocks = {
        roots[relationship["source"]]
        for graph in graphs
        for relationship in graph.get("relationships", [])
        if relationship.get("kind") == "conformsTo"
        and relationship.get("source") in roots
        and roots[relationship["source"]] == "Mock" + protocols.get(relationship.get("target"), "")
    }
    return {symbol["identifier"]["precise"] for symbol in symbols if symbol.get("pathComponents", [None])[0] in mocks}


def without(graph, identifiers):
    """`graph` without the symbols of `identifiers` and the relationships that name one."""
    return dict(
        graph,
        symbols=[symbol for symbol in graph.get("symbols", []) if symbol["identifier"]["precise"] not in identifiers],
        relationships=[
            relationship for relationship in graph.get("relationships", [])
            if relationship.get("source") not in identifiers and relationship.get("target") not in identifiers
        ],
    )


def _source_info(arguments):
    source, output, *sources = arguments
    with open(source, "rb") as f:
        data = f.read()
    data, _ = relocate_source_info(data, sources)
    with open(output, "wb") as f:
        f.write(data)


def _symbol_graph(arguments):
    module, root, source, output = arguments
    texts = {}
    for name in sorted(os.listdir(source)):
        if name.endswith(".json"):
            with open(os.path.join(source, name)) as f:
                texts[name] = f.read()
    graphs = {name: json.loads(text) for name, text in texts.items()}
    mocks = generated_mocks(graphs.values())
    missing = []
    for name, text in texts.items():
        graph = without(graphs[name], mocks) if mocks else graphs[name]
        # Rewritten only when a double was there, so every other graph is copied byte for byte.
        if graph != graphs[name]:
            text = json.dumps(graph)
        missing += documented_without_location(graph, module)
        with open(os.path.join(output, name), "w") as f:
            f.write(relocated(text, root))
    if missing:
        shown = "\n".join("  " + identifier for identifier in missing[:5])
        more = f"\n  … and {len(missing) - 5} more" if len(missing) > 5 else ""
        sys.stderr.write(
            f"error: {len(missing)} documented symbol(s) of {module} have no source location, so "
            "docc would skip checking their doc comments:\n"
            f"{shown}{more}\n"
            "The extractor could not read the sources the module's .swiftsourceinfo names "
            "(tools/docc_symbol_graph.py explains how they are found).\n"
        )
        sys.exit(1)


def main(arguments):
    command, *rest = arguments
    {"source-info": _source_info, "symbol-graph": _symbol_graph}[command](rest)


if __name__ == "__main__":
    main(sys.argv[1:])
