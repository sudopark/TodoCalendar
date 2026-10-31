import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "ExternalServices",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
                .external(name: "SwiftLinkPreview")
    ]
)
