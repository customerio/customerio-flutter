#!/usr/bin/env python3

import pathlib
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SPM_SOURCE = REPO_ROOT / (
    "apps/flutter_sample_spm/ios/Runner/LifecycleTraceRawLaunchMarker.swift"
)
COCOAPODS_SOURCE = REPO_ROOT / (
    "apps/flutter_sample_cocoapods/ios/Runner/LifecycleTraceRawLaunchMarker.swift"
)


class RawLaunchMarkerTests(unittest.TestCase):
    def test_samples_use_byte_identical_decoder(self):
        self.assertEqual(SPM_SOURCE.read_bytes(), COCOAPODS_SOURCE.read_bytes())

    def test_decoder_rejects_spoofed_object_process_and_payload(self):
        harness = textwrap.dedent(
            r"""
            import Foundation

            @main
            struct RawLaunchMarkerHarness {
                static func main() {
                    let center = NotificationCenter()
                    let expectedProcess = "12345678-1234-4123-8123-123456789abc"
                    let validInfo: [AnyHashable: Any] = [
                        "process_instance_id": expectedProcess,
                        "app_state": "inactive",
                        "has_launch_options": false,
                        "launch_option_keys": 0
                    ]
                    let valid = Notification(
                        name: LifecycleTraceRawLaunchMarker.notificationName,
                        object: center,
                        userInfo: validInfo
                    )
                    let facts = LifecycleTraceRawLaunchMarker.decode(
                        valid,
                        center: center,
                        expectedProcessInstanceID: expectedProcess
                    )
                    precondition(facts?.appState == "inactive")
                    precondition(facts?.hasLaunchOptions == false)
                    precondition(facts?.launchOptionKeys == 0)

                    let spoofedObject = Notification(
                        name: LifecycleTraceRawLaunchMarker.notificationName,
                        object: NotificationCenter(),
                        userInfo: validInfo
                    )
                    precondition(
                        LifecycleTraceRawLaunchMarker.decode(
                            spoofedObject,
                            center: center,
                            expectedProcessInstanceID: expectedProcess
                        ) == nil
                    )

                    var wrongProcess = validInfo
                    wrongProcess["process_instance_id"] =
                        "22345678-1234-4123-8123-123456789abc"
                    precondition(
                        LifecycleTraceRawLaunchMarker.decode(
                            Notification(
                                name: LifecycleTraceRawLaunchMarker.notificationName,
                                object: center,
                                userInfo: wrongProcess
                            ),
                            center: center,
                            expectedProcessInstanceID: expectedProcess
                        ) == nil
                    )

                    var malformed = validInfo
                    malformed["launch_option_keys"] = "0"
                    precondition(
                        LifecycleTraceRawLaunchMarker.decode(
                            Notification(
                                name: LifecycleTraceRawLaunchMarker.notificationName,
                                object: center,
                                userInfo: malformed
                            ),
                            center: center,
                            expectedProcessInstanceID: expectedProcess
                        ) == nil
                    )
                }
            }
            """
        )
        with tempfile.TemporaryDirectory() as directory:
            temporary = pathlib.Path(directory)
            harness_path = temporary / "Harness.swift"
            executable = temporary / "raw-launch-marker-test"
            harness_path.write_text(harness, encoding="utf-8")
            compile_result = subprocess.run(
                [
                    "xcrun",
                    "swiftc",
                    str(SPM_SOURCE),
                    str(harness_path),
                    "-o",
                    str(executable),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
            run_result = subprocess.run(
                [str(executable)], text=True, capture_output=True, check=False
            )
            self.assertEqual(run_result.returncode, 0, run_result.stderr)


if __name__ == "__main__":
    unittest.main()
