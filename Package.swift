// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "Alamofire": .framework,
        "Kingfisher": .framework,
        "Prelude": .framework,
        "Optics": .framework,
        "Pulse": .framework,
        "PulseUI": .framework,
        "CombineCocoa": .framework,
        "AsyncAlgorithms": .framework,
        "AsyncFlatMap": .framework,
        "SQLiteService": .framework,
        "Toaster": .framework,
        "FirebaseAuth": .framework,
        "FirebaseCrashlytics": .framework,
        "FirebaseAnalytics": .framework,
        "FirebaseMessaging": .framework,
        "GoogleSignIn": .framework,
        "GoogleSignInSwift": .framework,
        "KeychainSwift": .framework,
        "CombineExt": .framework,
        "SwiftLinkPreview": .framework,
        // Firebase/Google 전이 의존성 — static 중복 링킹 방지
        "FBLPromises": .framework,
        "Promises": .framework,
        "GoogleDataTransport": .framework,
        "GTMSessionFetcherCore": .framework,
        "GTMAppAuth": .framework,
        "AppAuthCore": .framework,
        "GoogleUtilities-AppDelegateSwizzler": .framework,
        "GoogleUtilities-Environment": .framework,
        "GoogleUtilities-Logger": .framework,
        "GoogleUtilities-MethodSwizzler": .framework,
        "GoogleUtilities-NSData": .framework,
        "GoogleUtilities-Network": .framework,
        "GoogleUtilities-Reachability": .framework,
        "GoogleUtilities-UserDefaults": .framework,
    ]
)
#endif

let package = Package(
    name: "TodoCalendar",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.9.1"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-prelude.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
        .package(url: "https://github.com/sudopark/publisher-async-bind.git", from: "0.0.2"),
        .package(url: "https://github.com/sudopark/SQLiteService.git", from: "0.3.2"),
        .package(url: "https://github.com/CombineCommunity/CombineCocoa.git", from: "0.4.1"),
        .package(url: "https://github.com/kean/Pulse", from: "4.1.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.1.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.1.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "24.0.0"),
        .package(url: "https://github.com/CombineCommunity/CombineExt.git", from: "1.8.1"),
        .package(url: "https://github.com/LeonardoCardoso/SwiftLinkPreview.git", from: "3.4.0"),
        .package(url: "https://github.com/devxoul/Toaster.git", branch: "master"),
    ]
)
