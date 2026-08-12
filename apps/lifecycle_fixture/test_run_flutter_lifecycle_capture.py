import importlib.util
import json
import os
from pathlib import Path
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
