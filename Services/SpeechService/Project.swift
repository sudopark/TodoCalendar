import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "SpeechService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
        .project(
            target: "Common3rdParty",
            path: .relativeToRoot("Supports/Common3rdParty")
        ),
        .project(
            target: "Extensions",
            path: .relativeToRoot("Supports/Extensions")
        )
    ]
)
