import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "ExternalCalendarDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "UnitTestHelpKit", path: .relativeToRoot("Supports/UnitTestHelpKit")),
        .xctest,
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "DBInfra", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraTesting", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "RemoteInfra", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraTesting", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
