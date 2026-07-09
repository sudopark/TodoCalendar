import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "SnapshotTestHelpKit",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .external(name: "SnapshotTesting"),
        .xctest
    ]
)
