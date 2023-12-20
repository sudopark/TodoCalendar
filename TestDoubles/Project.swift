import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(name: "TestDoubles",
                                platform: .iOS,
                                iOSTargetVersion: "16.0",
                                dependencies: [
                                    .project(target: "Common3rdParty", path: .relativeToCurrentFile("../Common3rdParty")),
                                    .project(target: "Domain", path: .relativeToCurrentFile("../Domain")),
                                    .project(target: "Extensions", path: .relativeToCurrentFile("../Extensions")),
                                    .project(target: "Scenes", path: .relativeToCurrentFile("../Scenes")),
                                    .project(target: "UnitTestHelpKit", path: .relativeToCurrentFile("../UnitTestHelpKit")),
                                    .sdk(name: "XCTest", type: .framework)
                                ])

