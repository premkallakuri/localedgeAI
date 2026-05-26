// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LocalEdgeAI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "LocalEdgeAI", targets: ["LocalEdgeAI"])
    ],
    targets: [
        // Google AI Edge LiteRT-LM as a binary target.
        // Only the iOS slices ship in CLiteRTLM.xcframework v0.12.0 — the
        // .when(platforms: [.iOS]) clause on the dependency below makes sure
        // we don't try to link it into macOS builds.
        .binaryTarget(
            name: "CLiteRTLM",
            path: "Frameworks/CLiteRTLM.xcframework"
        ),
        .executableTarget(
            name: "LocalEdgeAI",
            dependencies: [
                .target(name: "CLiteRTLM", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/LocalEdgeAI",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
