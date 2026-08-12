import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "apps/scripts/lifecycle_fixture_build.sh"


class LifecycleFixtureBuildLockTests(unittest.TestCase):
    def _environment(self, directory: Path, hold_seconds: int) -> dict[str, str]:
        app = directory / "sample"
        app.mkdir()
        (app / ".flutter-version").write_text("3.44.8\n", encoding="utf-8")
        flutter = directory / "flutter"
        flutter.write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' '{\"frameworkVersion\":\"3.44.8\"}'\n",
            encoding="utf-8",
        )
        flutter.chmod(0o755)
        environment = os.environ.copy()
        environment.update({
            "FLUTTER": str(flutter),
            "CIO_LIFECYCLE_BUILD_LOCK_TEST_APP_DIR": str(app),
            "CIO_LIFECYCLE_LOCK_TEST_HOLD_SECONDS": str(hold_seconds),
        })
        return environment

    def _wait_for_lock(self, lock: Path, owner: subprocess.Popen[str]) -> None:
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if lock.is_dir():
                return
            if owner.poll() is not None:
                output, _ = owner.communicate(timeout=1)
                self.fail(
                    f"fixture build exited {owner.returncode} before acquiring lock:\n{output}"
                )
            time.sleep(0.01)
        owner.kill()
        output, _ = owner.communicate(timeout=5)
        self.fail(f"fixture build did not acquire its test lock:\n{output}")

    @staticmethod
    def _stop_process(process: subprocess.Popen[str]) -> None:
        if process.poll() is None:
            process.kill()
        process.communicate(timeout=5)

    def testConcurrentBuildIsRejectedAndOwnerCleansOnSuccess(self):
        with tempfile.TemporaryDirectory() as value:
            directory = Path(value)
            environment = self._environment(directory, 2)
            lock = directory / "sample/build/lifecycle-fixture-locks/build.lock"
            owner = subprocess.Popen(
                [str(SCRIPT), "legacy", "spm", str(directory / "derived-owner")],
                cwd=ROOT,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            self.addCleanup(self._stop_process, owner)
            self._wait_for_lock(lock, owner)

            contender = subprocess.run(
                [str(SCRIPT), "scene", "spm", str(directory / "derived-contender")],
                cwd=ROOT,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )
            self.assertNotEqual(contender.returncode, 0)
            self.assertIn("another spm lifecycle build owns", contender.stdout)
            self.assertEqual(owner.wait(timeout=5), 0)
            owner.communicate(timeout=1)
            self.assertFalse(lock.exists())

    def testSignalReleasesOwnedLock(self):
        with tempfile.TemporaryDirectory() as value:
            directory = Path(value)
            environment = self._environment(directory, 30)
            lock = directory / "sample/build/lifecycle-fixture-locks/build.lock"
            owner = subprocess.Popen(
                [str(SCRIPT), "legacy", "cocoapods", str(directory / "derived")],
                cwd=ROOT,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                start_new_session=True,
            )
            self.addCleanup(self._stop_process, owner)
            self._wait_for_lock(lock, owner)
            os.killpg(owner.pid, signal.SIGTERM)
            returncode = owner.wait(timeout=5)
            owner.communicate(timeout=1)
            self.assertFalse(lock.exists())
            self.assertIn(returncode, (143, -signal.SIGTERM))

    def testMetadataWriteFailureReleasesOwnedLock(self):
        with tempfile.TemporaryDirectory() as value:
            directory = Path(value)
            environment = self._environment(directory, 1)
            environment["CIO_LIFECYCLE_LOCK_TEST_FAIL_METADATA_WRITE"] = "1"
            lock = directory / "sample/build/lifecycle-fixture-locks/build.lock"

            result = subprocess.run(
                [str(SCRIPT), "legacy", "spm", str(directory / "derived")],
                cwd=ROOT,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("forced lifecycle fixture lock metadata failure", result.stdout)
            self.assertFalse(lock.exists())

    def testSymlinkedBuildDirectoryIsRejectedWithoutTouchingTarget(self):
        with tempfile.TemporaryDirectory() as value:
            directory = Path(value)
            environment = self._environment(directory, 1)
            outside = directory / "outside"
            outside.mkdir()
            (directory / "sample/build").symlink_to(outside, target_is_directory=True)

            result = subprocess.run(
                [str(SCRIPT), "legacy", "spm", str(directory / "derived")],
                cwd=ROOT,
                env=environment,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("build directory is a symlink", result.stdout)
            self.assertEqual(list(outside.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
