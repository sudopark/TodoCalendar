import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(name: "TodoCalendarApp",
                          platform: .iOS,
                          iOSTargetVersion: "16.4",
                          dependencies: [
                            .project(target: "CalendarScenes", 
                                     path: .relativeToCurrentFile("../Presentations/CalendarScenes")),
                            .project(target: "Common3rdParty",
                                     path: .relativeToCurrentFile("../Supports/Common3rdParty")),
                            .project(target: "CommonPresentation",
                                     path: .relativeToCurrentFile("../Presentations/CommonPresentation")),
                            .project(target: "Domain",
                                     path: .relativeToCurrentFile("../Domain")),
                            .project(target: "EventDetailScene",
                                     path: .relativeToCurrentFile("../Presentations/EventDetailScene")),
                            .project(target: "Extensions",
                                     path: .relativeToCurrentFile("../Supports/Extensions")),
                            .project(target: "Repository",
                                     path: .relativeToCurrentFile("../Repository")),
                            .project(target: "Scenes",
                                     path: .relativeToCurrentFile("../Presentations/Scenes")),
                            .project(target: "SettingScene",
                                     path: .relativeToCurrentFile("../Presentations/SettingScene"))
                          ])

