# CocoaPods deployment-target normalization

Xcode validates the deployment target of every generated CocoaPods target, including dependency,
aggregate, privacy-manifest, and resource-bundle targets. Xcode 27 rejects targets below the build
range supported by its iOS SDK even when the dependency itself is source-compatible with your app.

The `customer_io` package includes an opt-in Podfile helper that raises low or missing generated
settings to iOS 15.0. It also covers the integrated Runner, Notification Service Extension, and
widget targets, while preserving any numeric deployment target already above 15.0. When a target
setting is absent, the helper resolves its target xcconfig and then the same-named project build
configuration, preserving a higher inherited app or extension floor. It changes local build
settings in the generated Pods project and CocoaPods-integrated Runner or extension projects. It
does not rewrite a podspec or change runtime API availability.

Customer.io deliberately continues to publish native SDKs that support iOS versions below 15. A
podspec can therefore correctly declare that lower library minimum even when the Flutter
application consuming it has moved to iOS 15 or later. CocoaPods carries deployment metadata from
Customer.io and third-party podspecs into generated build targets, but Xcode 27 no longer accepts
targets below the iOS SDK's supported build range. Raising every published podspec to iOS 15 would
unnecessarily drop older applications and would not control metadata from transitive
dependencies. The helper instead aligns the generated targets with the host application's chosen
minimum while leaving the packages' published runtime compatibility unchanged.
This is the supported integration policy for a Flutter application that has moved its own minimum
to iOS 15 or later.

> [!WARNING]
> This is an opt-in build migration. Integrated Runner and extension targets below iOS 15.0 are
> raised to 15.0. Shipping that project means users on iOS 13 or iOS 14 cannot install subsequent
> app updates. Adopt the helper only when your product has intentionally moved its application and
> extension deployment targets to iOS 15.

Load the helper after `flutter_install_all_ios_pods` has run, then call it at the end of the one
existing `post_install` block:

```ruby
target 'Runner' do
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

# Declare Notification Service Extension and widget targets before this line too.
require File.expand_path(
  File.join('.symlinks', 'plugins', 'customer_io', 'ios', 'cocoapods_deployment_target'),
  __dir__
)

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    # Keep the rest of your existing Flutter settings here.
  end

  CustomerIO::CocoaPodsDeploymentTarget.normalize!(
    installer,
    minimum_ios_version: '15.0'
  )
end
```

Run `flutter pub get`, remove the generated `ios/Pods` directory, and run `pod install` again. The
helper resolves target xcconfig settings and the matching project configuration before adding an
override. For each change, it prints a stable project, target, and configuration line with the
original effective value and final value. It fails the install if the selected effective value is
non-numeric, such as `$(CUSTOM_IOS_FLOOR)`, because the generated-project audit cannot prove its
resolved value. A non-numeric value at a lower precedence does not fail when an explicit numeric
target setting already determines the effective value.

If an error says an xcconfig cannot be read or parsed, repair or remove the reported base
configuration file reference for the reported project, target, and configuration. Run the helper
in the CocoaPods Ruby environment so the public `Xcodeproj::Config` parser is available.
Synchronized-group xcconfig references are not resolved by that public parser; if the helper
reports one, replace it with a standard xcconfig file reference, then run `pod install` again.
These cases fail before any project mutation.

## When the helper is no longer needed

Keep the helper while a supported dependency graph can validly include deployment metadata below
the host application's minimum. This is expected while Customer.io supports older iOS versions or
supported third-party pods continue to declare lower minimums. A `platform` declaration in the
application's Podfile alone does not guarantee that every generated target uses the same value.

The helper becomes unnecessary only when a clean install without it proves that every
target/configuration in every supported Flutter plugin and push-provider graph declares an
effective numeric deployment target at or above the host application's minimum. That state would
normally follow an intentional platform-support change across the SDK, wrappers, and relevant
dependencies; it is not a prerequisite for adopting Xcode 27. Keep the audit in CI after removing
the helper so a later dependency update cannot silently reintroduce a lower target.

For a deterministic CI audit, use the script from this repository with the installed CocoaPods
Ruby environment. Its stable report includes the target, matching project, and effective value.
Pass the `Pods` directory so the audit recursively discovers every `.xcodeproj`, including
CocoaPods multi-project output. It fails if a supplied path is missing or contains no projects. The
audit examines every target in each passed project, including non-integrated targets that the
normalizer intentionally does not change; set those targets to the host minimum explicitly.

```sh
bundle exec ruby scripts/audit_cocoapods_deployment_targets.rb \
  --minimum 15.0 \
  apps/flutter_sample_cocoapods/ios/Pods \
  apps/flutter_sample_cocoapods/ios/Runner.xcodeproj
```

Keep this audit next to the Flutter simulator build and unsigned generic-device archive. Passing
those checks does not prove real-device push delivery, signed archive export, or App Store
submission.
