import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "CalendarScenes",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "AIAgentSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/AIAgentSceneInterface")),
                                            .project(target: "AIDomainInterface", path: .relativeToRoot("Domain/AIDomain")),
                                            .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
                                            .project(target: "BillingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/BillingSceneInterface")),
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "CalendarSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/CalendarSceneInterface")),
                                            .project(target: "EventDetailSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventDetailSceneInterface")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "EventListSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventListSceneInterface")),
                                            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "MemberSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/MemberSceneInterface")),
                                            .project(target: "MigrationDomainInterface", path: .relativeToRoot("Domain/MigrationDomain")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "CalendarPresentation",
                                                     path: .relativeToRoot("Presentations/CalendarPresentation")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToRoot("Presentations/CommonPresentation")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions"))
                                        ],
                                        testDependencies: [
                                            .project(target: "AIDomainTesting", path: .relativeToRoot("Domain/AIDomain")),
                                            .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
                                            .project(target: "CalendarDomain", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "MigrationDomainTesting", path: .relativeToRoot("Domain/MigrationDomain")),
                                            .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])

