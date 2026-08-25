import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "SnapshotTestHelpKit",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    resources: ["Resources/**"],
    dependencies: [
        .external(name: "SnapshotTesting"),
        .xctest
    ]
)
