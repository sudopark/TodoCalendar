import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "CommonPresentation",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    snapshotTests: true,
    dependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "AdDomainInterface", path: .relativeToRoot("Domain/AdDomain")),
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions")),
        .external(name: "Kingfisher"),
        .external(name: "Toaster")
    ],
    testDependencies: [
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain"))
    ]
)
