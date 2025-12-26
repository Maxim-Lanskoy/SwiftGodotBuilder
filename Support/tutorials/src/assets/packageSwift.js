export default `// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SwiftRunner",
  platforms: [.macOS(.v14)],
  products: [
    .library(
      name: "SwiftRunner",
      type: .dynamic,
      targets: ["SwiftRunner"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/Maxim-Lanskoy/SwiftGodotBuilder", branch: "tweaks")
  ],
  targets: [
    .target(
      name: "SwiftRunner",
      dependencies: ["SwiftGodotBuilder"],
    )
  ]
)`;
