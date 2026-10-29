import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "CalendarRepository",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty"))
    ],
    testingDependencies: [
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty"))
    ],
    withTest: false
)
