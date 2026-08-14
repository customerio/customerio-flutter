# iOS toolchain compatibility CI

`Xcode 27 preview compatibility` compiles the CocoaPods and SwiftPM sample apps on the floating Xcode 27 preview runner. Both paths install the exact Flutter version in each app's `.flutter-version` file, and the repository verifier requires the two pins to remain synchronized and compatible with Xcode 27. It runs nightly at 06:17 UTC, on manual dispatch, and when its own workflow definition changes. Ordinary source pull requests and pushes do not trigger it; a pull request changing the workflow intentionally opts into the preview jobs.

The regular sample-app, API, lint, and test workflows remain the required stable-Xcode regression coverage. Repeating the stable sample builds here would consume scarce hosted macOS capacity without adding a distinct release gate. A nightly run instead detects preview-image changes and incompatibilities on `main`. A pull request specifically changing Flutter's iOS toolchain integration can be validated before merge with a manual dispatch or an explicitly test-only workflow change.

The regular Ubuntu lint job runs the inexpensive Flutter-pin verifier on every pull request. Pin drift therefore fails before merge without consuming a macOS runner.

Preview failures are recorded as failed scheduled or manually dispatched runs. They cannot block ordinary pull requests because those pull requests do not trigger this workflow. A hosted preview label can become unavailable before a job starts, and job timeouts do not cover queue time, so a missing or persistently queued nightly is an infrastructure alert rather than a pass.

The workflow records the hosted image, macOS, architecture, exact Xcode build, SDK versions, and installed runtimes through the shared `mobile-ci-tools` action. It verifies toolchain families rather than copying an exact beta-image pin into this repository.

Exact beta-image validation belongs in a temporary, explicitly test-only PR. When Xcode 27 becomes stable, remove this temporary preview workflow and add Xcode 27 to the normal required CI path.

A pass proves simulator compilation of the named Flutter fixture and dependency-manager path. It does not prove app launch, lifecycle callback forwarding, physical-device push delivery, signing, export, or App Store acceptance.
