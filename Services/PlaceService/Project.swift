import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "PlaceService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
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
