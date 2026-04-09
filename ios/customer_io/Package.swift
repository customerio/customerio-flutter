// swift-tools-version: 5.9

import PackageDescription
import Foundation

// MARK: - Location Module Configuration
//
// The Location module is optional. To enable it, set the following property
// in your Flutter app's android/gradle.properties:
//
//   customerio_location_enabled=true
//
// This single property controls both Android and iOS.
//
// Alternatively, you can set the CIO_LOCATION environment variable:
//
//   CIO_LOCATION=true flutter build ios
//

/// Reads a value for the given key from a Java-style .properties file.
func readProperty(_ key: String, from path: String) -> String? {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return nil
    }
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("!") else { continue }
        let parts = trimmed.split(separator: "=", maxSplits: 1)
        guard parts.count == 2,
              parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }
    return nil
}

/// Walks up from `startDir` looking for android/gradle.properties.
func findGradleProperties(from startDir: String) -> String? {
    var dir = URL(fileURLWithPath: startDir).standardized
    for _ in 0..<10 {
        let candidate = dir.appendingPathComponent("android/gradle.properties").path
        if FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        let parent = dir.deletingLastPathComponent()
        if parent.path == dir.path { break }
        dir = parent
    }
    return nil
}

let useLocation: Bool = {
    // 1. Try gradle.properties using PWD (preserves symlink path in Flutter's SPM structure).
    if let pwd = ProcessInfo.processInfo.environment["PWD"],
       let path = findGradleProperties(from: pwd),
       let value = readProperty("customerio_location_enabled", from: path) {
        return value.lowercased() == "true"
    }
    // 2. Try from FileManager cwd (resolves symlinks, works for direct CLI usage).
    let cwd = FileManager.default.currentDirectoryPath
    if let path = findGradleProperties(from: cwd),
       let value = readProperty("customerio_location_enabled", from: path) {
        return value.lowercased() == "true"
    }
    // 3. Fallback to environment variable.
    return ProcessInfo.processInfo.environment["CIO_LOCATION"]?.lowercased() == "true"
}()

var targetDependencies: [Target.Dependency] = [
    .product(name: "DataPipelines", package: "customerio-ios"),
    .product(name: "MessagingInApp", package: "customerio-ios"),
    .product(name: "MessagingPushFCM", package: "customerio-ios"),
    .product(name: "CioFirebaseWrapper", package: "customerio-ios-fcm")
]

if useLocation {
    targetDependencies.append(.product(name: "Location", package: "customerio-ios"))
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
        .package(url: "https://github.com/customerio/customerio-ios.git", exact: "4.4.0"),
        .package(url: "https://github.com/customerio/customerio-ios-fcm.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "customer_io",
            dependencies: targetDependencies
        )
    ]
)
