// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FreeBikeControlCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ControlCore", targets: ["ControlCore"])],
    targets: [
        .target(name: "ControlCore", path: "freeBikeControl", exclude: ["Assets.xcassets", "ClickBluetooth.swift", "ContentView.swift", "freeBikeControlApp.swift", "RideSession.swift", "TrainerBridge.swift", "GearingView.swift", "RideTheme.swift", "ControllerPad.swift"], sources: ["ControlProtocol.swift", "Drivetrain.swift", "GearingStore.swift"]),
        .testTarget(name: "ControlCoreTests", dependencies: ["ControlCore"])
    ]
)
