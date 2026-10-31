import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "WidgetScenes",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        resources: ["Resources/**"],
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "BillingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/BillingSceneInterface")),
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "WidgetGallerySceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/WidgetGallerySceneInterface")),
                                            .project(target: "CalendarPresentation",
                                                     path: .relativeToRoot("Presentations/CalendarPresentation")),
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToRoot("Presentations/CommonPresentation")),
                                            .project(target: "Extensions",
                                                     path: .relativeToRoot("Supports/Extensions"))
                                        ],
                                        testDependencies: [
                                            .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])
