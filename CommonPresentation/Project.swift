import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(name: "CommonPresentation",
                                packages: [
                                    .remote(url: "https://github.com/onevcat/Kingfisher.git",
                                            requirement: .upToNextMajor(from: "7.10.0"))
                                ],
                                platform: .iOS,
                                iOSTargetVersion: "16.0",
                                dependencies: [
                                    .project(target: "Common3rdParty", path: .relativeToCurrentFile("../Common3rdParty")),
                                    .project(target: "Domain", path: .relativeToCurrentFile("../Domain")),
                                    .project(target: "Extensions", path: .relativeToCurrentFile("../Extensions")),
                                    .package(product:  "Kingfisher")
                                ])


