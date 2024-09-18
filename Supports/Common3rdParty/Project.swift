import ProjectDescriptionHelpers
import ProjectDescription

let project = Project.framework(
    name: "Common3rdParty",
    packages: [
        .remote(
            url: "https://github.com/Alamofire/Alamofire.git", requirement: .upToNextMajor(from: "5.9.1")
        ),
        .remote(
            url: "https://github.com/pointfreeco/swift-prelude.git", requirement: .branch("main")
        ),
        .remote(
            url: "https://github.com/apple/swift-async-algorithms.git", requirement: .upToNextMajor(from: "0.1.0")
        ),
        .remote(
            url: "https://github.com/sudopark/publisher-async-bind.git", requirement: .upToNextMajor(from: "0.0.2")
        ),
        .remote(
            url: "https://github.com/sudopark/SQLiteService.git", requirement:  .upToNextMajor(from:"0.2.0")
        ),
        .remote(
            url: "https://github.com/CombineCommunity/CombineCocoa.git", requirement: .upToNextMajor(from: "0.4.1")
        ),
        .remote(
            url: "https://github.com/kean/Pulse", requirement: .upToNextMajor(from: "4.1.0")
        ),
        .remote(
            url: "https://github.com/google/GoogleSignIn-iOS", requirement: .upToNextMajor(from: "7.1.0")
        ),
        .remote(
            url: "https://github.com/firebase/firebase-ios-sdk", requirement: .upToNextMajor(from: "11.1.0")
        ),
        .remote(
            url: "https://github.com/evgenyneu/keychain-swift.git", requirement: .upToNextMajor(from: "24.0.0")
        ),
        .remote(
            url: "https://github.com/CombineCommunity/CombineExt.git", requirement: .upToNextMajor(from: "1.8.1")
        ),
        .remote(
            url: "https://github.com/LeonardoCardoso/SwiftLinkPreview.git", requirement: .upToNextMajor(from: "3.4.0")
        )
    ],
    platform: .iOS,
    iOSTargetVersion: "15.0",
    withSourceFile: false,
    dependencies: [
        .package(product: "Alamofire"),
        .package(product: "Prelude"),
        .package(product: "AsyncAlgorithms"),
        .package(product: "AsyncFlatMap"),
        .package(product: "SQLiteService"),
        .package(product: "CombineCocoa"),
        .package(product: "Pulse"),
        .package(product: "PulseUI"),
        .package(product: "Optics"),
        .package(product: "FirebaseAuth"),
        .package(product: "FirebaseCrashlytics"),
        .package(product: "GoogleSignIn"),
        .package(product: "GoogleSignInSwift"),
        .package(product: "KeychainSwift"),
        .package(product: "CombineExt"),
        .package(product: "SwiftLinkPreview")
    ]
)
