//
//  AppDelegate.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Domain
import AdService
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
        
        #if DEBUG
        logger.prepare()
        #endif
        
        if AppEnvironment.isTestBuild == false {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            UNUserNotificationCenter.current().delegate = self
            application.registerForRemoteNotifications()

            self.startMobileAdService()
        }

        let builder = ApplicationRootBuilder()
        self.applicationViewModel = builder.makeRootViewModel()
        self.applicationRouter = self.applicationViewModel.router
        self.applicationViewModel.registerBackgroundTask()

        return true
    }

    private func startMobileAdService() {
        let service = GoogleMobileAdsServiceImple()
        Task {
            await service.prepare()
            #if DEBUG
            await self.checkTestRewardedAdLoadable(service)
            #endif
        }
    }

    #if DEBUG
    private func checkTestRewardedAdLoadable(_ service: any MobileAdService) async {
        // 실제 광고 단위 발급 전이라 Google 공개 데모 단위를 쓴다
        let testUnitId = "ca-app-pub-3940256099942544/1712485313"
        do {
            try await service.loadRewardedAd(unitId: testUnitId)
            logger.log(level: .info, "AdMob test rewarded ad loaded")
        } catch {
            logger.log(level: .error, "AdMob test rewarded ad load failed: \(error)")
        }
    }
    #endif

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
