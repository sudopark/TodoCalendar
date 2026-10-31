import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.frameworkWithTest(
    name: "AuthService",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(
            target: "Common3rdParty",
            path: .relativeToRoot("Supports/Common3rdParty")
        ),
        .project(
            target: "Extensions",
            path: .relativeToRoot("Supports/Extensions")
        )
    ],
    testDependencies: [
        .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain"))
    ]
)
