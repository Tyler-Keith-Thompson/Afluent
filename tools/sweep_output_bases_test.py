"""Tests of tools/sweep-output-bases against a fake output user root, and of how tools/bazel starts it."""

import hashlib
import importlib.machinery
import importlib.util
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

RUNFILES = os.getcwd()
SWEEP = os.path.join(RUNFILES, "tools", "sweep-output-bases")
WRAPPER = os.path.join(RUNFILES, "tools", "bazel")
DAY = 24 * 60 * 60

loader = importlib.machinery.SourceFileLoader("sweep_output_bases", SWEEP)
specification = importlib.util.spec_from_loader("sweep_output_bases", loader)
sweep_output_bases = importlib.util.module_from_spec(specification)
loader.exec_module(sweep_output_bases)


class SweepTests(unittest.TestCase):
    def setUp(self):
        self.directory = os.path.realpath(tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR")))
        self.root = os.path.join(self.directory, "_bazel_user")
        os.makedirs(self.root)
        self.workspace = os.path.join(self.directory, "current")
        os.makedirs(self.workspace)
        self.now = time.time()

    def tearDown(self):
        shutil.rmtree(self.directory, ignore_errors=True)

    def make_output_base(self, workspace, idle_days=0, name=None):
        """An output base laid out as Bazel leaves one, last used idle_days ago."""
        name = name or hashlib.md5(workspace.encode()).hexdigest()
        base = os.path.join(self.root, name)
        os.makedirs(os.path.join(base, "server"))
        with open(os.path.join(base, "README"), "w") as file:
            file.write(f"WORKSPACE: {workspace}\n\nThe first line of this file is intentionally easy to parse.\n")
        with open(os.path.join(base, "command.log"), "w") as file:
            file.write("INFO: Build completed successfully\n")
        os.symlink(os.path.join(self.root, "install", "abc"), os.path.join(base, "install"))
        # Bazel makes external repositories read-only.
        external = os.path.join(base, "external", "rules_swift+")
        os.makedirs(external)
        with open(os.path.join(external, "BUILD.bazel"), "w") as file:
            file.write("")
        os.chmod(external, 0o555)
        os.chmod(os.path.join(base, "external"), 0o555)
        used = self.now - idle_days * DAY
        for path in (os.path.join(base, "command.log"), base):
            os.utime(path, (used, used))
        return base

    def sweep(self, max_idle_days=7):
        return sweep_output_bases.sweep(self.root, self.workspace, self.now, max_idle_days * DAY)

    def test_an_output_base_whose_workspace_is_gone_is_deleted(self):
        base = self.make_output_base(os.path.join(self.directory, "deleted-checkout"))

        actual = self.sweep()

        self.assertEqual(actual, [base])
        self.assertFalse(os.path.lexists(base))

    def test_an_output_base_named_only_in_do_not_build_here_is_deleted_when_that_workspace_is_gone(self):
        base = self.make_output_base(os.path.join(self.directory, "deleted-checkout"))
        os.remove(os.path.join(base, "README"))
        with open(os.path.join(base, "DO_NOT_BUILD_HERE"), "w") as file:
            file.write(os.path.join(self.directory, "deleted-checkout"))
        os.utime(base, (self.now, self.now))

        actual = self.sweep()

        self.assertEqual(actual, [base])

    def test_an_output_base_idle_for_more_than_seven_days_is_deleted(self):
        live = os.path.join(self.directory, "idle-checkout")
        os.makedirs(live)
        base = self.make_output_base(live, idle_days=8)

        actual = self.sweep()

        self.assertEqual(actual, [base])
        self.assertTrue(os.path.isdir(live))

    def test_an_output_base_used_within_seven_days_is_kept(self):
        live = os.path.join(self.directory, "recent-checkout")
        os.makedirs(live)
        base = self.make_output_base(live, idle_days=6)

        actual = self.sweep()

        self.assertEqual(actual, [])
        self.assertTrue(os.path.isdir(base))

    def test_the_current_workspaces_output_base_is_kept_however_long_it_was_idle(self):
        base = self.make_output_base(self.workspace, idle_days=30)

        actual = self.sweep()

        self.assertEqual(actual, [])
        self.assertTrue(os.path.isdir(base))

    def test_an_output_base_naming_the_current_workspace_is_kept_under_any_name(self):
        base = self.make_output_base(self.workspace, idle_days=30, name="0" * 32)

        actual = self.sweep()

        self.assertEqual(actual, [])
        self.assertTrue(os.path.isdir(base))

    def test_a_release_output_base_whose_checkout_is_gone_is_deleted(self):
        checkout = os.path.join(self.directory, "deleted-checkout")
        # Named as the justfile's BAZEL_RELEASE_OUTPUT_BASE names it.
        name = hashlib.sha256(f"{checkout}:release".encode()).hexdigest()[:32]
        base = self.make_output_base(checkout, name=name)

        actual = self.sweep()

        self.assertEqual(actual, [base])
        self.assertFalse(os.path.lexists(base))

    def test_the_current_checkouts_release_output_base_is_kept_however_long_it_was_idle(self):
        name = hashlib.sha256(f"{self.workspace}:release".encode()).hexdigest()[:32]
        base = self.make_output_base(self.workspace, idle_days=30, name=name)

        actual = self.sweep()

        self.assertEqual(actual, [])
        self.assertTrue(os.path.isdir(base))

    def test_install_cache_and_other_entries_of_the_root_are_never_deleted(self):
        expected = ["cache", "install", "notes"]
        for name in expected:
            os.makedirs(os.path.join(self.root, name))
            old = self.now - 30 * DAY
            os.utime(os.path.join(self.root, name), (old, old))

        actual = self.sweep()

        self.assertEqual(actual, [])
        self.assertEqual(sorted(os.listdir(self.root)), expected)

    def test_the_server_of_a_stale_output_base_is_stopped_before_it_is_deleted(self):
        base = self.make_output_base(os.path.join(self.directory, "deleted-checkout"))
        # Like a Bazel server, the process's command line names its output base, and it is not this
        # test's child, so nothing here holds it as a zombie once it exits. The `; :` keeps the
        # shell from replacing itself with sleep, whose command line wouldn't name the base.
        launcher = subprocess.run(
            ["/bin/sh", "-c", '/bin/sh -c "sleep 300; :" "$0" >/dev/null 2>&1 & echo $!', f"--output_base={base}"],
            stdout=subprocess.PIPE, text=True, check=True,
        )
        server = int(launcher.stdout)
        with open(os.path.join(base, "server", "server.pid.txt"), "w") as file:
            file.write(str(server))
        os.utime(base, (self.now, self.now))
        start = time.monotonic()

        self.sweep()

        seconds = time.monotonic() - start
        # Gone, or a zombie (with an empty command line) where the container's init doesn't reap.
        self.assertNotIn(base, sweep_output_bases.command_line(server))
        # Well under the sweep's wait before SIGKILL: SIGTERM stopped it.
        self.assertLess(seconds, sweep_output_bases.SERVER_EXIT_SECONDS / 2)
        self.assertFalse(os.path.lexists(base))

    def test_a_process_whose_pid_a_stale_server_left_behind_is_not_stopped(self):
        base = self.make_output_base(os.path.join(self.directory, "deleted-checkout"))
        bystander = subprocess.Popen(["/bin/sh", "-c", "sleep 300"])
        with open(os.path.join(base, "server", "server.pid.txt"), "w") as file:
            file.write(str(bystander.pid))
        os.utime(base, (self.now, self.now))

        self.sweep()

        actual = bystander.poll()
        bystander.kill()
        bystander.wait()
        self.assertIsNone(actual)
        self.assertFalse(os.path.lexists(base))

    def test_an_output_base_whose_lock_a_running_command_holds_is_kept(self):
        import fcntl

        base = self.make_output_base(os.path.join(self.directory, "deleted-checkout"))
        lock = open(os.path.join(base, "lock"), "a")
        fcntl.flock(lock, fcntl.LOCK_EX)
        os.utime(base, (self.now, self.now))

        actual = self.sweep()

        lock.close()
        self.assertEqual(actual, [])
        self.assertTrue(os.path.isdir(base))


class WrapperTests(unittest.TestCase):
    """tools/bazel, run from a copy of tools/ whose sweep is a stand-in that is slow and fails."""

    def setUp(self):
        self.directory = os.path.realpath(tempfile.mkdtemp(dir=os.environ.get("TEST_TMPDIR")))
        self.home = os.path.join(self.directory, "home")
        self.root = os.path.join(self.home, "Library", "Caches", "bazel", "_bazel_user")
        os.makedirs(self.root)
        tools = os.path.join(self.directory, "workspace", "tools")
        os.makedirs(tools)
        self.wrapper = os.path.join(tools, "bazel")
        shutil.copy(WRAPPER, self.wrapper)
        self.started = os.path.join(self.directory, "sweeps-started")
        with open(os.path.join(tools, "sweep-output-bases"), "w") as file:
            file.write(f"import os, time\nopen({self.started!r}, 'a').write(str(os.getpid()) + '\\n')\ntime.sleep(30)\nraise SystemExit(1)\n")
        self.bazel = os.path.join(self.directory, "bazel-real")
        with open(self.bazel, "w") as file:
            file.write("#!/bin/sh\nexit 3\n")
        os.chmod(self.bazel, 0o755)

    def tearDown(self):
        for pid in self.sweeps_started():
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        shutil.rmtree(self.directory, ignore_errors=True)

    def sweeps_started(self, wait=False):
        deadline = time.monotonic() + (10 if wait else 0)
        while True:
            try:
                with open(self.started) as file:
                    pids = [int(line) for line in file if line.strip()]
            except FileNotFoundError:
                pids = []
            if pids or time.monotonic() >= deadline:
                return pids
            time.sleep(0.05)

    def run_wrapper(self):
        environment = {"HOME": self.home, "USER": "user", "PATH": os.environ.get("PATH", "/usr/bin:/bin"), "BAZEL_REAL": self.bazel}
        start = time.monotonic()
        completed = subprocess.run(["/bin/bash", self.wrapper, "version"], env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
        return completed.returncode, time.monotonic() - start

    @unittest.skipUnless(sys.platform == "darwin", "the sweep runs on macOS only")
    def test_a_slow_failing_sweep_neither_delays_the_command_nor_changes_its_exit_status(self):
        status, seconds = self.run_wrapper()

        self.assertEqual(status, 3)
        self.assertLess(seconds, 10)
        self.assertEqual(len(self.sweeps_started(wait=True)), 1)

    @unittest.skipUnless(sys.platform == "darwin", "the sweep runs on macOS only")
    def test_the_sweep_starts_at_most_once_a_day(self):
        self.run_wrapper()
        self.sweeps_started(wait=True)

        self.run_wrapper()
        time.sleep(1)

        self.assertEqual(len(self.sweeps_started()), 1)

    @unittest.skipUnless(sys.platform == "darwin", "the sweep runs on macOS only")
    def test_the_sweep_starts_again_once_its_stamp_is_a_day_old(self):
        self.run_wrapper()
        self.sweeps_started(wait=True)
        old = time.time() - DAY - 60
        os.utime(os.path.join(self.root, ".sweep-output-bases"), (old, old))

        self.run_wrapper()
        deadline = time.monotonic() + 10
        while len(self.sweeps_started()) < 2 and time.monotonic() < deadline:
            time.sleep(0.05)

        self.assertEqual(len(self.sweeps_started()), 2)

    @unittest.skipIf(sys.platform == "darwin", "on macOS the sweep runs")
    def test_on_linux_no_sweep_starts_and_the_command_runs_unchanged(self):
        status, _ = self.run_wrapper()
        time.sleep(1)

        self.assertEqual(status, 3)
        self.assertEqual(self.sweeps_started(), [])
        self.assertFalse(os.path.exists(os.path.join(self.root, ".sweep-output-bases")))


if __name__ == "__main__":
    unittest.main()
