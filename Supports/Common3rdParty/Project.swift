import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "Common3rdParty",
    destinations: [.iPhone],
    iOSTargetVersion: "15.0",
    withSourceFile: false,
    dependencies: [
        .external(name: "Alamofire"),
        .external(name: "Prelude"),
        .external(name: "AsyncAlgorithms"),
        .external(name: "AsyncFlatMap"),
        .external(name: "SQLiteService"),
        .external(name: "CombineCocoa"),
        .external(name: "Pulse"),
        .external(name: "PulseUI"),
        .external(name: "Optics"),
        .external(name: "FirebaseAuth"),
        .external(name: "FirebaseCrashlytics"),
        .external(name: "FirebaseAnalytics"),
        .external(name: "FirebaseMessaging"),
        .external(name: "GoogleSignIn"),
        .external(name: "GoogleSignInSwift"),
        .external(name: "KeychainSwift"),
        .external(name: "CombineExt"),
        .external(name: "SwiftLinkPreview")
    ],
    customSetting: .init().otherLinkerFlags(["-ObjC"])
)
