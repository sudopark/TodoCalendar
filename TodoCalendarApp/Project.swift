import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(
    name: "TodoCalendarApp",
    platform: .iOS,
    iOSTargetVersion: "17.0",
    dependencies: [
        .target(
            name: "TodoCalendarAppWidget", condition: nil
        ),
        .target(
            name: "TodoCalendarAppIntentExtensions", condition: nil
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
            iOSTargetVersion: "17.0",
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
                ),
                .project(
                    target: "CalendarScenes",
                    path: .relativeToCurrentFile("../Presentations/CalendarScenes")
                )
            ]
        )
    + Project.makeAppExtensionTargets(
        appName: "TodoCalendarApp",
        extensionName: "IntentExtensions",
        platform: .iOS,
        iOSTargetVersion: "17.0",
        infoPlist: [
            "INIntentsSupported": .array([.string("EventListTypeSelect")]),
            "NSExtension": .dictionary([
                "NSExtensionAttributes" : .dictionary([
                    "IntentsRestrictedWhileLocked": .array([]),
                    "IntentsSupported": .array([.string("EventListTypeSelectIntent")])
                ]),
                "NSExtensionPointIdentifier": .string("com.apple.intents-service"),
                "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).IntentHandler")
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
        ],
        withTest: false
    )
)

