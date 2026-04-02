import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "Extensions",
    iOSTargetVersion: "15.0",
    resources: ["Resources/**"],
    dependencies: [
        .project(
            target: "Common3rdParty",
            path: .relativeToCurrentFile("../../Supports/Common3rdParty")
        )
    ]
)
