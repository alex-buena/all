import ProjectDescription

let project = Project(
    name: "benjamin",
    targets: [
        .target(
            name: "benjamin",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.benjamin",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            buildableFolders: [
                "benjamin/Sources",
                "benjamin/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "benjaminTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.benjaminTests",
            infoPlist: .default,
            buildableFolders: [
                "benjamin/Tests"
            ],
            dependencies: [.target(name: "benjamin")]
        ),
    ]
)
