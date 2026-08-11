# Xcode 27 preview CI

`Xcode 27 Flutter fixtures` is a compile-only early-warning lane for the CocoaPods and SwiftPM sample apps. It complements, and does not replace, the existing macOS 26 and Xcode 26.6 build workflows. A pass does not prove app launch, lifecycle callback forwarding, push delivery, or device behavior.

The `xcode-27` runner label is a floating GitHub public preview, not an immutable image selector. The local guard therefore fails before compilation unless the runner still matches image `20260810.0090.1`, macOS `26.5.2` (`25F84`) on `arm64`, Xcode 27.0 beta 4 build `27A5228h` at `/Applications/Xcode_27_beta_4.app`, the `iphoneos27.0` and `iphonesimulator27.0` SDKs, and runtime `com.apple.CoreSimulator.SimRuntime.iOS-27-0`. The workflow prints every observed value.

The guard must run before `flutter pub get`: it exports the pinned `DEVELOPER_DIR`, which Flutter inspects when deciding whether to generate the SwiftPM plugin package. The SwiftPM matrix cell also sets `FLUTTER_SWIFT_PACKAGE_MANAGER=true` explicitly.

`preview-infrastructure-drift` means the floating runner moved and requires pin review. `fixture-preparation-failure` means dependencies did not resolve, so no compile conclusion exists. `sdk-compile-failure` means the complete guard passed and a named Flutter fixture then failed to compile.

Squad Mobile owns this pin. The reviewed values come from the official [Xcode 27 preview announcement](https://github.com/actions/runner-images/issues/14404) and [image inventory for release 20260810.0090](https://github.com/actions/runner-images/blob/xcode-27-arm64/20260810.0090/images/macos/xcode-27-arm64-Readme.md). When the hosted label moves, verify the replacement inventory linked as `Included Software` by the job, then update the constants in `.github/actions/verify-xcode-27-preview/action.yml`. The same reviewed values must be updated in the native iOS and Expo repositories in the same tracking work, and both Flutter fixture jobs plus the existing Xcode 26 jobs must remain required evidence. Git history retains prior values for diagnosis; it cannot make a retired hosted image runnable.
