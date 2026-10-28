# Customer.io Flutter SDK

Flutter plugin over the native Customer.io Android and iOS SDKs.

## Layout
- `lib/`: Dart API
- `android/`, `ios/`: native plugin code for the wrapped SDKs
- `apps/`: sample apps (`flutter_sample_cocoapods`, `flutter_sample_spm`)
- `test/`: Dart tests
- `scripts/`: API extraction and check scripts
- `customerio-flutter.api`: checked-in public API baseline

## Commands
Run from the repo root.
- Install dependencies: `flutter pub get`
- Analyze: `flutter analyze` (the lint workflow runs this)
- Test: `flutter test`
- Regenerate the API baseline: `./scripts/extract_api.sh`. It fails unless the installed Flutter version equals the one in `scripts/api-extraction-flutter-version.txt`.
- Check for API changes: `./scripts/check_api_changes.sh`

## Conventions
- After changing the public Dart API, regenerate `customerio-flutter.api` with `./scripts/extract_api.sh` and commit it. The `check_api_changes` job in `.github/workflows/check-api-changes.yml` runs `./scripts/check_api_changes.sh`.
- Native SDK versions are pinned in several files. When bumping iOS, set the same version in `pubspec.yaml` (`native_sdk_version`), `ios/customer_io/Package.swift`, `apps/flutter_sample_cocoapods/ios/Podfile`, and `apps/flutter_sample_spm/ios/Runner.xcodeproj/project.pbxproj`. For Android, change the default `cioVersion` in `android/build.gradle`. The steps are in `.cursor/commands/update-native-sdks.md`.
