import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(name: "TodoCalendarApp",
                          platform: .iOS,
                          iOSTargetVersion: "16.4",
                          dependencies: [
                            .project(target: "CalendarScenes", path: .relativeToCurrentFile("../CalendarScenes")),
                            .project(target: "Common3rdParty", path: .relativeToCurrentFile("../Common3rdParty")),
                            .project(target: "CommonPresentation", path: .relativeToCurrentFile("../CommonPresentation")),
                            .project(target: "Domain", path: .relativeToCurrentFile("../Domain")),
                            .project(target: "EventDetailScene", path: .relativeToCurrentFile("../EventDetailScene")),
                            .project(target: "Extensions", path: .relativeToCurrentFile("../Extensions")),
                            .project(target: "Repository", path: .relativeToCurrentFile("../Repository")),
                            .project(target: "Scenes", path: .relativeToCurrentFile("../Scenes")),
                            .project(target: "SettingScene", path: .relativeToCurrentFile("../SettingScene"))
                          ])

