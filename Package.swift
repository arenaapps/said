// swift-tools-version:5.10
import PackageDescription

// whisper.cpp is built into vendor/whisper by scripts/build-whisper.sh.
// scripts/release.sh points SAID_WHISPER_DIR at a build for both Intel and Apple silicon.
let whisper = "\(Context.packageDirectory)/\(Context.environment["SAID_WHISPER_DIR"] ?? "vendor/whisper")"

let package = Package(
    name: "Said",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(name: "CWhisper", path: "Sources/CWhisper"),
        .executableTarget(
            name: "Said",
            dependencies: ["CWhisper"],
            path: "Sources/Said",
            swiftSettings: [.unsafeFlags(["-Xcc", "-I\(whisper)/include"])],
            linkerSettings: [
                .unsafeFlags(["-L\(whisper)/lib"]),
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-blas"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("Foundation"),
            ]
        ),
        .testTarget(name: "SaidTests", dependencies: ["Said"], path: "Tests/SaidTests"),
    ]
)
