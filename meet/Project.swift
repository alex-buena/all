import ProjectDescription

let project = Project(
    name: "meet",
    targets: [
        .target(
            name: "meet",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.meet",
            infoPlist: .extendingDefault(
                with: [
                    "FOURSQUARE_API_KEY": "IKJT4VF4QTGI0RI3JWPZKNA3ADMKK24TN4XDXOTHQCTSBZXD",
                    "FSQ_API_KEY": "IKJT4VF4QTGI0RI3JWPZKNA3ADMKK24TN4XDXOTHQCTSBZXD",
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["meet/Sources/**"],
            resources: ["meet/Resources/**"],
            dependencies: [
                .external(name: "SwiftyH3"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "9DB3G7Q9U4",
                    "CODE_SIGN_IDENTITY[sdk=iphoneos*]": "Apple Development",
                    "CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]": "NO",
                    "CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]": "NO",
                ]
            )
        ),
        .target(
            name: "meetTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.meetTests",
            infoPlist: .default,
            sources: ["meet/Tests/**"],
            dependencies: [.target(name: "meet")]
        ),
    ]
)
