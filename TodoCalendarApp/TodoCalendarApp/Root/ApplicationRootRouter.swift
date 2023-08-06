//
//  ApplicationRootRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Domain
import Scenes
import CommonPresentation
import CalendarScenes



// MARK: - ApplicationRootRouter

protocol ApplicationRouting: Routing {
    
    func setupInitialScene()
}

final class ApplicationRootRouter: ApplicationRouting {
    
    @MainActor var window: UIWindow!
    var viewAppearance: ViewAppearance!
    
    private let nonLoginUsecaseFactory: NonLoginUsecaseFactoryImple
    init(nonLoginUsecaseFactory: NonLoginUsecaseFactoryImple) {
        self.nonLoginUsecaseFactory = nonLoginUsecaseFactory
    }
}


extension ApplicationRootRouter {
    
    func setupInitialScene() {
        
        guard !AppEnvironment.isTestBuild else { return }
        Task { @MainActor in
            let builder = CalendarSceneBuilderImple(
                usecaseFactory: self.nonLoginUsecaseFactory,
                viewAppearance: self.viewAppearance
            )
            let calendarScene = builder.makeCalendarScene()
            let navigationController = UINavigationController(rootViewController: calendarScene)
            self.window.rootViewController = navigationController
            self.window.makeKeyAndVisible()
        }
    }
}
