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
        platform: Platform,
        iOSTargetVersion: String,
        dependencies: [TargetDependency] = [],
        extensionTargets: [Target] = []
    ) -> Project {
        let targets = makeAppTargets(
            name: name,
            platform: platform,
            iOSTargetVersion: iOSTargetVersion,
            dependencies: dependencies
        )
        return Project(
            name: name,
            organizationName: organizationName,
            options: .options(
                disableBundleAccessors: true,
                disableSynthesizedResourceAccessors: true
            ),
            targets: targets + extensionTargets
        )
    }
    
    public static func frameworkWithTest(
        name: String,
        packages: [Package] = [],
        platform: Platform,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    ) -> Project {
        let targets = makeFrameworkTargetsWithTest(
            name: name,
            platform: platform,
            iOSTargetVersion: iOSTargetVersion,
            resources: resources,
            dependencies: dependencies
        )
        return Project(
            name: name,
            organizationName: organizationName,
            packages: packages,
            targets: targets
        )
    }
    
    public static func framework(name: String,
                                 packages: [Package] = [],
                                 platform: Platform,
                                 iOSTargetVersion: String,
                                 withSourceFile: Bool = true,
                                 dependencies: [TargetDependency] = []) -> Project {
        let targets = makeFrameworkTargets(name: name,
                                           platform: platform,
                                           iOSTargetVersion: iOSTargetVersion,
                                           withSourceFile: withSourceFile,
                                           dependencies: dependencies)
        return Project(name: name,
                       organizationName: organizationName,
                       packages: packages,
                       targets: targets)
    }
    
    // MARK: - Private
    
    /// Helper function to create a framework target and an associated unit test target
    private static func makeFrameworkTargetsWithTest(
        name: String,
        platform: Platform,
        iOSTargetVersion: String,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    )
    -> [Target]
    {
        let sources = Target(name: name,
                             platform: platform,
                             product: .framework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
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
        let tests = Target(name: "\(name)Tests",
                           platform: platform,
                           product: .unitTests,
                           bundleId: "\(organizationName).\(name)Tests",
                           deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
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
    
    private static func makeFrameworkTargets(name: String,
                                             platform: Platform,
                                             iOSTargetVersion: String,
                                             withSourceFile: Bool,
                                             dependencies: [TargetDependency] = [])
    -> [Target]
    {
        let sources = Target(name: name,
                             platform: platform,
                             product: .framework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
                             infoPlist: .default,
                             sources: withSourceFile ? ["Sources/**"] : [],
                             resources: [],
                             headers: Headers.headers(public: "\(name).h"),
                             dependencies: dependencies,
                             settings: .settings(
                                base: .init().swiftVersion("6.0"),
                                configurations: []
                             )
        )
        return [sources]
    }
    
    /// Helper function to create the application target and the unit test target.
    private static func makeAppTargets(
        name: String,
        platform: Platform,
        iOSTargetVersion: String,
        dependencies: [TargetDependency]
    )
    -> [Target]
    {
        let platform: Platform = platform
        let mainTarget = Target(
            name: name,
            platform: platform,
            product: .app,
            bundleId: "\(organizationName).\(name)",
            deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
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
                    ]
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "CFBundleDisplayName": "To-do Calendar",
                "CFBundleShortVersionString": "1.1.1",
                "CFBundleVersion": "1"
            ]),
            sources: [
                "Sources/**",
                .glob("Intents/TodoCalendarWidgetIntents.intentdefinition", codeGen: .public)
            ],
            resources: ["Resources/**"],
            entitlements: Entitlements.file(path: "./TodoCalendarApp.entitlements"),
            dependencies: dependencies,
            settings: .settings(
               base: .init().swiftVersion("6.0"),
               configurations: []
            )
        )
        
        let testTarget = Target(
            name: "\(name)Tests",
            platform: platform,
            product: .unitTests,
            bundleId: "\(organizationName).\(name)",
            deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
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
        platform: Platform,
        iOSTargetVersion: String,
        infoPlist: [String: Plist.Value] = [:],
        dependencies: [TargetDependency],
        withTest: Bool = true
    ) -> [Target] {
        
        let targetName = "\(appName)\(extensionName)"
        
        let target = Target(
            name: targetName,
            platform: platform,
            product: .appExtension,
            bundleId: "\(organizationName).\(appName).\(extensionName)",
            deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
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
               base: .init().swiftVersion("6.0"),
               configurations: []
            )
        )
        
        guard withTest else { return [target] }
        
        let testTarget = Target(
            name: "\(targetName)Tests",
            platform: platform,
            product: .unitTests,
            bundleId: "\(organizationName).\(appName).\(extensionName)Tests",
            deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: [.iphone]),
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
