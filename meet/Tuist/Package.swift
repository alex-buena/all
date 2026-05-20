// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        // Customize the product types for specific package product
        // Default is .staticFramework
        // productTypes: ["Alamofire": .framework,]
        productTypes: [:]
    )
#endif

let package = Package(
    name: "meet",
    dependencies: [
        .package(url: "https://github.com/pawelmajcher/SwiftyH3.git", "0.5.0"..<"0.6.0"),
    ]
)
