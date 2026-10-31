import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "MemberScenes",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    snapshotTests: true,
    dependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "MemberSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/MemberSceneInterface")),
        .project(target: "MigrationDomainInterface", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "CommonPresentation",
                 path: .relativeToRoot("Presentations/CommonPresentation")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "MigrationDomainTesting", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
    ]
)

