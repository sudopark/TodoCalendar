import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "RemoteInfra",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Domain",
                 path: .relativeToRoot("Domain")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Domain",
                 path: .relativeToRoot("Domain")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions")),
        .project(target: "StorageInfraInterface",
                 path: .relativeToRoot("Repository/Infra/StorageInfra"))
    ],
    testingDependencies: [
        .target(name: "RemoteInfra"),
        .project(target: "Domain",
                 path: .relativeToRoot("Domain")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions")),
        .project(target: "StorageInfraInterface",
                 path: .relativeToRoot("Repository/Infra/StorageInfra"))
    ]
)
