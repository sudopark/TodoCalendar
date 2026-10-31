import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.app(
    name: "TodoCalendarApp",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(target: "AIAgentSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/AIAgentSceneInterface")),
        .project(target: "AIDomain", path: .relativeToRoot("Domain/AIDomain")),
        .project(target: "AIDomainInterface", path: .relativeToRoot("Domain/AIDomain")),
        .project(target: "AccountDomain", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "AdDomain", path: .relativeToRoot("Domain/AdDomain")),
        .project(target: "AdDomainInterface", path: .relativeToRoot("Domain/AdDomain")),
        .project(target: "BillingDomain", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "BillingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/BillingSceneInterface")),
        .project(target: "CalendarDomain", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "CalendarSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/CalendarSceneInterface")),
        .project(target: "DBInfra", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
        .project(target: "EventDetailSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventDetailSceneInterface")),
        .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "EventListSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/EventListSceneInterface")),
        .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
        .project(target: "MemberSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/MemberSceneInterface")),
        .project(target: "MigrationDomain", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "MigrationDomainInterface", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "NotificationDomain", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "NotificationDomainInterface", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "RemoteInfra", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
        .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
        .project(target: "SettingDomain", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "SettingSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/SettingSceneInterface")),
        .project(target: "StorageInfra", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "SupportDomain", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "WidgetGallerySceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/WidgetGallerySceneInterface")),
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
            target: "CalendarPresentation",
            path: .relativeToRoot("Presentations/CalendarPresentation")
        ),
        .project(
            target: "Common3rdParty",
            path: .relativeToRoot("Supports/Common3rdParty")
        ),
        .external(name: "FacebookCore"),
        .project(
            target: "CommonPresentation",
            path: .relativeToRoot("Presentations/CommonPresentation")
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
            target: "SettingScene",
            path: .relativeToRoot("Presentations/SettingScene")
        ),
        .project(
            target: "MemberScenes",
            path: .relativeToRoot("Presentations/MemberScenes")
        ),
        .project(
            target: "WidgetScenes",
            path: .relativeToRoot("Presentations/WidgetScenes")
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
        ),
        .project(
            target: "AdService",
            path: .relativeToRoot("Services/AdService")
        )
      ],
    testDependencies: [
        .project(target: "AIDomainTesting", path: .relativeToRoot("Domain/AIDomain")),
        .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
        .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
        .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
        .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
        .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
        .project(target: "MigrationDomainTesting", path: .relativeToRoot("Domain/MigrationDomain")),
        .project(target: "NotificationDomainTesting", path: .relativeToRoot("Domain/NotificationDomain")),
        .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
        .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
        .project(target: "StorageInfraTesting", path: .relativeToRoot("Repository/Infra/StorageInfra")),
        .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain")),
        .project(target: "TestDoubles", path: .relativeToRoot("Supports/TestDoubles"))
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
                .project(target: "AccountDomain", path: .relativeToRoot("Domain/AccountDomain")),
                .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
                .project(target: "AuthService", path: .relativeToRoot("Services/AuthService")),
                .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
                .project(target: "CalendarDomain", path: .relativeToRoot("Domain/CalendarDomain")),
                .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
                .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
                .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
                .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
                .project(target: "PlaceServiceInterface", path: .relativeToRoot("Domain/PlaceServiceInterface")),
                .project(target: "RemoteInfra", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
                .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
                .project(target: "SettingDomain", path: .relativeToRoot("Domain/SettingDomain")),
                .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
                .project(target: "StorageInfra", path: .relativeToRoot("Repository/Infra/StorageInfra")),
                .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
                .project(
                    target: "Extensions",
                    path: .relativeToRoot("Supports/Extensions")
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
                    target: "CalendarPresentation",
                    path: .relativeToRoot("Presentations/CalendarPresentation")
                ),
                .project(
                    target: "WidgetScenes",
                    path: .relativeToRoot("Presentations/WidgetScenes")
                )
            ],
            testDependencies: [
                .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
                .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
                .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
                .project(target: "ExternalCalendarDomainTesting", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
                .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain"))
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
            ],
            snapshotTests: true
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
            .project(target: "AccountDomain", path: .relativeToRoot("Domain/AccountDomain")),
            .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
            .project(target: "AuthService", path: .relativeToRoot("Services/AuthService")),
            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
            .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
            .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
            .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
            .project(target: "RemoteInfra", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
            .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
            .project(target: "StorageInfra", path: .relativeToRoot("Repository/Infra/StorageInfra")),
            .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
            .project(
                target: "Extensions",
                path: .relativeToRoot("Supports/Extensions")
            ),
            .project(
                target: "Common3rdParty",
                path: .relativeToRoot("Supports/Common3rdParty")
            )
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
                        "NSExtensionActivationSupportsWebURLWithMaxCount": .integer(1),
                        "NSExtensionActivationSupportsImageWithMaxCount": .integer(1)
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
            .project(target: "AIDomain", path: .relativeToRoot("Domain/AIDomain")),
            .project(target: "AIDomainInterface", path: .relativeToRoot("Domain/AIDomain")),
            .project(target: "AccountDomain", path: .relativeToRoot("Domain/AccountDomain")),
            .project(target: "AccountDomainInterface", path: .relativeToRoot("Domain/AccountDomain")),
            .project(target: "AuthService", path: .relativeToRoot("Services/AuthService")),
            .project(target: "BillingDomain", path: .relativeToRoot("Domain/BillingDomain")),
            .project(target: "BillingDomainInterface", path: .relativeToRoot("Domain/BillingDomain")),
            .project(target: "DBInfraInterface", path: .relativeToRoot("Repository/Infra/DBInfra")),
            .project(target: "EventDomain", path: .relativeToRoot("Domain/EventDomain")),
            .project(target: "EventDomainInterface", path: .relativeToRoot("Domain/EventDomain")),
            .project(target: "ExternalCalendarDomain", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
            .project(target: "ExternalCalendarDomainInterface", path: .relativeToRoot("Domain/ExternalCalendarDomain")),
            .project(target: "KernelUtils", path: .relativeToRoot("Domain/KernelUtils")),
            .project(target: "RemoteInfra", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
            .project(target: "RemoteInfraInterface", path: .relativeToRoot("Repository/Infra/RemoteInfra")),
            .project(target: "SettingDomain", path: .relativeToRoot("Domain/SettingDomain")),
            .project(target: "StorageInfra", path: .relativeToRoot("Repository/Infra/StorageInfra")),
            .project(target: "StorageInfraInterface", path: .relativeToRoot("Repository/Infra/StorageInfra")),
            .project(target: "SupportDomainInterface", path: .relativeToRoot("Domain/SupportDomain")),
            .project(
                target: "Extensions",
                path: .relativeToRoot("Supports/Extensions")
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
                target: "FirstPartyServices",
                path: .relativeToRoot("Services/FirstPartyServices")
            )
        ],
        testDependencies: [
            .project(target: "AIDomainTesting", path: .relativeToRoot("Domain/AIDomain")),
            .project(target: "AccountDomainTesting", path: .relativeToRoot("Domain/AccountDomain")),
            .project(target: "BillingDomainTesting", path: .relativeToRoot("Domain/BillingDomain")),
            .project(target: "EventDomainTesting", path: .relativeToRoot("Domain/EventDomain")),
            .project(target: "SettingDomainInterface", path: .relativeToRoot("Domain/SettingDomain")),
            .project(target: "SettingDomainTesting", path: .relativeToRoot("Domain/SettingDomain")),
            .project(target: "SupportDomainTesting", path: .relativeToRoot("Domain/SupportDomain"))
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
    ],
    e2eTests: true
)
