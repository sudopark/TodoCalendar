import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "StoreKitService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
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
