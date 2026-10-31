import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "BillingScenes",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
                                            .project(target: "AdDomainInterface", path: .relativeToRoot("Domain/AdDomain")),
                                            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "BillingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/BillingSceneInterface")),
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToRoot("Presentations/CommonPresentation")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions"))
                                        ],
                                        testDependencies: [
                                            .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
                                            .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])
