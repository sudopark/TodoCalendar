import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "CalendarDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "CalendarRepositoryInterface", path: .relativeToRoot("Repository/CalendarRepository")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty"))
    ]
)
