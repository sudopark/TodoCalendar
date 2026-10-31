import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "CalendarPresentation",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        dependencies: [
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                                            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                                            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
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
                                            .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain"))
                                        ])
