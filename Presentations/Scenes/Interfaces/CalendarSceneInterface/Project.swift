import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "CalendarSceneInterface",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
