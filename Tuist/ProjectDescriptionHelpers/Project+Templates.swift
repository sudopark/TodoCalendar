import ProjectDescription

/// Project helpers are functions that simplify the way you define your project.
/// Share code to create targets, settings, dependencies,
/// Create your own conventions, e.g: a func that makes sure all shared targets are "static frameworks"
/// See https://docs.tuist.io/guides/helpers/

extension Project {
    static let organizationName = "com.sudo.park"
    
    /// Helper function to create the Project for this ExampleApp
    public static func app(name: String,
                           platform: Platform,
                           iOSTargetVersion: String,
                           dependencies: [TargetDependency] = []) -> Project {
        var targets = makeAppTargets(name: name,
                                     platform: platform,
                                     iOSTargetVersion: iOSTargetVersion ,
                                     dependencies: dependencies)
//        targets += additionalTargets.flatMap({ makeFrameworkTargets(name: $0, platform: platform,
//                                                                    iOSTargetVersion: iOSTargetVersion) })
        return Project(name: name,
                       organizationName: organizationName,
                       targets: targets)
    }
    
    public static func frameworkWithTest(name: String,
                                         platform: Platform,
                                         iOSTargetVersion: String,
                                         dependencies: [TargetDependency] = []) -> Project {
        let targets = makeFrameworkTargetsWithTest(name: name,
                                                   platform: platform,
                                                   iOSTargetVersion: iOSTargetVersion,
                                                   dependencies: dependencies)
        return Project(name: name,
                       organizationName: organizationName,
                       targets: targets)
    }
    
    public static func framework(name: String,
                                 platform: Platform,
                                 iOSTargetVersion: String,
                                 dependencies: [TargetDependency] = []) -> Project {
        let targets = makeFrameworkTargets(name: name,
                                           platform: platform, 
                                           iOSTargetVersion: iOSTargetVersion,
                                           dependencies: dependencies)
        return Project(name: name,
                       organizationName: organizationName,
                       targets: targets)
    }
    
    // MARK: - Private
    
    /// Helper function to create a framework target and an associated unit test target
    private static func makeFrameworkTargetsWithTest(name: String,
                                                     platform: Platform,
                                                     iOSTargetVersion: String,
                                                     dependencies: [TargetDependency] = [])
    -> [Target]
    {
        let sources = Target(name: name,
                             platform: platform,
                             product: .framework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
                             infoPlist: .default,
                             sources: ["Sources/**"],
                             resources: [],
                             dependencies: dependencies)
        let tests = Target(name: "\(name)Tests",
                           platform: platform,
                           product: .unitTests,
                           bundleId: "\(organizationName).\(name)Tests",
                           deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
                           infoPlist: .default,
                           sources: ["\(name)Tests/**"],
                           resources: [],
                           dependencies: [
                            .target(name: name),
                            .project(target: "UnitTestHelpKit", path: .relativeToCurrentFile("../../UnitTestHelpKit")),
                            .project(target: "TestDoubles", path: .relativeToCurrentFile("../../TestDoubles"))
                           ])
        return [sources, tests]
    }
    
    private static func makeFrameworkTargets(name: String,
                                             platform: Platform,
                                             iOSTargetVersion: String,
                                             dependencies: [TargetDependency] = [])
    -> [Target]
    {
        let sources = Target(name: name,
                             platform: platform,
                             product: .framework,
                             bundleId: "\(organizationName).\(name)",
                             deploymentTarget: .iOS(targetVersion: iOSTargetVersion, devices: .iphone),
                             infoPlist: .default,
                             sources: ["Sources/**"],
                             resources: [],
                             headers: Headers.headers(public: "\(name).h"),
                             dependencies: dependencies)
        return [sources]
    }
    
    /// Helper function to create the application target and the unit test target.
    private static func makeAppTargets(name: String, 
                                       platform: Platform,
                                       iOSTargetVersion: String,
                                       dependencies: [TargetDependency])
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
                "NSBonjourServices": "_pulse._tcp",
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
                ]
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: Entitlements.file(path: "./TodoCalendarApp.entitlements"),
            dependencies: dependencies
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
                        .relativeToCurrentFile("../../UnitTestHelpKit")),
                .project(target: "TestDoubles", path: .relativeToCurrentFile("../../TestDoubles"))
            ])
        return [mainTarget, testTarget]
    }
}
