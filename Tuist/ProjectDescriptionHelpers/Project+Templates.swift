import ProjectDescription

/// Project helpers are functions that simplify the way you define your project.
/// Share code to create targets, settings, dependencies,
/// Create your own conventions, e.g: a func that makes sure all shared targets are "static frameworks"
/// See https://docs.tuist.io/guides/helpers/

extension Project {
    static let organizationName = "com.sudo.park"

    /// Helper function to create the Project for this ExampleApp
    public static func app(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        dependencies: [TargetDependency] = [],
        extensionTargets: [Target] = [],
        schemes: [Scheme] = []
    ) -> Project {
        let targets = makeAppTargets(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            dependencies: dependencies,
            signingConfigures: [
                .debug(
                    name: "Debug",
                    settings: debugAppSigningSetting
                ),
                .release(
                    name: "Release",
                    settings: releaseAppSigningSetting
                )
            ]
        )
        return Project(
            name: name,
            organizationName: organizationName,
            options: .options(
                disableBundleAccessors: true,
                disableSynthesizedResourceAccessors: true
            ),
            targets: targets + extensionTargets,
            schemes: schemes
        )
    }

    public static func frameworkWithTest(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        snapshotTests: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Project {
        var targets = makeFrameworkTargetsWithTest(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            resources: resources,
            dependencies: dependencies
        )
        if snapshotTests {
            targets.append(
                makeSnapshotsTarget(
                    name: name,
                    destinations: destinations,
                    iOSTargetVersion: iOSTargetVersion
                )
            )
        }
        return Project(
            name: name,
            organizationName: organizationName,
            targets: targets
        )
    }

    public static func framework(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        withSourceFile: Bool = true,
        snapshotTests: Bool = false,
        dependencies: [TargetDependency] = [],
        customSetting: [String: SettingValue] = [:]
    ) -> Project {
        var targets = makeFrameworkTargets(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            withSourceFile: withSourceFile,
            dependencies: dependencies,
            customSetting: customSetting
        )
        if snapshotTests {
            targets.append(
                makeSnapshotsTarget(
                    name: name,
                    destinations: destinations,
                    iOSTargetVersion: iOSTargetVersion
                )
            )
        }
        return Project(name: name,
                       organizationName: organizationName,
                       targets: targets)
    }

    // MARK: - Private

    private static func makeSnapshotsTarget(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String
    ) -> Target {
        return Target.target(name: "\(name)Snapshots",
                             destinations: destinations,
                             product: .unitTests,
                             bundleId: "\(organizationName).\(name)Snapshots",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: ["Snapshots/**"],
                             resources: [],
                             dependencies: [
                                .target(name: name),
                                .project(target: "SnapshotTestHelpKit", path: .relativeToCurrentFile("../../Supports/SnapshotTestHelpKit")),
                                .project(target: "TestDoubles", path: .relativeToCurrentFile("../../Supports/TestDoubles")),
                             ])
    }

    /// Helper function to create a framework target and an associated unit test target
    private static func makeFrameworkTargetsWithTest(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    )
    -> [Target]
    {
        let sources = Target.target(name: name,
                             destinations: destinations,
                             product: .staticFramework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: ["Sources/**"],
                             resources: resources,
                             headers: Headers.headers(public: "\(name).h"),
                             dependencies: dependencies,
                             settings: .settings(
                                base: .init().swiftVersion("6.0"),
                                configurations: []
                             )
        )
        let tests = Target.target(name: "\(name)Tests",
                           destinations: destinations,
                           product: .unitTests,
                           bundleId: "\(organizationName).\(name)Tests",
                           deploymentTargets: .iOS(iOSTargetVersion),
                           infoPlist: .default,
                           sources: ["Tests/**"],
                           resources: [],
                           dependencies: [
                            .target(name: name),
                            .project(target: "UnitTestHelpKit", path: .relativeToCurrentFile("../../Supports/UnitTestHelpKit")),
                            .project(target: "TestDoubles", path: .relativeToCurrentFile("../../Supports/TestDoubles")),
                            .project(target: "Common3rdParty", path: .relativeToCurrentFile("../../Supports/Common3rdParty")),
                           ])
        return [sources, tests]
    }

    private static func makeFrameworkTargets(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        withSourceFile: Bool,
        dependencies: [TargetDependency] = [],
        customSetting: [String: SettingValue] = [:]
    )
    -> [Target]
    {
        let settingDict = customSetting.swiftVersion("6.0")
        let sources = Target.target(name: name,
                             destinations: destinations,
                             product: .staticFramework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: withSourceFile ? ["Sources/**"] : [],
                             resources: [],
                             headers: Headers.headers(public: "\(name).h"),
                             dependencies: dependencies,
                             settings: .settings(
                                base: settingDict,
                                configurations: []
                             )
        )
        return [sources]
    }

    /// Helper function to create the application target and the unit test target.
    private static func makeAppTargets(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        dependencies: [TargetDependency],
        signingConfigures: [ProjectDescription.Configuration]
    )
    -> [Target]
    {
        let mainTarget = Target.target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: "\(organizationName).\(name)",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .extendingDefault(with: [
                "UILaunchStoryboardName": "LaunchScreen",
                "ENABLE_TESTS": .boolean(true),
                "NSLocalNetworkUsageDescription": "Network usage required for debugging purposes",
                "NSBonjourServices": [
                    "_pulse._tcp"
                ],
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true
                ],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ],
                "GIDClientID": "\(googleClientId)",
                "CFBundleURLTypes": [
                    [
                        "CFBundleTypeRole": "Editor",
                        "CFBundleURLSchemes": [
                            "\(googleReverseAppId)"
                        ]
                    ],
                    [
                        "CFBundleURLName": "com.sudo.park.TodoCalendarApp",
                        "CFBundleURLSchemes": [
                            "tc.app"
                        ]
                    ]
                ],
                "LSApplicationQueriesSchemes": ["comgooglemaps"],
                "ITSAppUsesNonExemptEncryption": false,
                "CFBundleDisplayName": "To-do Calendar",
                "CFBundleShortVersionString": "\(self.appVersion)",
                "CFBundleVersion": "\(self.buildNumber)",
                "BGTaskSchedulerPermittedIdentifiers": [
                    "com.sudo.park.TodoCalendarApp.bgSync"
                ],
                "UIBackgroundModes": ["fetch"],
                "NSCalendarsFullAccessUsageDescription": "Calendar access is required to display events and sync with Apple Calendar.",
                "NSMicrophoneUsageDescription": "Microphone access is required to enter events and to-dos by voice.",
                "NSSpeechRecognitionUsageDescription": "Speech recognition is required to convert your voice into events and to-dos."
            ]),
            sources: [
                "Sources/**",
                .glob("Intents/TodoCalendarWidgetIntents.intentdefinition", codeGen: .public)
            ],
            resources: ["Resources/**"],
            entitlements: Entitlements.file(path: "./TodoCalendarApp.entitlements"),
            dependencies: dependencies,
            settings: .settings(
                base: .init()
                    .swiftVersion("6.0")
                    .otherLinkerFlags(["-ObjC"]),
                configurations: signingConfigures + [

                ]
            )
        )

        let testTarget = Target.target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(organizationName).\(name)",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .default,
            sources: ["\(name)Tests/**"],
            dependencies: [
                .target(name: "\(name)"),
                .project(target: "UnitTestHelpKit", path:
                        .relativeToCurrentFile("../../Supports/UnitTestHelpKit")),
                .project(target: "TestDoubles", path: .relativeToCurrentFile("../../Supports/TestDoubles")),
                .project(target: "Common3rdParty", path: .relativeToCurrentFile("../../Supports/Common3rdParty")),
            ])
        return [mainTarget, testTarget]
    }

    public static func makeAppExtensionTargets(
        appName: String,
        extensionName: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        infoPlist: [String: Plist.Value] = [:],
        dependencies: [TargetDependency],
        signingConfigures: [ProjectDescription.Configuration],
        withTest: Bool = true
    ) -> [Target] {

        let targetName = "\(appName)\(extensionName)"

        let target = Target.target(
            name: targetName,
            destinations: destinations,
            product: .appExtension,
            bundleId: "\(organizationName).\(appName).\(extensionName)",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .extendingDefault(with: infoPlist),
            sources: [
                "AppExtensions/Base/**",
                "AppExtensions/\(extensionName)/Sources/**",
                "Sources/AppEnvironment.swift",
                .glob("Intents/TodoCalendarWidgetIntents.intentdefinition", codeGen: .public)
            ],
            resources: [
                "AppExtensions/\(extensionName)/Resources/**",
                "Resources/secrets.json",
                "Resources/GoogleService-Info.plist"
            ],
            entitlements: Entitlements.file(path: "./AppExtensions/\(extensionName)/\(targetName).entitlements"),
            dependencies: dependencies,
            settings: .settings(
                base: .init()
                    .swiftVersion("6.0")
                    .otherLinkerFlags(["-ObjC"]),
                configurations: signingConfigures + [

                ]
            )
        )

        guard withTest else { return [target] }

        let testTarget = Target.target(
            name: "\(targetName)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(organizationName).\(appName).\(extensionName)Tests",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .default,
            sources: [
                "AppExtensions/Base/**",
                "AppExtensions/\(extensionName)/Sources/**",
                "Sources/AppEnvironment.swift",
                .glob("Intents/TodoCalendarWidgetIntents.intentdefinition", codeGen: .public),
                "AppExtensions/\(extensionName)/Tests/**"
            ],
            dependencies: [
                .target(name: appName),
                .project(
                    target: "UnitTestHelpKit",
                    path: .relativeToCurrentFile("../../Supports/UnitTestHelpKit")
                ),
                .project(
                    target: "TestDoubles",
                    path: .relativeToCurrentFile("../../Supports/TestDoubles")
                ),
                .project(
                    target: "Common3rdParty",
                    path: .relativeToCurrentFile("../../Supports/Common3rdParty")
                )
            ]
        )

        return [target, testTarget]
    }
}
