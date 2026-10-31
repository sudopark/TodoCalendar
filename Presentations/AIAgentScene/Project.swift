import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "AIAgentScene",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "AIAgentSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/AIAgentSceneInterface")),
                                            .project(target: "AIDomainInterface", path: .relativeToRoot("Domain/AIDomain")),
                                            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToRoot("Presentations/CommonPresentation")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions"))
                                        ],
                                        testDependencies: [
                                            .project(target: "AIDomainTesting", path: .relativeToRoot("Domain/AIDomain")),
                                            .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])
