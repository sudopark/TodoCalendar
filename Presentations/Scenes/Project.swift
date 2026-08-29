import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "Scenes",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "CommonPresentation", path: .relativeToRoot("Presentations/CommonPresentation")),
        .project(target: "Domain", path: .relativeToRoot("Domain")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
