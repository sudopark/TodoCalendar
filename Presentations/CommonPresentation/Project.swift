import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "CommonPresentation",
    packages: [
        .remote(
            url: "https://github.com/onevcat/Kingfisher.git",
            requirement: .upToNextMajor(from: "7.12.0")
        ),
        .remote(
            url: "https://github.com/devxoul/Toaster.git",
            requirement: .branch("master")
        )
    ],
    platform: .iOS,
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "Common3rdParty", path: .relativeToCurrentFile("../../Supports/Common3rdParty")),
        .project(target: "Domain", path: .relativeToCurrentFile("../../Domain")),
        .project(target: "Extensions", path: .relativeToCurrentFile("../../Supports/Extensions")),
        .package(product: "Kingfisher"),
        .package(product: "Toaster")
    ]
)
