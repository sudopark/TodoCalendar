import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "MigrationDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "AIDomain", path: .relativeToRoot("Domain/AIDomain")),
        .project(target: "CalendarDomain", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "NotificationDomain", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SettingDomain", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "DBInfra", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraTesting", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraTesting", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SettingDomain", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "StorageInfraTesting", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
