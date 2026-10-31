import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "WidgetGallerySceneInterface",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
