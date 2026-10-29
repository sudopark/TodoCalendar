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
        .project(target: "Domain",
                 path: .relativeToRoot("Domain")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions"))
    ]
)
