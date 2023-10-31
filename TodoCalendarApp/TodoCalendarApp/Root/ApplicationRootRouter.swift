//
//  ApplicationRootRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Domain
import Extensions
import Scenes
import CommonPresentation
import CalendarScenes
import EventDetailScene
import SettingScene


// MARK: - ApplicationViewAppearanceStore

final class ApplicationViewAppearanceStoreImple: ViewAppearanceStore, @unchecked Sendable {
    
    let appearance: ViewAppearance
    init(_ setting: AppearanceSettings) {
        
        self.appearance = .init(
            tagColorSetting: setting.tagColorSetting,
            color: setting.colorSetKey,
            font: setting.fontSetKey
        )
    }
    
    func notifySettingChanged(_ newSetting: AppearanceSettings) {
        let newTagColorSet = EventTagColorSet(newSetting.tagColorSetting)
        if self.appearance.tagColors != newTagColorSet {
            self.appearance.tagColors = newTagColorSet
        }
        if self.appearance.colorSet.key != newSetting.colorSetKey {
            self.appearance.colorSet = newSetting.colorSetKey.convert()
        }
        if self.appearance.fontSet.key != newSetting.fontSetKey {
            self.appearance.fontSet = newSetting.fontSetKey.convert()
        }
    }
}

// MARK: - ApplicationRootRouter

protocol ApplicationRouting: Routing {
    
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult)
}

final class ApplicationRootRouter: ApplicationRouting, @unchecked Sendable {
    
    @MainActor var window: UIWindow!
    var viewAppearanceStore: ApplicationViewAppearanceStoreImple!
    private var usecaseFactory: (any UsecaseFactory)!
    
    init() { }
    
    func showError(_ error: any Error) {
        // TODO:
    }
    
    func showToast(_ message: String) {
        // TODO: 
    }
    
    func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        // TODO: 
    }
    
    func showConfirm(dialog info: ConfirmDialogInfo) {
        // ignore
    }
}


extension ApplicationRootRouter {
    
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult) {
        
        guard !AppEnvironment.isTestBuild else { return }
        self.viewAppearanceStore = .init(prepareResult.appearnceSetings)
        self.prepareDatabase(for: prepareResult.latestLoginAccountId)
        
        // TODO: 추후에 prepare result에 따라 usecase factory 결정해야함
        self.usecaseFactory = NonLoginUsecaseFactoryImple(viewAppearanceStore: self.viewAppearanceStore)
        
        Task { @MainActor in
            let builder = MainSceneBuilerImple(
                usecaseFactory: self.usecaseFactory,
                viewAppearance: self.viewAppearanceStore.appearance,
                calendarSceneBulder: self.calendarSceneBulder(),
                settingSceneBuilder: self.settingSceneBuilder()
            )
            let mainScene = builder.makeMainScene()
            self.window.rootViewController = mainScene
            self.window.makeKeyAndVisible()
        }
    }
    
    private func calendarSceneBulder() -> any CalendarSceneBuilder {
        return CalendarSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder()
        )
    }
    
    private func eventDetailSceneBuilder() -> any EventDetailSceneBuilder {
        return EventDetailSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance,
            settingSceneBuilder: settingSceneBuilder()
        )
    }
    
    private func settingSceneBuilder() -> any SettingSceneBuiler {
        return SettingSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance
        )
    }
    
    private func prepareDatabase(for accountId: String?) {
        let database = Singleton.shared.commonSqliteService
        let dbPath = AppEnvironment.dbFilePath(for: accountId)
        let openResult = database.open(path: dbPath)
        logger.log(level: .info, "db open result: \(openResult) -> path: \(dbPath)")
        
        // TODO: create table if need
    }
}
