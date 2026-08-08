import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "AuthService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(
            target: "Common3rdParty",
            path: .relativeToRoot("Supports/Common3rdParty")
        ),
        .project(
            target: "Domain",
            path: .relativeToRoot("Domain")
        ),
        .project(
            target: "Extensions",
            path: .relativeToRoot("Supports/Extensions")
        )
    ]
)
