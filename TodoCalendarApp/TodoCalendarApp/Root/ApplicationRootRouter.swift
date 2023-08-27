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
        
        // TODO: 추후에 prepare result에 따라 usecase factory 결정해야함
        
        Task { @MainActor in
            let builder = MainSceneBuilerImple(
                usecaseFactory: self.nonLoginUsecaseFactory,
                viewAppearance: self.viewAppearance
            )
            let mainScene = builder.makeMainScene()
            self.window.rootViewController = mainScene
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
