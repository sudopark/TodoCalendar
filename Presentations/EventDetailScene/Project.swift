import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "EventDetailScene",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDetailSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventDetailSceneInterface")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
                                            .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SettingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/SettingSceneInterface")),
                                            .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToRoot("Presentations/CommonPresentation")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions"))
                                        ],
                                        testDependencies: [
                                            .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "NotificationDomainTesting", path: .relativeToRoot("Domain/NotificationDomain")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])


