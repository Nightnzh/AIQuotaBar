// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIQuotaBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AIQuotaBar", targets: ["AIQuotaBar"])
    ],
    targets: [
        .executableTarget(
            name: "AIQuotaBar",
            path: "Sources/AIQuotaBar"
        ),
        .testTarget(
            name: "AIQuotaBarTests",
            dependencies: ["AIQuotaBar"],
            path: "Tests/AIQuotaBarTests"
        )
    ]
)
