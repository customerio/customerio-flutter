// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "customer_io",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "customer-io", targets: ["customer_io"])
    ],
    dependencies: [
        .package(url: "https://github.com/customerio/customerio-ios.git", exact: "4.4.0")
    ],
    targets: [
        .target(
            name: "customer_io",
            dependencies: [
                .product(name: "DataPipelines", package: "customerio-ios"),
                .product(name: "MessagingInApp", package: "customerio-ios"),
                .product(name: "MessagingPushAPN", package: "customerio-ios")
            ]
        )
    ]
)
