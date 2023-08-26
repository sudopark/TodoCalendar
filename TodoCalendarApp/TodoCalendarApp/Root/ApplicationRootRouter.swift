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
    
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult)
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
    
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult) {
        
        guard !AppEnvironment.isTestBuild else { return }
        self.viewAppearance = ViewAppearance(
            color: prepareResult.appearnceSetings.colorSetKey,
            font: prepareResult.appearnceSetings.fontSetKey
        )
        self.prepareDatabase(for: prepareResult.latestLoginAccountId)
        
        Task { @MainActor in
            let builder = CalendarSceneBuilderImple(
                usecaseFactory: self.nonLoginUsecaseFactory,
                viewAppearance: self.viewAppearance
            )
            let calendarScene = builder.makeCalendarScene(listener: DummyListener())
            let navigationController = UINavigationController(rootViewController: calendarScene)
            self.window.rootViewController = navigationController
            self.window.makeKeyAndVisible()
        }
    }
    
    private func prepareDatabase(for accountId: String?) {
        let database = Singleton.shared.commonSqliteService
        let dbPath = AppEnvironment.dbFilePath(for: accountId)
        let openResult = database.open(path: dbPath)
        print("db open result: \(openResult) -> path: \(dbPath)")
        
        // TODO: create table if need
    }
}

// TODO: replace real listener after implement
final class DummyListener: CalendarSceneListener {
    
    func calendarScene(focusChangedTo month: CalendarMonth, isCurrentMonth: Bool) { }
}
