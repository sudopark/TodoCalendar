import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "AdService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(
            target: "Extensions",
            path: .relativeToRoot("Supports/Extensions")
        ),
        .external(name: "GoogleMobileAds"),
        .external(name: "GoogleUserMessagingPlatform")
    ]
)
