import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(
    name: "TodoCalendarApp",
    platform: .iOS,
    iOSTargetVersion: "16.4",
    dependencies: [
        .target(
            name: "TodoCalendarAppWidget", condition: nil
        ),
        .project(
            target: "CalendarScenes",
            path: .relativeToCurrentFile("../Presentations/CalendarScenes")
        ),
        .project(
            target: "Common3rdParty",
            path: .relativeToCurrentFile("../Supports/Common3rdParty")
        ),
        .project(
            target: "CommonPresentation",
            path: .relativeToCurrentFile("../Presentations/CommonPresentation")
        ),
        .project(
            target: "Domain",
            path: .relativeToCurrentFile("../Domain")
        ),
        .project(
            target: "EventDetailScene",
            path: .relativeToCurrentFile("../Presentations/EventDetailScene")
        ),
        .project(
            target: "Extensions",
            path: .relativeToCurrentFile("../Supports/Extensions")
        ),
        .project(
            target: "Repository",
            path: .relativeToCurrentFile("../Repository")
        ),
        .project(
            target: "Scenes",
            path: .relativeToCurrentFile("../Presentations/Scenes")
        ),
        .project(
            target: "SettingScene",
            path: .relativeToCurrentFile("../Presentations/SettingScene")
        ),
        .project(
            target: "MemberScenes",
            path: .relativeToCurrentFile("../Presentations/MemberScenes")
        ),
        .project(
            target: "EventListScenes",
            path: .relativeToCurrentFile("../Presentations/EventListScenes")
        )
      ],
    extensionTargets:
        Project.makeAppExtensionTargets(
            appName: "TodoCalendarApp",
            extensionName: "Widget",
            platform: .iOS,
            iOSTargetVersion: "16.4",
            infoPlist: [
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
                ])
            ],
            dependencies: [
                .project(
                    target: "Extensions",
                    path: .relativeToCurrentFile("../Supports/Extensions")
                ),
                .project(
                    target: "Common3rdParty",
                    path: .relativeToCurrentFile("../Supports/Common3rdParty")
                ),
                .project(
                    target: "Domain",
                    path: .relativeToCurrentFile("../Domain")
                ),
                .project(
                    target: "Repository",
                    path: .relativeToCurrentFile("../Repository")
                ),
                .project(
                    target: "CommonPresentation",
                    path: .relativeToCurrentFile("../Presentations/CommonPresentation")
                )
            ]
        )
)

