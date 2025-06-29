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
        }
        
        let builder = ApplicationRootBuilder()
        self.applicationViewModel = builder.makeRootViewModel()
        self.applicationRouter = self.applicationViewModel.router
        
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



extension AppDelegate {
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        
        return self.applicationViewModel.handle(open: url)
    }
}
