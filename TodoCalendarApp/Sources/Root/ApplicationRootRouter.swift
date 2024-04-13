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
import MemberScenes
import SQLiteService


// MARK: - ApplicationViewAppearanceStore

final class ApplicationViewAppearanceStoreImple: ViewAppearanceStore, @unchecked Sendable {
    
    let appearance: ViewAppearance
    init(_ setting: AppearanceSettings) {
        
        self.appearance = .init(setting: setting)
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
        // calendar
        if self.appearance.accnetDayPolicy != newSetting.accnetDayPolicy {
            self.appearance.accnetDayPolicy = newSetting.accnetDayPolicy
        }
        if self.appearance.showUnderLineOnEventDay != newSetting.showUnderLineOnEventDay {
            self.appearance.showUnderLineOnEventDay = newSetting.showUnderLineOnEventDay
        }
        
        // evnet on calendar
        if self.appearance.eventOnCalenarTextAdditionalSize != newSetting.eventOnCalenarTextAdditionalSize {
            self.appearance.eventOnCalenarTextAdditionalSize = newSetting.eventOnCalenarTextAdditionalSize
        }
        if self.appearance.eventOnCalendarIsBold != newSetting.eventOnCalendarIsBold {
            self.appearance.eventOnCalendarIsBold = newSetting.eventOnCalendarIsBold
        }
        if self.appearance.eventOnCalendarShowEventTagColor != newSetting.eventOnCalendarShowEventTagColor {
            self.appearance.eventOnCalendarShowEventTagColor = newSetting.eventOnCalendarShowEventTagColor
        }
        
        // event list
        if self.appearance.eventTextAdditionalSize != newSetting.eventTextAdditionalSize {
            self.appearance.eventTextAdditionalSize = newSetting.eventTextAdditionalSize
        }
        if self.appearance.showHoliday != newSetting.showHoliday {
            self.appearance.showHoliday = newSetting.showHoliday
        }
        if self.appearance.showLunarCalendarDate != newSetting.showLunarCalendarDate {
            self.appearance.showLunarCalendarDate = newSetting.showLunarCalendarDate
        }
        if self.appearance.is24hourForm != newSetting.is24hourForm {
            self.appearance.is24hourForm = newSetting.is24hourForm
        }
        
        // general
        if self.appearance.hapticEffectOff != newSetting.hapticEffectIsOn {
            self.appearance.hapticEffectOff = newSetting.hapticEffectIsOn
        }
        if self.appearance.animationEffectOff != newSetting.animationEffectIsOn {
            self.appearance.animationEffectOff = newSetting.animationEffectIsOn
        }
    }
}

// MARK: - ApplicationRootRouter

protocol ApplicationRouting: Routing {
    
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult)
    func changeRootSceneAfter(signIn auth: Auth?)
}

final class ApplicationRootRouter: ApplicationRouting, @unchecked Sendable {
    
    
    @MainActor var window: UIWindow!
    var viewAppearanceStore: ApplicationViewAppearanceStoreImple!
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private var usecaseFactory: (any UsecaseFactory)!
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
    }
    
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
    
    func openSafari(_ path: String) {
        // ignore
    }
    
    func pop(animate: Bool) {
        // ignore
    }
}


extension ApplicationRootRouter {
    
    func setupInitialScene(
        _ prepareResult: ApplicationPrepareResult
    ) {
        
        guard !AppEnvironment.isTestBuild else { return }
        self.viewAppearanceStore = .init(prepareResult.appearnceSetings)
        
        Task { @MainActor in
            self.changeUsecaseFactroy(
                by: prepareResult.latestLoginAcount?.auth
            )
            self.refreshRoot()
        }
    }

    func changeRootSceneAfter(signIn auth: Auth?) {
        Task { @MainActor in
            self.changeUsecaseFactroy(by: auth)
            self.refreshRoot()
        }
    }
    
    private func changeUsecaseFactroy(
        by auth: Auth?
    ) {
        if let auth = auth {
            self.usecaseFactory = LoginUsecaseFactoryImple(
                authUsecase: self.authUsecase,
                accountUescase: self.accountUsecase,
                viewAppearanceStore: self.viewAppearanceStore
            )
        } else {
            self.usecaseFactory = NonLoginUsecaseFactoryImple(
                authUsecase: self.authUsecase,
                accountUescase: self.accountUsecase,
                viewAppearanceStore: self.viewAppearanceStore
            )
        }
    }
    
    @MainActor
    private func refreshRoot() {
        
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
            viewAppearance: self.viewAppearanceStore.appearance,
            memberSceneBuilder: self.memberSceneBuilder()
        )
    }
    
    private func memberSceneBuilder() -> any MemberSceneBuilder {
        return MemberSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance
        )
    }
}
