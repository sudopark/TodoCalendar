import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "BillingSceneInterface",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
