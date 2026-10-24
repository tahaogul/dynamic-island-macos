// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "Sources/DynamicIsland",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/DynamicIsland/Info.plist"]),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
