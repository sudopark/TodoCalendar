import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "ExternalServices",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(
            target: "Domain",
            path: .relativeToCurrentFile("../../Domain")
        ),
        .external(name: "SwiftLinkPreview")
    ]
)
