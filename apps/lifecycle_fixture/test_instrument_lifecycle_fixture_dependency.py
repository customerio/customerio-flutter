#!/usr/bin/env python3

import pathlib
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest

from apps.lifecycle_fixture.dependency_content_snapshot import content_snapshot


APPS_ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = APPS_ROOT / "scripts" / "instrument_lifecycle_fixture_dependency.sh"
ORIGINAL = pathlib.Path(__file__).parent / "testdata" / "CioAppDelegateFCM-4.7.2.swift"
SPM_SUFFIX = pathlib.Path(
    "SourcePackages/checkouts/customerio-ios/Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
)
PODS_SUFFIX = pathlib.Path(
    "ios/Pods/CustomerIOMessagingPushFCM/Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
)


class InstrumentLifecycleFixtureDependencyTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def install_original(self, root: pathlib.Path, suffix: pathlib.Path) -> pathlib.Path:
        destination = root / suffix
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ORIGINAL, destination)
        return destination

    def run_patch(self, resolution: str, root: pathlib.Path, command=None, extra_environment=None):
        arguments = [str(SCRIPT), resolution, str(root.resolve())]
        environment = None
        if command is not None:
            arguments.extend(["--", *command])
            environment = os.environ.copy()
            environment["CIO_LIFECYCLE_INSTRUMENTATION_RECEIPT"] = str(
                self.root / "instrumentation.json"
            )
            environment.update(extra_environment or {})
        return subprocess.run(
            arguments,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_spm_original_and_idempotent_patched_state_succeed(self):
        self.install_original(self.root, SPM_SUFFIX)
        first = self.run_patch("spm", self.root)
        second = self.run_patch("spm", self.root)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)

    def test_cocoapods_success_restores_exact_original_and_writes_receipt(self):
        source = self.install_original(self.root, PODS_SUFFIX)
        original = source.read_bytes()
        result = self.run_patch("cocoapods", self.root, ["/usr/bin/true"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(source.read_bytes(), original)
        receipt = json.loads((self.root / "instrumentation.json").read_text())
        self.assertEqual(receipt["restored_sha256"], hashlib.sha256(original).hexdigest())
        self.assertRegex(receipt["patched_tree_sha256"], r"^[0-9a-f]{64}$")
        dependency = self.root / "ios/Pods/CustomerIOMessagingPushFCM"
        relative = source.relative_to(dependency).as_posix()
        reconstructed = content_snapshot(
            dependency,
            {relative: receipt["patched_sha256"]},
        )
        self.assertEqual(receipt["patched_tree_sha256"], reconstructed["tree_hash"])
        self.assertEqual(
            list((self.root / "ios/Pods").glob(".CioAppDelegateFCM.original.*")),
            [],
        )

    def test_cocoapods_failure_restores_exact_original_without_receipt(self):
        source = self.install_original(self.root, PODS_SUFFIX)
        original = source.read_bytes()
        result = self.run_patch("cocoapods", self.root, ["/usr/bin/false"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(source.read_bytes(), original)
        self.assertFalse((self.root / "instrumentation.json").exists())

    def test_cocoapods_backup_setup_failure_deletesCandidateWithoutTouchingSource(self):
        source = self.install_original(self.root, PODS_SUFFIX)
        original = source.read_bytes()
        result = self.run_patch(
            "cocoapods",
            self.root,
            ["/usr/bin/true"],
            {"CIO_LIFECYCLE_INSTRUMENTATION_TEST_FAIL_BACKUP_SETUP": "1"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("forced CocoaPods source backup setup failure", result.stderr)
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual(
            list((self.root / "ios/Pods").glob(".CioAppDelegateFCM.original.*")),
            [],
        )
        self.assertFalse((self.root / "instrumentation.json").exists())

    def test_cocoapods_prepatched_source_is_refused(self):
        source = self.install_original(self.root, PODS_SUFFIX)
        spm_source = self.install_original(self.root, SPM_SUFFIX)
        spm = self.run_patch("spm", self.root)
        self.assertEqual(spm.returncode, 0, spm.stderr)
        shutil.copyfile(spm_source, source)
        result = self.run_patch("cocoapods", self.root, ["/usr/bin/true"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing prepatched CocoaPods", result.stderr)

    def test_wrong_hash_fails_closed(self):
        source = self.install_original(self.root, SPM_SUFFIX)
        source.write_bytes(source.read_bytes() + b" ")
        result = self.run_patch("spm", self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected Customer.io source hash", result.stderr)

    def test_wrong_path_fails_closed(self):
        wrong = SPM_SUFFIX.parent.parent / "Other" / SPM_SUFFIX.name
        self.install_original(self.root, wrong)
        result = self.run_patch("spm", self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing pinned Customer.io source", result.stderr)

    def test_symlink_source_fails_closed(self):
        target = self.install_original(self.root, pathlib.Path("original.swift"))
        source = self.root / SPM_SUFFIX
        source.parent.mkdir(parents=True)
        source.symlink_to(target)
        result = self.run_patch("spm", self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing pinned Customer.io source", result.stderr)


if __name__ == "__main__":
    unittest.main()
