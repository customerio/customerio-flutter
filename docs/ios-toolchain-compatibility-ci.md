# iOS toolchain compatibility CI

`iOS toolchain compatibility` compiles the CocoaPods and SwiftPM sample apps on the supported Xcode 26.6 toolchain and the floating Xcode 27 preview runner. Both sides install the exact Flutter version in each app's `.flutter-version` file, and the repository verifier requires the two pins to remain synchronized and compatible with Xcode 27.

The stable cells are required regression evidence. Preview cells are experimental and non-blocking until Xcode 27 is supported as a stable toolchain. The workflow records the hosted image, macOS, architecture, exact Xcode build, SDK versions, and installed runtimes through the shared `mobile-ci-tools` action. It verifies toolchain families rather than copying an exact beta-image pin into this repository.

Exact beta-image validation belongs in a temporary, explicitly test-only PR. When Xcode 27 becomes stable, change its matrix cells to the supported stable runner/version and make them blocking. Remove preview wording at the same time.

A pass proves simulator compilation of the named Flutter fixture and dependency-manager path. It does not prove app launch, lifecycle callback forwarding, physical-device push delivery, signing, export, or App Store acceptance.
