import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "Repository",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        dependencies: [
                                            .project(target: "Common3rdParty", 
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "Domain",
                                                     path: .relativeToRoot("Domain")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions")),
                                            .project(target: "StorageInfraInterface",
                                                     path: .relativeToRoot("Repository/Infra/StorageInfra")),
                                            .project(target: "StorageInfra",
                                                     path: .relativeToRoot("Repository/Infra/StorageInfra")),
                                            .project(target: "DBInfraInterface",
                                                     path: .relativeToRoot("Repository/Infra/DBInfra")),
                                            .project(target: "DBInfra",
                                                     path: .relativeToRoot("Repository/Infra/DBInfra")),
                                            .project(target: "RemoteInfraInterface",
                                                     path: .relativeToRoot("Repository/Infra/RemoteInfra")),
                                            .project(target: "RemoteInfra",
                                                     path: .relativeToRoot("Repository/Infra/RemoteInfra"))
                                        ],
                                        testDependencies: [
                                            .project(target: "StorageInfraTesting",
                                                     path: .relativeToRoot("Repository/Infra/StorageInfra")),
                                            .project(target: "RemoteInfraTesting",
                                                     path: .relativeToRoot("Repository/Infra/RemoteInfra")),
                                            .project(target: "RemoteInfraInterface",
                                                     path: .relativeToRoot("Repository/Infra/RemoteInfra")),
                                            .project(target: "RemoteInfra",
                                                     path: .relativeToRoot("Repository/Infra/RemoteInfra"))
                                        ])


