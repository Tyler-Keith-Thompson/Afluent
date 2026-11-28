"""Tests of tools/load-gate: which commands it holds, when it lets them through, and the hook's I/O."""

import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

RUNFILES = os.getcwd()
GATE = os.path.join(RUNFILES, "tools", "load-gate")

loader = importlib.machinery.SourceFileLoader("load_gate", GATE)
specification = importlib.util.spec_from_loader("load_gate", loader)
load_gate = importlib.util.module_from_spec(specification)
loader.exec_module(load_gate)


class FakeMachine:
    """A clock that sleeping advances, and a load average read from a list as time passes."""

    def __init__(self, loads, now=1_000_000.0):
        self.now = now
        self.loads = list(loads)

    def clock(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds

    def load(self):
        return self.loads.pop(0) if len(self.loads) > 1 else self.loads[0]


class HeavyTests(unittest.TestCase):
    def test_builds_and_tests_are_heavy(self):
        commands = [
            "bazel test //...",
            "bazel build //Sources/Greetings",
            "bazel --output_base=/tmp/x test --config=release //...",
            "perl -e 'alarm 1800; exec @ARGV' bazel test //Tests/GreetingsTests",
            "cd Benchmarks && swift build -c release",
            "swift test --parallel",
            "xcodebuild -scheme App test",
            "docker build -t app .",
            "just test",
            "just test-one //Tests/GreetingsTests",
            "just mutate Greetings --all",
            "git status && just spm-test",
            "kanban checks PT-1 -- just test",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertTrue(load_gate.is_heavy(command))

    def test_other_commands_are_light(self):
        commands = [
            "git status",
            "bazel query 'rdeps(//Tests/..., //Sources/X)'",
            "bazel shutdown",
            "bazel info output_base",
            "just modules",
            "just resolve",
            "just --list",
            "ls bazel-testlogs",
            "grep -n 'swift build' README.md",
            "python3 scripts/modules.py",
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertFalse(load_gate.is_heavy(command))


class GateTests(unittest.TestCase):
    def setUp(self):
        self.state = tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR"))

    def tearDown(self):
        shutil.rmtree(self.state, ignore_errors=True)

    def gate(self, machine, max_load=1.0, spacing=20, max_wait=600):
        return load_gate.Gate(self.state, max_load, spacing, max_wait,
                              clock=machine.clock, load=machine.load, sleep=machine.sleep)

    def test_an_idle_machine_lets_a_command_through_at_once(self):
        machine = FakeMachine([0.2])

        actual = self.gate(machine).wait()

        self.assertEqual(actual, 0)

    def test_a_busy_machine_holds_the_command_until_the_load_falls(self):
        machine = FakeMachine([2.0, 1.5, 1.2, 0.9])
        expected = 3 * load_gate.POLL_SECONDS

        actual = self.gate(machine).wait()

        self.assertEqual(actual, expected)

    def test_a_load_at_the_limit_passes(self):
        machine = FakeMachine([1.0])

        actual = self.gate(machine).wait()

        self.assertEqual(actual, 0)

    def test_a_second_command_waits_out_the_spacing_after_the_first(self):
        machine = FakeMachine([0.1])
        self.gate(machine).wait()
        expected = 20

        actual = self.gate(machine).wait()

        self.assertEqual(actual, expected)

    def test_a_command_after_the_spacing_starts_at_once(self):
        machine = FakeMachine([0.1])
        self.gate(machine).wait()
        machine.now += 21

        actual = self.gate(machine).wait()

        self.assertEqual(actual, 0)

    def test_a_machine_that_stays_busy_lets_the_command_through_after_the_maximum_wait(self):
        machine = FakeMachine([8.0])
        expected = 60

        actual = self.gate(machine, max_wait=60).wait()

        self.assertEqual(actual, expected)

    def test_an_unreadable_stamp_counts_as_no_earlier_admission(self):
        with open(os.path.join(self.state, "last-admission"), "w") as file:
            file.write("not a time\n")
        machine = FakeMachine([0.1])

        actual = self.gate(machine).wait()

        self.assertEqual(actual, 0)


class HookTests(unittest.TestCase):
    def setUp(self):
        self.state = tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR"))

    def tearDown(self):
        shutil.rmtree(self.state, ignore_errors=True)

    def run_gate(self, stdin, **environment):
        env = dict(os.environ, LOAD_GATE_STATE=self.state, **environment)
        return subprocess.run([sys.executable, "-I", GATE], input=stdin, capture_output=True,
                              text=True, env=env, timeout=60)

    def test_a_heavy_command_on_an_idle_machine_passes_silently(self):
        hook = json.dumps({"tool_name": "Bash", "tool_input": {"command": "bazel test //..."}})

        actual = self.run_gate(hook, LOAD_GATE_MAX_LOAD="1000000")

        self.assertEqual((actual.returncode, actual.stdout), (0, ""))
        self.assertTrue(os.path.exists(os.path.join(self.state, "last-admission")))

    def test_a_held_command_reports_the_wait(self):
        hook = json.dumps({"tool_name": "Bash", "tool_input": {"command": "just test"}})

        actual = self.run_gate(hook, LOAD_GATE_MAX_LOAD="-1", LOAD_GATE_MAX_WAIT="1")

        self.assertEqual(actual.returncode, 0)
        output = json.loads(actual.stdout)["hookSpecificOutput"]
        self.assertEqual(output["hookEventName"], "PreToolUse")
        self.assertIn("held this command", output["additionalContext"])

    def test_a_light_command_is_never_held(self):
        hook = json.dumps({"tool_name": "Bash", "tool_input": {"command": "git status"}})

        actual = self.run_gate(hook, LOAD_GATE_MAX_LOAD="-1")

        self.assertEqual((actual.returncode, actual.stdout), (0, ""))
        self.assertFalse(os.path.exists(os.path.join(self.state, "last-admission")))

    def test_turned_off_it_holds_nothing(self):
        hook = json.dumps({"tool_name": "Bash", "tool_input": {"command": "bazel test //..."}})

        actual = self.run_gate(hook, LOAD_GATE="off", LOAD_GATE_MAX_LOAD="-1")

        self.assertEqual((actual.returncode, actual.stdout), (0, ""))

    def test_input_that_isnt_a_hook_payload_passes(self):
        actual = self.run_gate("not json")

        self.assertEqual((actual.returncode, actual.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
