"""Tests of tools/docc_symbol_graph.py: relocated source info, relocated symbol graphs, the guard."""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

RUNFILES = os.getcwd()
TOOL = os.path.join(RUNFILES, "tools", "docc_symbol_graph.py")

specification = importlib.util.spec_from_file_location("docc_symbol_graph", TOOL)
docc_symbol_graph = importlib.util.module_from_spec(specification)
specification.loader.exec_module(docc_symbol_graph)


class SourceInfoTests(unittest.TestCase):
    def test_each_sources_prefix_becomes_a_relative_one_of_the_same_length(self):
        data = (
            b"\x04\x00\x00\x00/gone/output/execroot/_main/Sources/A/A.swift\x00"
            b"/gone/output/execroot/_main/Sources/A/Other.swift\x00\x22\x0e"
        )

        actual, count = docc_symbol_graph.relocate_source_info(
            data, ["Sources/A/A.swift", "Sources/A/Other.swift"]
        )

        expected_prefix = b"./" * 14
        self.assertEqual(count, 2)
        self.assertEqual(len(actual), len(data))
        self.assertEqual(
            actual,
            b"\x04\x00\x00\x00" + expected_prefix + b"Sources/A/A.swift\x00"
            + expected_prefix + b"Sources/A/Other.swift\x00\x22\x0e",
        )

    def test_an_odd_length_prefix_ends_in_a_doubled_slash(self):
        data = b"\x00/odd1/execroot/_main/Sources/A/A.swift\x00"

        actual, count = docc_symbol_graph.relocate_source_info(data, ["Sources/A/A.swift"])

        expected = b"\x00" + b"./" * 9 + b".//" + b"Sources/A/A.swift\x00"
        self.assertEqual(count, 1)
        self.assertEqual(actual, expected)

    def test_a_path_from_any_root_is_relocated_not_only_an_execution_root(self):
        data = b"\x00/b/f/ws/Sources/A/A.swift\x00"

        actual, count = docc_symbol_graph.relocate_source_info(data, ["Sources/A/A.swift"])

        expected = b"\x00././././Sources/A/A.swift\x00"
        self.assertEqual(count, 1)
        self.assertEqual(actual, expected)

    def test_a_path_that_only_ends_like_a_source_is_left_alone(self):
        data = b"\x00/root/Sources/A/NotA.swift\x00/root/Sources/A/A.swift.orig\x00"

        actual, count = docc_symbol_graph.relocate_source_info(data, ["Sources/A/A.swift"])

        self.assertEqual(count, 0)
        self.assertEqual(actual, data)

    def test_no_sources_leave_the_data_unchanged(self):
        data = b"\x00/root/execroot/_main/Sources/A/A.swift\x00"

        actual, count = docc_symbol_graph.relocate_source_info(data, [])

        self.assertEqual(count, 0)
        self.assertEqual(actual, data)

    def test_no_relative_prefix_is_one_byte_long(self):
        with self.assertRaises(ValueError):
            docc_symbol_graph.relative_prefix(1)


class RelocationTests(unittest.TestCase):
    def test_a_relative_uri_is_rooted_at_the_checkout(self):
        text = '{"uri":"file://./././/Sources/A/A.swift"}'

        actual = docc_symbol_graph.relocated(text, "/checkout")

        expected = '{"uri":"file:///checkout/Sources/A/A.swift"}'
        self.assertEqual(actual, expected)

    def test_an_execution_root_uri_is_rooted_at_the_checkout(self):
        text = '{"uri":"file:///var/out/execroot/_main/Sources/A/A.swift"}'

        actual = docc_symbol_graph.relocated(text, "/checkout")

        expected = '{"uri":"file:///checkout/Sources/A/A.swift"}'
        self.assertEqual(actual, expected)

    def test_another_absolute_uri_is_left_alone(self):
        text = '{"uri":"file:///usr/include/stdio.h"}'

        actual = docc_symbol_graph.relocated(text, "/checkout")

        self.assertEqual(actual, text)

    def test_doc_comment_uris_are_relocated_as_well_as_symbol_locations(self):
        text = (
            '{"docComment":{"uri":"file://././Sources/A/A.swift"},'
            '"location":{"uri":"file://././Sources/A/A.swift"}}'
        )

        actual = docc_symbol_graph.relocated(text, "/checkout")

        expected = (
            '{"docComment":{"uri":"file:///checkout/Sources/A/A.swift"},'
            '"location":{"uri":"file:///checkout/Sources/A/A.swift"}}'
        )
        self.assertEqual(actual, expected)


