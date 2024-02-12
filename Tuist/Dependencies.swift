//
//  Dependencies.swift
//  TodoCalendarAppManifests
//
//  Created by 강준영 on 2023/12/16.
//

import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager:
        SwiftPackageManagerDependencies(
            [
                .remote(url: "https://github.com/Alamofire/Alamofire.git",
                        requirement: .upToNextMajor(from: "5.7.1")),
                .remote(url: "https://github.com/onevcat/Kingfisher.git",
                        requirement: .upToNextMajor(from: "7.10.0")),
                .remote(url: "https://github.com/pointfreeco/swift-prelude.git", 
                        requirement: .branch("main")),
                .remote(url: "https://github.com/apple/swift-async-algorithms.git",
                        requirement: .upToNextMajor(from: "0.1.0")),
                .remote(url: "https://github.com/sudopark/publisher-async-bind.git", 
                        requirement: .upToNextMajor(from: "0.0.2")),
                .remote(url: "https://github.com/sudopark/SQLiteService.git",
                        requirement:  .upToNextMajor(from:"0.2.0")),
                .remote(url: "https://github.com/CombineCommunity/CombineCocoa.git", 
                        requirement: .upToNextMajor(from: "0.4.1")),
                .remote(url: "https://github.com/kean/Pulse",
                        requirement: .upToNextMajor(from: "4.0.3")),
                .remote(url: "https://github.com/google/GoogleSignIn-iOS", requirement: .upToNextMajor(from: "7.0.0"))
            ],
            productTypes: [ // 다이나믹 프레임워크로
                "Alamofire": .framework,
                "Kingfisher": .framework,
                "swift-prelude": .framework,
                "Pulse": .framework,
                "CombineCocoa": .framework,
                "AsyncAlgorithms": .framework,
                "publisher-async-bind": .framework,
                "SQLiteService": .framework,
                "GoogleSignIn": .framework
            ]
        ),
    platforms: [.iOS]
)
