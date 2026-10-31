import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "FirstPartyServices",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
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
