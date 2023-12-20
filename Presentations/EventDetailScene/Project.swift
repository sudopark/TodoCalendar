import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "EventDetailScene",
                                        platform: .iOS,
                                        iOSTargetVersion: "16.0",
                                        dependencies: [
                                            .project(target: "Common3rdParty",
                                                     path: .relativeToCurrentFile("../../Supports/Common3rdParty")),
                                            .project(target: "CommonPresentation",
                                                     path: .relativeToCurrentFile("../../Presentations/CommonPresentation")),
                                            .project(target: "Domain",
                                                     path: .relativeToCurrentFile("../../Domain")),
                                            .project(target: "Extensions",
                                                     path: .relativeToCurrentFile("../../Supports/Extensions")),
                                            .project(target: "Scenes",
                                                     path: .relativeToCurrentFile("../../Presentations/Scenes"))
                                        ])


