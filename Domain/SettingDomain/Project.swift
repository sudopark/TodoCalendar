import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "SettingDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "NotificationDomainTesting", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraTesting", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "StorageInfraTesting", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
