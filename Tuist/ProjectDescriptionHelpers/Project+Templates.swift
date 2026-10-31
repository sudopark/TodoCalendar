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
        testDependencies: [TargetDependency] = [],
        extensionTargets: [Target] = [],
        schemes: [Scheme] = [],
        e2eTests: Bool = false
    ) -> Project {
        var targets = makeAppTargets(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            dependencies: dependencies,
            testDependencies: testDependencies,
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
        if e2eTests {
            targets.append(
                makeE2ETarget(
                    name: name,
                    destinations: destinations,
                    iOSTargetVersion: iOSTargetVersion
                )
            )
        }
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
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = []
    ) -> Project {
        var targets = makeFrameworkTargetsWithTest(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            resources: resources,
            dependencies: dependencies,
            testDependencies: testDependencies
        )
        if snapshotTests {
            targets.append(
                makeSnapshotsTarget(
                    name: name,
                    destinations: destinations,
                    iOSTargetVersion: iOSTargetVersion,
                    dependencies: testDependencies
                )
            )
        }
        return Project(
            name: name,
            organizationName: organizationName,
            targets: targets
        )
    }

    public static func frameworkWithInterfaceAndTesting(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        interfaceDependencies: [TargetDependency] = [],
        dependencies: [TargetDependency] = [],
        testingDependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = []
    ) -> Project {
        let interfaceName = "\(name)Interface"
        let testingName = "\(name)Testing"
        let frameworkTargets = [
            makeStaticFrameworkTarget(
                name: interfaceName,
                destinations: destinations,
                iOSTargetVersion: iOSTargetVersion,
                sourceDirectory: "Interface",
                dependencies: interfaceDependencies
            ),
            makeStaticFrameworkTarget(
                name: name,
                destinations: destinations,
                iOSTargetVersion: iOSTargetVersion,
                sourceDirectory: "Sources",
                resources: resources,
                dependencies: [.target(name: interfaceName)] + dependencies
            ),
            makeStaticFrameworkTarget(
                name: testingName,
                destinations: destinations,
                iOSTargetVersion: iOSTargetVersion,
                sourceDirectory: "Testing",
                dependencies: [.target(name: interfaceName)] + testingDependencies
            )
        ]
        let testTarget = makeUnitTestsTarget(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            testedTargets: [interfaceName, name, testingName],
            testDependencies: testDependencies
        )
        return Project(
            name: name,
            organizationName: organizationName,
            targets: frameworkTargets + [testTarget]
        )
    }

    public static func framework(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        withSourceFile: Bool = true,
        resources: ResourceFileElements? = nil,
        snapshotTests: Bool = false,
        dependencies: [TargetDependency] = [],
        customSetting: [String: SettingValue] = [:]
    ) -> Project {
        var targets = makeFrameworkTargets(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            withSourceFile: withSourceFile,
            resources: resources,
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
        iOSTargetVersion: String,
        dependencies: [TargetDependency] = []
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
                                .project(target: "SnapshotTestHelpKit", path: .relativeToRoot("Supports/SnapshotTestHelpKit")),
                             ] + dependencies)
    }

    private static func makeE2ETarget(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String
    ) -> Target {
        return Target.target(name: "\(name)E2E",
                             destinations: destinations,
                             product: .uiTests,
                             bundleId: "\(organizationName).\(name)E2E",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: ["E2E/**"],
                             resources: ["E2E/Fixtures/**/*.json"],
                             dependencies: [
                                .target(name: name),
                                .project(target: "SceneInfra", path: .relativeToRoot("Presentations/Scenes/SceneInfra")),
                                .project(target: "CalendarSceneInterface", path: .relativeToRoot("Presentations/Scenes/Interfaces/CalendarSceneInterface")),
                                .project(target: "CalendarDomainInterface", path: .relativeToRoot("Domain/CalendarDomain")),
                                .project(target: "CalendarDomainTesting", path: .relativeToRoot("Domain/CalendarDomain")),
                             ])
    }

    /// Helper function to create a framework target and an associated unit test target
    private static func makeFrameworkTargetsWithTest(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = []
    )
    -> [Target]
    {
        let sources = makeStaticFrameworkTarget(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            sourceDirectory: "Sources",
            resources: resources,
            dependencies: dependencies
        )
        let tests = makeUnitTestsTarget(
            name: name,
            destinations: destinations,
            iOSTargetVersion: iOSTargetVersion,
            testedTargets: [name],
            testDependencies: testDependencies
        )
        return [sources, tests]
    }

    private static func makeStaticFrameworkTarget(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        sourceDirectory: String,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency]
    ) -> Target {
        return Target.target(name: name,
                             destinations: destinations,
                             product: .staticFramework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: ["\(sourceDirectory)/**"],
                             resources: resources,
                             headers: Headers.headers(public: "\(name).h"),
                             dependencies: dependencies,
                             settings: .settings(
                                base: .init().swiftVersion("6.0"),
                                configurations: []
                             )
        )
    }

    private static func makeUnitTestsTarget(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        testedTargets: [String],
        testDependencies: [TargetDependency] = []
    ) -> Target {
        return Target.target(name: "\(name)Tests",
                             destinations: destinations,
                             product: .unitTests,
                             bundleId: "\(organizationName).\(name)Tests",
                             deploymentTargets: .iOS(iOSTargetVersion),
                             infoPlist: .default,
                             sources: ["Tests/**"],
                             resources: [],
                             dependencies: testedTargets.map { .target(name: $0) } + [
                                .project(target: "UnitTestHelpKit", path: .relativeToRoot("Supports/UnitTestHelpKit")),
                                .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
                             ] + testDependencies)
    }

    private static func makeFrameworkTargets(
        name: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        withSourceFile: Bool,
        resources: ResourceFileElements? = nil,
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
                             resources: resources,
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
        testDependencies: [TargetDependency],
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
                "GADApplicationIdentifier": "\(admobAppId)",
                "FacebookAppID": "\(facebookAppId)",
                "FacebookClientToken": "\(facebookClientToken)",
                "FacebookDisplayName": "To-do Calendar",
                "NSUserTrackingUsageDescription": "Tracking permission is used to show you more relevant ads.",
                "SKAdNetworkItems": .array(
                    Project.skAdNetworkIdentifiers.map {
                        .dictionary(["SKAdNetworkIdentifier": .string($0)])
                    }
                ),
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
                "INAlternativeAppNames": .array([
                    .dictionary(["INAlternativeAppName": .string("Todo Calendar")]),
                    .dictionary(["INAlternativeAppName": .string("투두캘린더")])
                ]),
                "CFBundleShortVersionString": "\(self.appVersion)",
                "CFBundleVersion": "\(self.buildNumber)",
                "BGTaskSchedulerPermittedIdentifiers": [
                    "com.sudo.park.TodoCalendarApp.bgSync"
                ],
                "UIBackgroundModes": ["fetch"],
                "NSCalendarsFullAccessUsageDescription": "Calendar access is required to display events and sync with Apple Calendar.",
                "NSMicrophoneUsageDescription": "Microphone access is required to enter events and to-dos by voice.",
                "NSSpeechRecognitionUsageDescription": "Speech recognition is required to convert your voice into events and to-dos.",
                "NSCameraUsageDescription": "Camera access is required to read text from a photo you take.",
                "NSPhotoLibraryAddUsageDescription": "Photo library access is required to save a shared event image to your photos.",
                "NSSupportsLiveActivities": true
            ]),
            sources: [
                "Sources/**",
                "AppExtensions/Base/**",
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
                        .relativeToRoot("Supports/UnitTestHelpKit")),
                .project(target: "Common3rdParty", path: .relativeToRoot("Supports/Common3rdParty")),
            ] + testDependencies)
        return [mainTarget, testTarget]
    }

    public static func makeAppExtensionTargets(
        appName: String,
        extensionName: String,
        destinations: Destinations,
        iOSTargetVersion: String,
        infoPlist: [String: Plist.Value] = [:],
        dependencies: [TargetDependency],
        testDependencies: [TargetDependency] = [],
        signingConfigures: [ProjectDescription.Configuration],
        withTest: Bool = true,
        snapshotTests: Bool = false
    ) -> [Target] {

        let targetName = "\(appName)\(extensionName)"

        // 확장 소스는 .appExtension product라 unit test가 host할 수 없다 —
        // 테스트·스냅샷 타겟 모두 본 타겟과 같은 소스를 다시 컴파일해서 참조한다.
        let extensionSources: [SourceFileGlob] = [
            "AppExtensions/Base/**",
            "AppExtensions/\(extensionName)/Sources/**",
            "Sources/AppEnvironment.swift",
            "Sources/DummyFirebaseAuthService.swift",
            "Sources/E2ERunMarker.swift",
            "Sources/NeverRemoveAuthStorage.swift",
            // 컨트롤이 참조하는 AppIntent — 앱을 열려면 앱·확장 양쪽 타겟에 속해야 한다 (Apple 문서 요구)
            "Sources/AppIntents/OpenAICommandInputIntent.swift",
            .glob("Intents/TodoCalendarWidgetIntents.intentdefinition", codeGen: .public),
            .glob("Sources/LiveActivity/**")
        ]

        let target = Target.target(
            name: targetName,
            destinations: destinations,
            product: .appExtension,
            bundleId: "\(organizationName).\(appName).\(extensionName)",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .extendingDefault(with: infoPlist),
            sources: .init(globs: extensionSources),
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

        let testTarget = Target.target(
            name: "\(targetName)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "\(organizationName).\(appName).\(extensionName)Tests",
            deploymentTargets: .iOS(iOSTargetVersion),
            infoPlist: .default,
            sources: .init(globs: extensionSources + ["AppExtensions/\(extensionName)/Tests/**"]),
            dependencies: [
                .target(name: appName),
                .project(
                    target: "UnitTestHelpKit",
                    path: .relativeToRoot("Supports/UnitTestHelpKit")
                ),
                .project(
                    target: "Common3rdParty",
                    path: .relativeToRoot("Supports/Common3rdParty")
                )
            ] + testDependencies
        )

        var targets: [Target] = [target]
        if withTest {
            targets.append(testTarget)
        }

        if snapshotTests {
            targets.append(
                Target.target(
                    name: "\(targetName)Snapshots",
                    destinations: destinations,
                    product: .unitTests,
                    bundleId: "\(organizationName).\(appName).\(extensionName)Snapshots",
                    deploymentTargets: .iOS(iOSTargetVersion),
                    infoPlist: .default,
                    sources: .init(globs: extensionSources + ["AppExtensions/\(extensionName)/Snapshots/**"]),
                    dependencies: [
                        .target(name: appName),
                        .project(
                            target: "SnapshotTestHelpKit",
                            path: .relativeToRoot("Supports/SnapshotTestHelpKit")
                        ),
                        .project(
                            target: "Common3rdParty",
                            path: .relativeToRoot("Supports/Common3rdParty")
                        )
                    ] + testDependencies
                )
            )
        }

        return targets
    }
}
