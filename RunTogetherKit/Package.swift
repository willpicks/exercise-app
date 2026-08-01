// swift-tools-version: 5.9
import PackageDescription

// The engine deliberately depends on nothing but Foundation. No HealthKit, no
// CloudKit, no SwiftUI. That is what lets the whole of the training logic be
// tested in milliseconds on any machine with a Swift toolchain, without a
// device, without HealthKit permissions, and without waiting out a real run.
let package = Package(
    name: "RunTogetherKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v13)
    ],
    products: [
        .library(name: "RunTogetherKit", targets: ["RunTogetherKit"])
    ],
    targets: [
        .target(name: "RunTogetherKit"),
        .testTarget(name: "RunTogetherKitTests", dependencies: ["RunTogetherKit"])
    ]
)
