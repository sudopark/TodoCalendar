import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "Domain",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        dependencies: [
                                            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                                            .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "CalendarDomain", path: .relativeToRoot("Domain/CalendarDomain")),
                                            .project(target: "CalendarRepositoryInterface", path: .relativeToRoot("Repository/CalendarRepository")),
                                            .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
                                            .project(target: "Extensions", path: .relativeToRoot("Supports/Extensions"))
                                        ])


