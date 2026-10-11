// swift-tools-version:5.9
// Onlang iOS SDK 1.0.0-rc.1: DivKit rendering, flows, telemetry and the optional StoreKit 2 adapter.
// Generated from the Onlang monorepo (sdks/ios/scripts/release-packages.mjs); do not edit here.
import PackageDescription

let package = Package(
  name: "Onlang",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "OnlangKit", targets: ["OnlangKit"]),
    .library(name: "OnlangStoreKit", targets: ["OnlangStoreKit"]),
    .library(name: "OnlangCore", targets: ["OnlangCore"]),
    .library(name: "OnlangContract", targets: ["OnlangContract"]),
  ],
  dependencies: [
    .package(url: "https://github.com/divkit/divkit-ios.git", exact: "33.6.0"),
    .package(url: "https://github.com/yandex/vgsl.git", "8.3.0" ..< "9.0.0"),
  ],
  targets: [
    .target(name: "OnlangContract"),
    .target(name: "OnlangCore", dependencies: ["OnlangContract"]),
    .target(
      name: "OnlangKit",
      dependencies: [
        "OnlangCore",
        "OnlangContract",
        .product(name: "DivKit", package: "divkit-ios"),
        .product(name: "VGSL", package: "vgsl"),
      ]
    ),
    .target(name: "OnlangStoreKit", dependencies: ["OnlangKit", "OnlangCore"]),
  ]
)
