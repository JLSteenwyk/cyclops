// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Cyclops",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "Cyclops", targets: ["Cyclops"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/sparkle-project/Sparkle",
      exact: "2.9.6"
    )
  ],
  targets: [
    .executableTarget(
      name: "Cyclops",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-rpath",
          "-Xlinker", "@executable_path/../Frameworks",
        ])
      ]
    ),
    .testTarget(
      name: "CyclopsTests",
      dependencies: ["Cyclops"]
    ),
  ]
)
