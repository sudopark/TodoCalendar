import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(name: "Common3rdParty",
                                platform: .iOS,
                                iOSTargetVersion: "15.0",
                                dependencies: [
                                    .external(name: "Alamofire"),
                                    .external(name: "Prelude"),
                                    .external(name: "AsyncAlgorithms"),
                                    .external(name: "AsyncFlatMap"),
                                    .external(name: "SQLiteService"),
                                    .external(name: "CombineCocoa"),
                                    .external(name: "Pulse"),
                                    .external(name: "PulseUI"),
                                    .external(name: "Optics")
                                ])
