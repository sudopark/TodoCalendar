import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "DBInfra",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty"))
    ],
    dependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "ExternalCalendarDomainInterface",
                 path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "UnitTestHelpKit",
                 path: .relativeToRoot("Supports/UnitTestHelpKit")),
        .xctest
    ]
)
