import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "SceneInfra",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "AIDomainInterface", path: .relativeToRoot("Domain/AIDomain")),
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "AdDomainInterface", path: .relativeToRoot("Domain/AdDomain")),
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "MigrationDomainInterface", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "CommonPresentation", path: .relativeToRoot("Presentations/CommonPresentation")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
    ]
)
