import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(name: "Extensions",
                                        platform: .iOS,
                                        iOSTargetVersion: "15.0",
                                        dependencies: [
                                            .project(target: "Common3rdParty", 
                                                     path: .relativeToCurrentFile("../../Supports/Common3rdParty"))
                                        ])


