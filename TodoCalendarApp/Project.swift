import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(
    name: "TodoCalendarApp",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .target(
            name: "TodoCalendarAppWidget", condition: nil
        ),
        .target(
            name: "TodoCalendarAppIntentExtensions", condition: nil
        ),
        .target(
            name: "TodoCalendarAppShare", condition: nil
        ),
        .project(
            target: "CalendarScenes",
            path: .relativeToRoot("Presentations/CalendarScenes")
        ),
        .project(
            target: "Common3rdParty",
            path: .relativeToRoot("Supports/Common3rdParty")
        ),
        .project(
            target: "CommonPresentation",
            path: .relativeToRoot("Presentations/CommonPresentation")
        ),
        .project(
            target: "Domain",
            path: .relativeToRoot("Domain")
        ),
        .project(
            target: "EventDetailScene",
            path: .relativeToRoot("Presentations/EventDetailScene")
        ),
        .project(
            target: "Extensions",
            path: .relativeToRoot("Supports/Extensions")
        ),
        .project(
            target: "Repository",
            path: .relativeToRoot("Repository")
        ),
        .project(
            target: "Scenes",
            path: .relativeToRoot("Presentations/Scenes")
        ),
        .project(
            target: "SettingScene",
            path: .relativeToRoot("Presentations/SettingScene")
        ),
        .project(
            target: "MemberScenes",
            path: .relativeToRoot("Presentations/MemberScenes")
        ),
        .project(
            target: "EventListScenes",
            path: .relativeToRoot("Presentations/EventListScenes")
        ),
        .project(
            target: "AIAgentScene",
            path: .relativeToRoot("Presentations/AIAgentScene")
        ),
        .project(
            target: "BillingScenes",
            path: .relativeToRoot("Presentations/BillingScenes")
        ),
        .project(
            target: "FirstPartyServices",
            path: .relativeToRoot("Services/FirstPartyServices")
        ),
        .project(
            target: "SpeechService",
            path: .relativeToRoot("Services/SpeechService")
        ),
        .project(
            target: "PlaceService",
            path: .relativeToRoot("Services/PlaceService")
        ),
        .project(
            target: "AuthService",
            path: .relativeToRoot("Services/AuthService")
        ),
        .project(
            target: "ExternalServices",
            path: .relativeToRoot("Services/ExternalServices")
        ),
        .project(
            target: "StoreKitService",
            path: .relativeToRoot("Services/StoreKitService")
        )
      ],
    extensionTargets:
        Project.makeAppExtensionTargets(
            appName: "TodoCalendarApp",
            extensionName: "Widget",
            destinations: [.iPhone],
            iOSTargetVersion: "17.0",
            infoPlist: [
                "NSExtension": .dictionary([
                    "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
                ]),
                "CFBundleDisplayName": "To-do Calendar Widget",
                "CFBundleShortVersionString": "\(Project.appVersion)",
                "CFBundleVersion": "\(Project.buildNumber)"
            ],
            dependencies: [
                .project(
                    target: "Extensions",
                    path: .relativeToRoot("Supports/Extensions")
                ),
                .project(
                    target: "Common3rdParty",
                    path: .relativeToRoot("Supports/Common3rdParty")
                ),
                .project(
                    target: "Domain",
                    path: .relativeToRoot("Domain")
                ),
                .project(
                    target: "Repository",
                    path: .relativeToRoot("Repository")
                ),
                .project(
                    target: "CommonPresentation",
                    path: .relativeToRoot("Presentations/CommonPresentation")
                ),
                .project(
                    target: "CalendarScenes",
                    path: .relativeToRoot("Presentations/CalendarScenes")
                )
            ],
            signingConfigures: [
                .debug(
                    name: "Debug",
                    settings: Project.debugWidgetSigningSetting
                ),
                .release(
                    name: "Release",
                    settings: Project.releaseWidgetSigningSetting
                )
            ]
        )
    + Project.makeAppExtensionTargets(
        appName: "TodoCalendarApp",
        extensionName: "IntentExtensions",
        destinations: [.iPhone],
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
            ]),
            "CFBundleDisplayName": "To-do Calendar intent extension",
            "CFBundleShortVersionString": "\(Project.appVersion)",
            "CFBundleVersion": "\(Project.buildNumber)"
        ],
        dependencies: [
            .project(
                target: "Extensions",
                path: .relativeToRoot("Supports/Extensions")
            ),
            .project(
                target: "Common3rdParty",
                path: .relativeToRoot("Supports/Common3rdParty")
            ),
            .project(
                target: "Domain",
                path: .relativeToRoot("Domain")
            ),
            .project(
                target: "Repository",
                path: .relativeToRoot("Repository")
            ),
        ],
        signingConfigures: [
            .debug(
                name: "Debug",
                settings: Project.debugAppIntentSigningSetting
            ),
            .release(
                name: "Release",
                settings: Project.releaseAppIntentSigningSetting
            )
        ],
        withTest: false
    )
    + Project.makeAppExtensionTargets(
        appName: "TodoCalendarApp",
        extensionName: "Share",
        destinations: [.iPhone],
        iOSTargetVersion: "17.0",
        infoPlist: [
            "NSExtension": .dictionary([
                "NSExtensionAttributes": .dictionary([
                    "NSExtensionActivationRule": .dictionary([
                        "NSExtensionActivationSupportsText": .boolean(true),
                        "NSExtensionActivationSupportsWebURLWithMaxCount": .integer(1)
                    ])
                ]),
                "NSExtensionPointIdentifier": .string("com.apple.share-services"),
                "NSExtensionPrincipalClass": .string("$(PRODUCT_MODULE_NAME).ShareViewController")
            ]),
            "CFBundleDisplayName": "To-do Calendar",
            "CFBundleShortVersionString": "\(Project.appVersion)",
            "CFBundleVersion": "\(Project.buildNumber)"
        ],
        dependencies: [
            .project(
                target: "Extensions",
                path: .relativeToRoot("Supports/Extensions")
            ),
            .project(
                target: "Common3rdParty",
                path: .relativeToRoot("Supports/Common3rdParty")
            ),
            .project(
                target: "Domain",
                path: .relativeToRoot("Domain")
            ),
            .project(
                target: "Repository",
                path: .relativeToRoot("Repository")
            ),
            .project(
                target: "CommonPresentation",
                path: .relativeToRoot("Presentations/CommonPresentation")
            )
        ],
        signingConfigures: [
            .debug(
                name: "Debug",
                settings: Project.debugShareSigningSetting
            ),
            .release(
                name: "Release",
                settings: Project.releaseShareSigningSetting
            )
        ],
        withTest: true,
        snapshotTests: true
    ),
    schemes: [
        .scheme(
            name: "TodoCalendarApp-StoreKit",
            shared: true,
            buildAction: .buildAction(targets: ["TodoCalendarApp"]),
            runAction: .runAction(
                executable: .executable(.target("TodoCalendarApp")),
                options: .options(
                    storeKitConfigurationPath: .relativeToRoot("TodoCalendarApp/Resources/Billing.storekit")
                )
            )
        )
    ]
)
