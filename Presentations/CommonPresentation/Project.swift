import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "CommonPresentation",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    snapshotTests: true,
    dependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Domain", path: .relativeToRoot("Domain")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions")),
        .external(name: "Kingfisher"),
        .external(name: "Toaster")
    ]
)
