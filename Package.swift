// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Pocus",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "Pocus", targets: ["Pocus"])
  ],
  targets: [
    .executableTarget(name: "Pocus"),
    .testTarget(
      name: "PocusTests",
      dependencies: ["Pocus"]
    ),
  ]
)
