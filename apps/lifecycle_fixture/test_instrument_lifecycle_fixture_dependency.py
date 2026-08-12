#!/usr/bin/env python3

import pathlib
import shutil
import subprocess
import tempfile
import unittest


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

    def run_patch(self, resolution: str, root: pathlib.Path):
        return subprocess.run(
            [str(SCRIPT), resolution, str(root.resolve())],
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

    def test_cocoapods_exact_path_succeeds(self):
        self.install_original(self.root, PODS_SUFFIX)
        result = self.run_patch("cocoapods", self.root)
        self.assertEqual(result.returncode, 0, result.stderr)

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