class GuardTests(unittest.TestCase):
    def test_a_documented_symbol_without_a_location_is_reported(self):
        graph = {"symbols": [
            {"identifier": {"precise": "s:1A5ThingV"}, "docComment": {"lines": []}},
        ]}

        actual = docc_symbol_graph.documented_without_location(graph, "A")

        self.assertEqual(actual, ["s:1A5ThingV"])

    def test_a_documented_symbol_with_a_location_is_not_reported(self):
        graph = {"symbols": [
            {
                "identifier": {"precise": "s:1A5ThingV"},
                "docComment": {"lines": []},
                "location": {"uri": "file:///checkout/Sources/A/A.swift"},
            },
        ]}

        actual = docc_symbol_graph.documented_without_location(graph, "A")

        self.assertEqual(actual, [])

    def test_an_undocumented_symbol_without_a_location_is_not_reported(self):
        graph = {"symbols": [{"identifier": {"precise": "s:1A5ThingV"}}]}

        actual = docc_symbol_graph.documented_without_location(graph, "A")

        self.assertEqual(actual, [])

    def test_a_synthesized_member_is_not_reported(self):
        graph = {"symbols": [
            {
                "identifier": {"precise": "s:SQsE2neoiySbx_xtFZ::SYNTHESIZED::s:1A5ThingV"},
                "docComment": {"lines": []},
            },
        ]}

        actual = docc_symbol_graph.documented_without_location(graph, "A")

        self.assertEqual(actual, [])

    def test_a_doc_comment_inherited_from_another_module_is_not_reported(self):
        graph = {"symbols": [
            {"identifier": {"precise": "s:1A5ThingV4hashyys"}, "docComment": {"module": "Swift"}},
        ]}

        actual = docc_symbol_graph.documented_without_location(graph, "A")

        self.assertEqual(actual, [])


