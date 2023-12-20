import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "SettingScene",
                                        platform: .iOS,
                                        iOSTargetVersion: "16.0",
                                        dependencies: [
                                            .project(target: "Common3rdParty", path: .relativeToCurrentFile("../Common3rdParty")),
                                            .project(target: "CommonPresentation", path: .relativeToCurrentFile("../CommonPresentation")),
                                            .project(target: "Domain", path: .relativeToCurrentFile("../Domain")),
                                            .project(target: "Extensions", path: .relativeToCurrentFile("../Extensions")),
                                            .project(target: "Scenes", path: .relativeToCurrentFile("../Scenes"))
                                        ])

