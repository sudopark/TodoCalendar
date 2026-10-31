import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(name: "TestDoubles",
                                destinations: [.iPhone],
                                iOSTargetVersion: "17.0",
                                dependencies: [
                                    .project(target: "Common3rdParty",
                                             path: .relativeToRoot("Supports/Common3rdParty")),
                                    .project(target: "Extensions",
                                             path: .relativeToRoot("Supports/Extensions")),
                                    .project(target: "SceneInfra",
                                             path: .relativeToRoot("Presentations/Scenes/SceneInfra"))
                                ])