class MockTests(unittest.TestCase):
    def test_a_generated_double_and_its_members_are_found_in_every_graph(self):
        graphs = [
            {
                "symbols": [
                    {"identifier": {"precise": "s:1A5StoreP"}, "kind": {"identifier": "swift.protocol"},
                     "pathComponents": ["Store"], "location": {"uri": "file://././Sources/A/Store.swift"}},
                    {"identifier": {"precise": "s:1A9MockStoreC"}, "kind": {"identifier": "swift.class"},
                     "pathComponents": ["MockStore"]},
                    {"identifier": {"precise": "s:1A9MockStoreC4keepyyF"}, "kind": {"identifier": "swift.method"},
                     "pathComponents": ["MockStore", "keep()"]},
                    {"identifier": {"precise": "s:1A9MockStoreC6MemberO"}, "kind": {"identifier": "swift.enum"},
                     "pathComponents": ["MockStore", "Member"]},
                ],
                "relationships": [{"source": "s:1A9MockStoreC", "target": "s:1A5StoreP", "kind": "conformsTo"}],
            },
            {"symbols": [
                {"identifier": {"precise": "s:e:s:1A9MockStoreC"}, "kind": {"identifier": "swift.extension"},
                 "pathComponents": ["MockStore"]},
            ]},
        ]
        expected = {"s:1A9MockStoreC", "s:1A9MockStoreC4keepyyF", "s:1A9MockStoreC6MemberO", "s:e:s:1A9MockStoreC"}

        actual = docc_symbol_graph.generated_mocks(graphs)

        self.assertEqual(actual, expected)

    def test_a_hand_written_double_with_a_location_is_not_a_generated_one(self):
        graphs = [{
            "symbols": [
                {"identifier": {"precise": "s:1A5StoreP"}, "kind": {"identifier": "swift.protocol"},
                 "pathComponents": ["Store"]},
                {"identifier": {"precise": "s:1A9MockStoreV"}, "kind": {"identifier": "swift.struct"},
                 "pathComponents": ["MockStore"], "location": {"uri": "file://././Sources/A/MockStore.swift"}},
            ],
            "relationships": [{"source": "s:1A9MockStoreV", "target": "s:1A5StoreP", "kind": "conformsTo"}],
        }]

        actual = docc_symbol_graph.generated_mocks(graphs)

        self.assertEqual(actual, set())

    def test_a_mock_named_type_that_conforms_to_no_protocol_of_that_name_is_not_a_double(self):
        graphs = [{
            "symbols": [
                {"identifier": {"precise": "s:1A5StoreP"}, "kind": {"identifier": "swift.protocol"},
                 "pathComponents": ["Store"]},
                {"identifier": {"precise": "s:1A9MockThingV"}, "kind": {"identifier": "swift.struct"},
                 "pathComponents": ["MockThing"]},
            ],
            "relationships": [{"source": "s:1A9MockThingV", "target": "s:1A5StoreP", "kind": "conformsTo"}],
        }]

        actual = docc_symbol_graph.generated_mocks(graphs)

        self.assertEqual(actual, set())

    def test_without_drops_the_symbols_and_the_relationships_naming_them(self):
        graph = {
            "symbols": [{"identifier": {"precise": "s:1A5StoreP"}}, {"identifier": {"precise": "s:1A9MockStoreC"}}],
            "relationships": [
                {"source": "s:1A9MockStoreC", "target": "s:1A5StoreP", "kind": "conformsTo"},
                {"source": "s:1A5ThingV", "target": "s:1A5StoreP", "kind": "conformsTo"},
            ],
        }
        expected = {
            "symbols": [{"identifier": {"precise": "s:1A5StoreP"}}],
            "relationships": [{"source": "s:1A5ThingV", "target": "s:1A5StoreP", "kind": "conformsTo"}],
        }

        actual = docc_symbol_graph.without(graph, {"s:1A9MockStoreC"})

        self.assertEqual(actual, expected)


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR"))
        self.source = os.path.join(self.directory, "extracted")
        self.output = os.path.join(self.directory, "relocated")
        os.makedirs(self.source)
        os.makedirs(self.output)

    def tearDown(self):
        shutil.rmtree(self.directory, ignore_errors=True)

    def test_symbol_graph_fails_naming_the_symbols_without_a_location(self):
        graph = {"symbols": [{"identifier": {"precise": "s:1A5ThingV"}, "docComment": {}}]}
        with open(os.path.join(self.source, "A.symbols.json"), "w") as f:
            json.dump(graph, f)

        actual = subprocess.run(
            [sys.executable, TOOL, "symbol-graph", "A", "/checkout", self.source, self.output],
            capture_output=True,
            text=True,
        )

        self.assertEqual(actual.returncode, 1)
        self.assertIn("1 documented symbol(s) of A have no source location", actual.stderr)
        self.assertIn("s:1A5ThingV", actual.stderr)

    def test_symbol_graph_leaves_out_a_generated_double_whose_members_have_no_location(self):
        graph = {
            "symbols": [
                {"identifier": {"precise": "s:1A5StoreP"}, "kind": {"identifier": "swift.protocol"},
                 "pathComponents": ["Store"], "docComment": {}, "location": {"uri": "file://././Sources/A/Store.swift"}},
                {"identifier": {"precise": "s:1A9MockStoreC"}, "kind": {"identifier": "swift.class"},
                 "pathComponents": ["MockStore"]},
                {"identifier": {"precise": "s:1A9MockStoreC4keepyyF"}, "kind": {"identifier": "swift.method"},
                 "pathComponents": ["MockStore", "keep()"], "docComment": {}},
            ],
            "relationships": [{"source": "s:1A9MockStoreC", "target": "s:1A5StoreP", "kind": "conformsTo"}],
        }
        with open(os.path.join(self.source, "A.symbols.json"), "w") as f:
            json.dump(graph, f)
        expected_symbols = ["s:1A5StoreP"]
        expected_uri = "file:///checkout/Sources/A/Store.swift"

        actual = subprocess.run(
            [sys.executable, TOOL, "symbol-graph", "A", "/checkout", self.source, self.output],
            capture_output=True,
            text=True,
        )

        self.assertEqual(actual.returncode, 0, actual.stderr)
        with open(os.path.join(self.output, "A.symbols.json")) as f:
            written = json.load(f)
        self.assertEqual([symbol["identifier"]["precise"] for symbol in written["symbols"]], expected_symbols)
        self.assertEqual(written["symbols"][0]["location"]["uri"], expected_uri)
        self.assertEqual(written["relationships"], [])

    def test_symbol_graph_still_fails_on_an_ordinary_symbol_without_a_location_beside_a_double(self):
        graph = {
            "symbols": [
                {"identifier": {"precise": "s:1A5StoreP"}, "kind": {"identifier": "swift.protocol"},
                 "pathComponents": ["Store"]},
                {"identifier": {"precise": "s:1A9MockStoreC"}, "kind": {"identifier": "swift.class"},
                 "pathComponents": ["MockStore"]},
                {"identifier": {"precise": "s:1A5ThingV"}, "kind": {"identifier": "swift.struct"},
                 "pathComponents": ["Thing"], "docComment": {}},
            ],
            "relationships": [{"source": "s:1A9MockStoreC", "target": "s:1A5StoreP", "kind": "conformsTo"}],
        }
        with open(os.path.join(self.source, "A.symbols.json"), "w") as f:
            json.dump(graph, f)

        actual = subprocess.run(
            [sys.executable, TOOL, "symbol-graph", "A", "/checkout", self.source, self.output],
            capture_output=True,
            text=True,
        )

        self.assertEqual(actual.returncode, 1)
        self.assertIn("1 documented symbol(s) of A have no source location", actual.stderr)
        self.assertIn("s:1A5ThingV", actual.stderr)

    def test_symbol_graph_writes_every_graph_relocated(self):
        text = '{"symbols":[{"identifier":{"precise":"s:1A5ThingV"},"docComment":{},' \
            '"location":{"uri":"file://././Sources/A/A.swift"}}]}'
        for name in ["A.symbols.json", "A@Swift.symbols.json"]:
            with open(os.path.join(self.source, name), "w") as f:
                f.write(text)

        actual = subprocess.run(
            [sys.executable, TOOL, "symbol-graph", "A", "/checkout", self.source, self.output],
            capture_output=True,
            text=True,
        )

        expected = text.replace("file://././", "file:///checkout/")
        self.assertEqual(actual.returncode, 0, actual.stderr)
        self.assertEqual(sorted(os.listdir(self.output)), ["A.symbols.json", "A@Swift.symbols.json"])
        for name in os.listdir(self.output):
            with open(os.path.join(self.output, name)) as f:
                self.assertEqual(f.read(), expected)


if __name__ == "__main__":
    unittest.main()
