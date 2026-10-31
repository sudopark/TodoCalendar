import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "BillingDomain",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    dependencies: [
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testingDependencies: [
        .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ],
    testDependencies: [
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraTesting", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraTesting", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "StorageInfraTesting", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
    ]
)
