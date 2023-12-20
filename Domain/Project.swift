import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "Domain",
                                        platform: .iOS,
                                        iOSTargetVersion: "16.0",
                                        dependencies: [
                                            .project(target: "Common3rdParty", path: .relativeToCurrentFile("../Common3rdParty")),
                                            .project(target: "Extensions", path: .relativeToCurrentFile("../Extensions"))
                                        ])


