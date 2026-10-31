import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "SettingScene",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        resources: ["Resources/**"],
                                        snapshotTests: true,
                                        dependencies: [
                                            .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
                                            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
                                            .project(target: "BillingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/BillingSceneInterface")),
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "MemberSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/MemberSceneInterface")),
                                            .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
                                            .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SettingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/SettingSceneInterface")),
                                            .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "WidgetGallerySceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/WidgetGallerySceneInterface")),
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
                                            .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "NotificationDomainTesting", path: .relativeToRoot("Domain/NotificationDomain")),
                                            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
                                            .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
                                            .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
                                        ])

