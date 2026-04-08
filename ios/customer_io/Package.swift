// swift-tools-version: 5.9

import PackageDescription
import Foundation

// Check if the Location module should be included.
// Customers can opt in by setting the environment variable:
//   CIO_LOCATION=true
// e.g., in Xcode: CIO_LOCATION=true flutter build ios
let useLocation = ProcessInfo.processInfo.environment["CIO_LOCATION"]?.lowercased() == "true"

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
