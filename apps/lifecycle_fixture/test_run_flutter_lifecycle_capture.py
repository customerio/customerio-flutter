import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("run_flutter_lifecycle_capture.py")
SPEC = importlib.util.spec_from_file_location("run_flutter_lifecycle_capture", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


IDS = {
    "MANIFEST_ID": "12345678-1234-4123-8123-123456789abc",
    "RUN_ID": "22345678-1234-4123-8123-123456789abc",
    "STREAM_ID": "32345678-1234-4123-8123-123456789abc",
    "DART_STREAM_ID": "42345678-1234-4123-8123-123456789abc",
    "PROCESS_INSTANCE_ID": "52345678-1234-4123-8123-123456789abc",
    "ACTIVATION_OCCURRENCE_ID": "62345678-1234-4123-8123-123456789abc",
}


def _record(runtime: str, stream_id: str, process_id: int = 42) -> dict:
    return {
        "manifest_id": IDS["MANIFEST_ID"],
        "run_id": IDS["RUN_ID"],
        "stream_id": stream_id,
        "scenario": "icon-cold-launch",
        "evidence_level": "L2",
        "integration": "flutter",
        "runtime": runtime,
        "provider": "none",
        "process_id": process_id,
        "sequence": 1,
        "kind": "app-received",
        "correlation": {"occurrence": "occurrence-1"},
    }


def _write_trace(path: Path, record: dict, *, drops: int = 0) -> None:
    path.write_text(MODULE.TRACE_PREFIX + json.dumps(record) + "\n", encoding="utf-8")
    Path(str(path) + ".receipt.json").write_text(
        json.dumps(
            {
                "last_assigned_sequence": 1,
                "last_emitted_sequence": 1,
                "emitted_records": 1,
                "dropped_records_total": drops,
                "alias_overflow": False,
            }
        ),
        encoding="utf-8",
    )


class FlutterLifecycleCaptureTests(unittest.TestCase):
    @staticmethod
    def _completed(arguments, returncode=0, stdout=""):
        return MODULE.subprocess.CompletedProcess(arguments, returncode, stdout, "")

    def testSimulatorProcessIds_parsesExactUIKitApplicationLabel(self):
        listing = """PID Status Label
8502 0 UIKitApplication:io.customer.testbed.flutter.spm[abc][rb-legacy]
9001 0 UIKitApplication:io.customer.testbed.flutter.spm.other[abc][rb-legacy]
- 0 com.apple.SpringBoard
"""
        with patch.object(MODULE, "_run", return_value=listing):
            self.assertEqual(
                MODULE._simulator_process_ids(
                    Path("."), "SIMULATOR", "io.customer.testbed.flutter.spm"
                ),
                [8502],
            )

    def testStimulusConfiguration_simctlCannotClaimAppIconEvidence(self):
        self.assertEqual(
            MODULE._stimulus_configuration("simctl-diagnostic"),
            ("diagnostic", "simulator-control"),
        )
        self.assertEqual(
            MODULE._stimulus_configuration("manual-app-icon"),
            ("L2", "app-icon"),
        )

    def testHostTopology_isExplicitForEachSupportedMode(self):
        self.assertEqual(MODULE._host_topology("legacy"), "app-delegate-only")
        self.assertEqual(MODULE._host_topology("scene"), "ui-scene")
        with self.assertRaisesRegex(MODULE.CaptureError, "unsupported lifecycle mode"):
            MODULE._host_topology("inferred")

    def testSwiftRuntimeEnvironment_bindsTopologyAndOccurrenceIdentity(self):
        environment = MODULE._swift_runtime_environment(
            IDS, "scene", Path("/tmp/swift.ndjson"), "L2"
        )

        self.assertEqual(environment["CIO_LIFECYCLE_HOST_TOPOLOGY"], "ui-scene")
        self.assertEqual(
            environment["CIO_LIFECYCLE_ACTIVATION_OCCURRENCE_ID"],
            IDS["ACTIVATION_OCCURRENCE_ID"],
        )
        self.assertEqual(environment["CIO_LIFECYCLE_EVIDENCE_LEVEL"], "L2")
        self.assertEqual(
            environment["CIO_LIFECYCLE_OUTPUT_PATH"], "/tmp/swift.ndjson"
        )

    def testManualAppIconMode_neverInvokesSimctlLaunch(self):
        with patch.object(MODULE, "_set_simulator_environment", return_value=["KEY"]), patch.object(
            MODULE, "_simulator_process_ids", return_value=[]
        ), patch.object(MODULE, "_run") as run, patch.object(
            MODULE.sys, "stdin", io.StringIO("\n")
        ):
            process_id, keys, initiated_at = MODULE._initiate_stimulus(
                "manual-app-icon",
                Path("."),
                "SIMULATOR",
                "example.bundle",
                {"KEY": "value"},
            )

        self.assertIsNone(process_id)
        self.assertEqual(keys, ["KEY"])
        self.assertTrue(initiated_at.endswith("Z"))
        run.assert_not_called()

    def testManualAppIconMode_timestampsOnlyAfterOperatorConfirmation(self):
        class ConfirmingInput:
            def readline(inner_self):
                self.assertEqual(timestamp.call_count, 0)
                return "\n"

        with patch.object(
            MODULE, "_set_simulator_environment", return_value=["KEY"]
        ), patch.object(
            MODULE, "_simulator_process_ids", return_value=[]
        ), patch.object(
            MODULE.sys, "stdin", ConfirmingInput()
        ), patch.object(
            MODULE, "_timestamp", return_value="2026-08-12T12:00:00.000Z"
        ) as timestamp:
            _, _, initiated_at = MODULE._initiate_stimulus(
                "manual-app-icon",
                Path("."),
                "SIMULATOR",
                "example.bundle",
                {"KEY": "value"},
            )

        timestamp.assert_called_once_with()
        self.assertEqual(initiated_at, "2026-08-12T12:00:00.000Z")

    def testManualAppIconMode_missingConfirmationFailsAndCleansEnvironment(self):
        with patch.object(
            MODULE, "_set_simulator_environment", return_value=["KEY"]
        ), patch.object(
            MODULE, "_simulator_process_ids", return_value=[]
        ), patch.object(
            MODULE.sys, "stdin", io.StringIO("")
        ), patch.object(MODULE, "_clear_simulator_environment") as clear:
            with self.assertRaisesRegex(MODULE.CaptureError, "not confirmed"):
                MODULE._initiate_stimulus(
                    "manual-app-icon",
                    Path("."),
                    "SIMULATOR",
                    "example.bundle",
                    {"KEY": "value"},
                )

        clear.assert_called_once_with(Path("."), "SIMULATOR", ["KEY"])

    def testDiagnosticMode_invokesSimctlLaunchAndReturnsItsPid(self):
        with patch.object(
            MODULE, "_run", return_value="example.bundle: 42"
        ) as run:
            process_id, keys, initiated_at = MODULE._initiate_stimulus(
                "simctl-diagnostic",
                Path("."),
                "SIMULATOR",
                "example.bundle",
                {"KEY": "value"},
            )

        self.assertEqual(process_id, 42)
        self.assertEqual(keys, [])
        self.assertTrue(initiated_at.endswith("Z"))
        self.assertIn("launch", run.call_args.args[0])

    def testManualAppIconMode_alreadyRunningFailsClosedAndCleansEnvironment(self):
        with patch.object(MODULE, "_set_simulator_environment", return_value=["KEY"]), patch.object(
            MODULE, "_simulator_process_ids", return_value=[42]
        ), patch.object(MODULE, "_clear_simulator_environment") as clear:
            with self.assertRaisesRegex(MODULE.CaptureError, "already running"):
                MODULE._initiate_stimulus(
                    "manual-app-icon",
                    Path("."),
                    "SIMULATOR",
                    "example.bundle",
                    {"KEY": "value"},
                )
        clear.assert_called_once_with(Path("."), "SIMULATOR", ["KEY"])

    def testManualAppIconMode_processQueryFailureCleansEnvironment(self):
        with patch.object(MODULE, "_set_simulator_environment", return_value=["KEY"]), patch.object(
            MODULE, "_simulator_process_ids", side_effect=MODULE.CaptureError("query failed")
        ), patch.object(MODULE, "_clear_simulator_environment") as clear:
            with self.assertRaisesRegex(MODULE.CaptureError, "query failed"):
                MODULE._initiate_stimulus(
                    "manual-app-icon",
                    Path("."),
                    "SIMULATOR",
                    "example.bundle",
                    {"KEY": "value"},
                )
        clear.assert_called_once_with(Path("."), "SIMULATOR", ["KEY"])

    def testManualAppIconMode_waitTimeoutCleansEnvironment(self):
        with patch.object(
            MODULE,
            "_initiate_stimulus",
            return_value=(None, ["KEY"], MODULE._timestamp()),
        ), patch.object(
            MODULE, "_wait_for_files", side_effect=MODULE.CaptureError("timed out")
        ), patch.object(MODULE, "_clear_simulator_environment") as clear:
            with self.assertRaisesRegex(MODULE.CaptureError, "timed out"):
                MODULE._await_stimulus_capture(
                    "manual-app-icon",
                    Path("/repo"),
                    "SIMULATOR",
                    "example.bundle",
                    {"KEY": "value"},
                    [Path("swift")],
                    0.01,
                )
        clear.assert_called_once_with(Path("/repo"), "SIMULATOR", ["KEY"])

    def testClearSimulatorEnvironment_unsetsAndVerifiesEmpty(self):
        completed = [
            self._completed(["unsetenv"]),
            self._completed(["getenv"]),
        ]
        with patch.object(MODULE.subprocess, "run", side_effect=completed) as run:
            MODULE._clear_simulator_environment(Path("/repo"), "SIMULATOR", ["KEY"])

        self.assertEqual(run.call_count, 2)
        self.assertIn("unsetenv", run.call_args_list[0].args[0])
        self.assertIn("getenv", run.call_args_list[1].args[0])

    def testClearSimulatorEnvironment_unsetFailureFailsClosed(self):
        completed = [
            self._completed(["unsetenv"], returncode=1),
            self._completed(["getenv"]),
        ]
        with patch.object(MODULE.subprocess, "run", side_effect=completed):
            with self.assertRaisesRegex(MODULE.CaptureError, "KEY unsetenv exited 1"):
                MODULE._clear_simulator_environment(Path("/repo"), "SIMULATOR", ["KEY"])

    def testClearSimulatorEnvironment_valueStillSetFailsClosed(self):
        completed = [
            self._completed(["unsetenv"]),
            self._completed(["getenv"], stdout="stale-value\n"),
        ]
        with patch.object(MODULE.subprocess, "run", side_effect=completed):
            with self.assertRaisesRegex(MODULE.CaptureError, "KEY remained set"):
                MODULE._clear_simulator_environment(Path("/repo"), "SIMULATOR", ["KEY"])

    def testClearSimulatorEnvironment_partialFailureStillAttemptsEveryKey(self):
        completed = [
            self._completed(["unsetenv"], returncode=1),
            self._completed(["getenv"], stdout="stale\n"),
            self._completed(["unsetenv"]),
            self._completed(["getenv"]),
        ]
        with patch.object(MODULE.subprocess, "run", side_effect=completed) as run:
            with self.assertRaisesRegex(MODULE.CaptureError, "cleanup failed"):
                MODULE._clear_simulator_environment(
                    Path("/repo"), "SIMULATOR", ["FIRST", "SECOND"]
                )

        self.assertEqual(run.call_count, 4)
        self.assertIn("SECOND", run.call_args_list[0].args[0])
        self.assertIn("FIRST", run.call_args_list[2].args[0])

    def testWaitTimeout_preservesPrimaryErrorWhenCleanupAlsoFails(self):
        with patch.object(
            MODULE,
            "_initiate_stimulus",
            return_value=(None, ["KEY"], MODULE._timestamp()),
        ), patch.object(
            MODULE, "_wait_for_files", side_effect=MODULE.CaptureError("timed out")
        ), patch.object(
            MODULE,
            "_clear_simulator_environment",
            side_effect=MODULE.CaptureError("cleanup failed"),
        ):
            with self.assertRaisesRegex(
                MODULE.CaptureError, "timed out; additionally, cleanup failed"
            ):
                MODULE._await_stimulus_capture(
                    "manual-app-icon",
                    Path("/repo"),
                    "SIMULATOR",
                    "example.bundle",
                    {"KEY": "value"},
                    [Path("swift")],
                    0.01,
                )

    def testManualCapture_ignoresManagedSignalsDuringCleanupAndRestoresHandlers(self):
        previous_hup = signal.getsignal(signal.SIGHUP)
        previous_term = signal.getsignal(signal.SIGTERM)
        cleared = []

        def cleanup(root, simulator_id, keys):
            os.kill(os.getpid(), signal.SIGTERM)
            cleared.extend(keys)

        with patch.object(
            MODULE,
            "_initiate_stimulus",
            return_value=(None, ["FIRST", "SECOND"], MODULE._timestamp()),
        ), patch.object(MODULE, "_wait_for_files"), patch.object(
            MODULE, "_clear_simulator_environment", side_effect=cleanup
        ):
            MODULE._await_stimulus_capture(
                "manual-app-icon",
                Path("/repo"),
                "SIMULATOR",
                "example.bundle",
                {"KEY": "value"},
                [Path("swift")],
                0.01,
            )

        self.assertEqual(cleared, ["FIRST", "SECOND"])
        self.assertIs(signal.getsignal(signal.SIGHUP), previous_hup)
        self.assertIs(signal.getsignal(signal.SIGTERM), previous_term)

    def testManualCapture_termDuringWaitRunsCleanupAndRestoresHandler(self):
        with tempfile.TemporaryDirectory() as directory:
            cleanup = Path(directory) / "cleanup"
            script = f"""
import importlib.util
from pathlib import Path
import signal
import time

spec = importlib.util.spec_from_file_location('capture', {str(SCRIPT)!r})
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
cleanup = Path({str(cleanup)!r})
module._initiate_stimulus = lambda *args: (None, ['FIRST', 'SECOND'], module._timestamp())
def wait(*args):
    print('WAITING', flush=True)
    time.sleep(30)
module._wait_for_files = wait
module._clear_simulator_environment = lambda root, simulator, keys: cleanup.write_text(','.join(keys))
try:
    module._await_stimulus_capture('manual-app-icon', Path('.'), 'SIMULATOR', 'bundle', {{}}, [Path('trace')], 30)
except module.CaptureError as error:
    print(error)
print('RESTORED=' + str(signal.getsignal(signal.SIGTERM) is signal.SIG_DFL), flush=True)
"""
            process = subprocess.Popen(
                [sys.executable, "-c", script],
                cwd=SCRIPT.parent,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            assert process.stdout is not None
            self.assertEqual(process.stdout.readline().strip(), "WAITING")
            process.send_signal(signal.SIGTERM)
            output, _ = process.communicate(timeout=5)

            self.assertEqual(process.returncode, 0, output)
            self.assertEqual(cleanup.read_text(), "FIRST,SECOND")
            self.assertIn("interrupted by SIGTERM", output)
            self.assertIn("RESTORED=True", output)

    def testContentSnapshot_directorySymlink_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target"
            target.mkdir()
            (target / "file.txt").write_text("inside\n", encoding="utf-8")
            os.symlink("target", root / "linked")

            with self.assertRaisesRegex(
                MODULE.CaptureError, "resolved Customer.io dependency contains unsafe input"
            ):
                MODULE._content_snapshot(root)

    def testContentSnapshot_unusedOverride_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "file.txt").write_text("value\n", encoding="utf-8")
            with self.assertRaisesRegex(MODULE.CaptureError, "did not match"):
                MODULE._content_snapshot(root, {"missing.txt": "a" * 64})

    def testCocoaDependencyProvenance_rejectsPostReceiptTreeMutation(self):
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory) / "repo"
            derived_data = Path(directory) / "derived"
            dependency = (
                source_root
                / "apps/flutter_sample_cocoapods/ios/Pods/CustomerIOMessagingPushFCM"
            )
            source = dependency / "Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
            source.parent.mkdir(parents=True)
            source.write_bytes(
                (SCRIPT.parent / "testdata/CioAppDelegateFCM-4.7.2.swift").read_bytes()
            )
            other = dependency / "Sources/Other.swift"
            other.write_text("original\n", encoding="utf-8")
            lock = source_root / "apps/flutter_sample_cocoapods/ios/Podfile.lock"
            lock.write_text("CustomerIOMessagingPushFCM (4.7.2)\n", encoding="utf-8")
            relative = source.relative_to(dependency).as_posix()
            snapshot = MODULE._content_snapshot(
                dependency,
                {relative: "b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176"},
            )
            derived_data.mkdir()
            (derived_data / "cio-lifecycle-dependency-instrumentation.json").write_text(
                json.dumps({
                    "original_sha256": "f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8",
                    "patch_sha256": "f213e7a51dc2eb59c9dbb21d33e32d42d967530933597b1abb06fcdbc2010195",
                    "patched_sha256": "b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176",
                    "patched_tree_sha256": snapshot["tree_hash"],
                    "restored_sha256": "f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8",
                }),
                encoding="utf-8",
            )

            MODULE._dependency_provenance(source_root, derived_data, "cocoapods")
            other.write_text("mutated\n", encoding="utf-8")
            with self.assertRaisesRegex(MODULE.CaptureError, "changed after"):
                MODULE._dependency_provenance(source_root, derived_data, "cocoapods")

    def testPartialReceipt_waitsAndFailsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / "receipt.json"
            receipt.write_text('{"emitted_records":\n', encoding="utf-8")
            with self.assertRaisesRegex(MODULE.CaptureError, "complete files"):
                MODULE._wait_for_files([receipt], 0.01)

            receipt.write_text('{"emitted_records": 1}\n', encoding="utf-8")
            MODULE._wait_for_files([receipt], 0.2)

    def testSourceMutation_failsClosed(self):
        with self.assertRaisesRegex(MODULE.CaptureError, "changed during capture"):
            MODULE._require_stable_source(
                "a" * 40,
                True,
                {"tree_hash": "1" * 64},
                "a" * 40,
                True,
                {"tree_hash": "2" * 64},
            )

    def testSnapshot_bindsUntrackedContentAndSafeInternalSymlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE._run(["git", "init", "-q"], cwd=root)
            target = root / "target.txt"
            link = root / "link.txt"
            target.write_text("tracked\n", encoding="utf-8")
            os.symlink("target.txt", link)
            MODULE._run(["git", "add", "target.txt", "link.txt"], cwd=root)
            MODULE._run(
                [
                    "git",
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "commit",
                    "-qm",
                    "fixture",
                ],
                cwd=root,
            )
            untracked = root / "untracked.txt"
            untracked.write_text("first\n", encoding="utf-8")

            dirty, first = MODULE._snapshot(root)
            untracked.write_text("second\n", encoding="utf-8")
            _, second = MODULE._snapshot(root)

            self.assertTrue(dirty)
            self.assertIsNotNone(first)
            self.assertIsNotNone(second)
            assert first is not None and second is not None
            self.assertNotEqual(first["tree_hash"], second["tree_hash"])
            self.assertNotEqual(first["diff_hash"], second["diff_hash"])

    def testSnapshot_bindsTrackedSymlinkTargetText(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE._run(["git", "init", "-q"], cwd=root)
            target = root / "target.txt"
            link = root / "link.txt"
            target.write_text("tracked\n", encoding="utf-8")
            os.symlink("target.txt", link)
            MODULE._run(["git", "add", "target.txt", "link.txt"], cwd=root)
            MODULE._run(
                [
                    "git",
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "commit",
                    "-qm",
                    "fixture",
                ],
                cwd=root,
            )
            (root / "untracked.txt").write_text("unchanged\n", encoding="utf-8")

            _, first = MODULE._snapshot(root)
            link.unlink()
            os.symlink("./target.txt", link)
            _, second = MODULE._snapshot(root)

            self.assertIsNotNone(first)
            self.assertIsNotNone(second)
            assert first is not None and second is not None
            self.assertNotEqual(first["tree_hash"], second["tree_hash"])
            self.assertNotEqual(first["diff_hash"], second["diff_hash"])

    def testSnapshot_acceptsTrackedInternalDirectorySymlinkWithoutWalkingIt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE._run(["git", "init", "-q"], cwd=root)
            target = root / "shared"
            target.mkdir()
            (target / "tracked.txt").write_text("tracked\n", encoding="utf-8")
            os.symlink("shared", root / "linked")
            MODULE._run(["git", "add", "shared/tracked.txt", "linked"], cwd=root)
            MODULE._run(
                [
                    "git",
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "commit",
                    "-qm",
                    "fixture",
                ],
                cwd=root,
            )
            (root / "dirty.txt").write_text("dirty\n", encoding="utf-8")

            dirty, snapshot = MODULE._snapshot(root)

            self.assertTrue(dirty)
            self.assertIsNotNone(snapshot)

    def testSnapshot_untrackedInternalSymlink_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE._run(["git", "init", "-q"], cwd=root)
            (root / "target.txt").write_text("inside\n", encoding="utf-8")
            os.symlink("target.txt", root / "link.txt")
            with self.assertRaisesRegex(
                MODULE.CaptureError, "unsafe untracked source snapshot symlink"
            ):
                MODULE._snapshot(root)

    def testSnapshot_trackedExternalSymlink_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            root = Path(directory)
            MODULE._run(["git", "init", "-q"], cwd=root)
            target = Path(outside) / "target.txt"
            target.write_text("outside\n", encoding="utf-8")
            os.symlink(target, root / "link.txt")
            MODULE._run(["git", "add", "link.txt"], cwd=root)
            with self.assertRaisesRegex(MODULE.CaptureError, "unsafe source snapshot symlink"):
                MODULE._snapshot(root)

    def testMissingDartFile_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            with self.assertRaisesRegex(MODULE.CaptureError, "missing trace"):
                MODULE._bind_streams(swift, root / "dart.ndjson", IDS, 42)

    def testMissingDartReceipt_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            dart.write_text(
                MODULE.TRACE_PREFIX
                + json.dumps(_record("dart", IDS["DART_STREAM_ID"]))
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(MODULE.CaptureError, "post-drain receipt"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testStaleCompiledDartIds_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            stale = _record("dart", IDS["DART_STREAM_ID"])
            stale["run_id"] = "62345678-1234-4123-8123-123456789abc"
            _write_trace(dart, stale)
            with self.assertRaisesRegex(MODULE.CaptureError, "mismatched run_id"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testStreamMismatch_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            _write_trace(dart, _record("dart", IDS["STREAM_ID"]))
            with self.assertRaisesRegex(MODULE.CaptureError, "mismatched stream_id"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testDrops_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            _write_trace(dart, _record("dart", IDS["DART_STREAM_ID"]), drops=1)
            with self.assertRaisesRegex(MODULE.CaptureError, "drops or overflow"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testProcessMismatch_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            _write_trace(swift, _record("swift", IDS["STREAM_ID"]))
            _write_trace(dart, _record("dart", IDS["DART_STREAM_ID"], 43))
            with self.assertRaisesRegex(MODULE.CaptureError, "launched process_id"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testMissingOccurrence_failsClosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            swift = root / "swift.ndjson"
            dart = root / "dart.ndjson"
            missing = _record("swift", IDS["STREAM_ID"])
            missing["correlation"] = None
            _write_trace(swift, missing)
            _write_trace(dart, _record("dart", IDS["DART_STREAM_ID"]))
            with self.assertRaisesRegex(MODULE.CaptureError, "occurrence-1"):
                MODULE._bind_streams(swift, dart, IDS, 42)

    def testValidatorRejection_failsClosed(self):
        with patch.object(
            MODULE, "_run", side_effect=MODULE.CaptureError("validator rejected")
        ):
            with self.assertRaisesRegex(MODULE.CaptureError, "validator rejected"):
                MODULE._validate_capture(
                    "python",
                    Path("validator.py"),
                    Path("manifest.json"),
                    [Path("swift.ndjson"), Path("dart.ndjson")],
                    Path("."),
                )


if __name__ == "__main__":
    unittest.main()
