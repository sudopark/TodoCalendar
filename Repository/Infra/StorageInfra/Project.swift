import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithInterfaceAndTesting(
    name: "StorageInfra",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    resources: ["Sources/PrivacyInfo.xcprivacy"],
    dependencies: [
        .project(target: "Common3rdParty",
                 path: .relativeToRoot("Supports/Common3rdParty"))
    ]
)
