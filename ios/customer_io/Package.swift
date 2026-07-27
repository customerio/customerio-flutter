// swift-tools-version: 5.9

import PackageDescription
import Foundation

// MARK: - Optional Module Configuration
//
// The Location and Live Activities modules are optional and excluded by default.
// To enable one, use ONE of these approaches (checked in this order):
//
// 1. Set in your Flutter app's android/gradle.properties (recommended, works for both platforms):
//      customerio_location_enabled=true
//      customerio_live_activities_enabled=true
//
// 2. Set an environment variable (required for Flutter add-to-app modules or custom project structures):
//      CIO_LOCATION=true flutter build ios
//      CIO_LIVE_ACTIVITIES=true flutter build ios
//

/// Reads a value for the given key from a Java-style .properties file.
/// Returns nil if the file cannot be read or the key is not found.
func readProperty(_ key: String, from path: String) -> String? {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return nil
    }
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("!") {
            continue
        }
        let parts = trimmed.split(separator: "=", maxSplits: 1)
        if parts.count == 2,
           parts[0].trimmingCharacters(in: .whitespaces) == key {
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
    }
    return nil
}

/// Walks up the directory tree from `startDir` looking for android/gradle.properties
/// and reads the given key if found. Combines search and read into a single pass to
/// avoid redundant file I/O. Checks up to 15 parent directories for monorepo support.
func readGradleProperty(_ key: String, from startDir: String) -> String? {
    var dir = URL(fileURLWithPath: startDir).standardized
    for _ in 0..<15 {
        let candidate = dir.appendingPathComponent("android/gradle.properties").path
        if let value = readProperty(key, from: candidate) {
            return value
        }
        let parent = dir.deletingLastPathComponent()
        if parent.path == dir.path { break }
        dir = parent
    }
    return nil
}

/// Determines whether an optional module should be included.
/// Checks gradle.properties first (file-based, persistent), then falls back to environment variable.
/// Returns false if no configuration is found — every module using this is opt-in.
func isModuleEnabled(propertyKey: String, envKey: String) -> Bool {
    let env = ProcessInfo.processInfo.environment

    // 1. Try gradle.properties via PWD (preserves symlink path in Flutter's SPM structure).
    if let pwd = env["PWD"],
       let value = readGradleProperty(propertyKey, from: pwd) {
        return value.lowercased() == "true"
    }

    // 2. Try gradle.properties via FileManager cwd (resolves symlinks; works for direct CLI usage).
    let cwd = FileManager.default.currentDirectoryPath
    if let value = readGradleProperty(propertyKey, from: cwd) {
        return value.lowercased() == "true"
    }

    // 3. Fallback: environment variable (required for add-to-app modules and custom project layouts).
    return env[envKey]?.lowercased() == "true"
}

let useLocation = isModuleEnabled(
    propertyKey: "customerio_location_enabled",
    envKey: "CIO_LOCATION"
)

let useLiveActivities = isModuleEnabled(
    propertyKey: "customerio_live_activities_enabled",
    envKey: "CIO_LIVE_ACTIVITIES"
)

var targetDependencies: [Target.Dependency] = [
    .product(name: "DataPipelines", package: "customerio-ios"),
    .product(name: "MessagingInApp", package: "customerio-ios"),
    .product(name: "MessagingPushFCM", package: "customerio-ios"),
    .product(name: "CioFirebaseWrapper", package: "customerio-ios-fcm")
]

if useLocation {
    targetDependencies.append(.product(name: "Location", package: "customerio-ios"))
}

// Live Activities (iOS) native rendering + built-in templates. Opt-in: the Templates product ships
// SwiftUI widget UI that is dead weight for apps which never run a Live Activity. The plugin's Swift
// is guarded by `#if canImport(CioLiveActivities)`, so it compiles to no-ops when this is off.
// NOTE: requires the customerio-ios pin below to include Live Activities (>= the LA release).
if useLiveActivities {
    targetDependencies.append(contentsOf: [
        .product(name: "LiveActivities", package: "customerio-ios"),
        .product(name: "LiveActivities_Attributes", package: "customerio-ios"),
        .product(name: "LiveActivities_Templates", package: "customerio-ios")
    ])
}

let package = Package(
    name: "customer_io",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "customer-io", targets: ["customer_io"])
    ],
    dependencies: [
        // TEMPORARY (REL-1): Live Activities products only exist on this branch. Restore an
        // exact released version once they ship.
        .package(url: "https://github.com/customerio/customerio-ios.git", branch: "live-activities-sdk-managed-module"),
        .package(url: "https://github.com/customerio/customerio-ios-fcm.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "customer_io",
            dependencies: targetDependencies
        )
    ]
)
