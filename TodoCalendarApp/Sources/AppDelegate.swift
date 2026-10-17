//
//  AppDelegate.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Domain
import Extensions
import FirebaseCore
import FirebaseMessaging
import UserNotifications


@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var applicationViewModel: ApplicationRootViewModelImple!
    weak var applicationRouter: ApplicationRootRouter?
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        #if DEBUG || TEST_DEPLOY
        logger.prepare()
        #endif
        
        self.syncE2ERunMarker()
        self.resetStateForUITestRunIfNeeded()
        
        if AppEnvironment.isExternalDependencyBlocked == false {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            UNUserNotificationCenter.current().delegate = self
            application.registerForRemoteNotifications()
        }

        let builder = ApplicationRootBuilder()
        self.applicationViewModel = builder.makeRootViewModel()
        self.applicationRouter = self.applicationViewModel.router
        self.applicationViewModel.registerBackgroundTask()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}


// MARK: - reset state for ui test

extension AppDelegate {
    
    // 잔존 마커를 걷는 것이 아래 격리 축 판정보다 앞이어야 지난 실행이 이번 실행을 오염시키지 않는다
    fileprivate func syncE2ERunMarker() {
#if DEBUG
        guard AppEnvironment.isUITestRun else {
            // 일반 실행이 잔존 마커를 걷는다 — 만료 시각과 함께 fail-safe 를 이룬다
            AppEnvironment.removeE2ERunMarker()
            return
        }
        guard let host = AppEnvironment.e2eLaunchAPIHost else { return }
        AppEnvironment.writeE2ERunMarker(host: host)
#endif
    }
    
    // ApplicationBase 가 UserDefaults 를 읽어 잡으므로 루트 조립보다 앞이어야 한다
    fileprivate func resetStateForUITestRunIfNeeded() {
        guard AppEnvironment.isUITestRun else { return }
        
        let testDBFilePath = AppEnvironment.dbFilePath(for: nil)
        guard testDBFilePath.isEmpty == false else { return }
        
        let testDBFileURL = URL(fileURLWithPath: testDBFilePath)
        let namePrefix = testDBFileURL.deletingPathExtension().lastPathComponent
        let containerURL = testDBFileURL.deletingLastPathComponent()
        
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(
            at: containerURL, includingPropertiesForKeys: nil
        )) ?? []
        files
            .filter { $0.lastPathComponent.hasPrefix(namePrefix) }
            .forEach { try? manager.removeItem(at: $0) }
        
        let suiteName = AppEnvironment.userDefaultSuiteName
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}


// MARK: - handle open url

extension AppDelegate {
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        
        return self.applicationViewModel.handle(open: url)
    }
}


// MARK: - handle notification

extension AppDelegate: @MainActor UNUserNotificationCenterDelegate, @MainActor MessagingDelegate {
    
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        self.applicationViewModel.handleReceiveFcmToken(fcmToken)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        self.applicationViewModel.handleReceivePushNotification(
            userInfo: notification.request.content.userInfo
        )
        return [.banner]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        self.applicationViewModel.handleReceivePushNotification(
            userInfo: response.notification.request.content.userInfo
        )
    }
}
