import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "RemoteInfra",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "KernelUtils",
                 path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions")),
        .project(target: "StorageInfraInterface",
                 path: .relativeToRoot("Repository/Infra/StorageInfra"))
    ],
    dependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "KernelUtils",
                 path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions")),
        .project(target: "StorageInfraInterface",
                 path: .relativeToRoot("Repository/Infra/StorageInfra"))
    ],
    testingDependencies: [
        .project(target: "KernelUtils",
                 path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "Extensions",
                 path: .relativeToRoot("Supports/Extensions")),
        .project(target: "StorageInfraInterface",
                 path: .relativeToRoot("Repository/Infra/StorageInfra"))
    ]
)
