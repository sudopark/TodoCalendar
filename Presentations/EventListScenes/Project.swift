import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "EventListScenes",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    snapshotTests: true,
    dependencies: [
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDetailSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventDetailSceneInterface")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventListSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventListSceneInterface")),
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "CommonPresentation", path: .relativeToRoot("Presentations/CommonPresentation")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
    ]
)

