import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "AIDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "DBInfraTesting", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "NotificationDomainTesting", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraTesting", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
