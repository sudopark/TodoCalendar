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
import EventListScenes
import SettingScene
import MemberScenes
import SQLiteService


// MARK: - ApplicationViewAppearanceStore

final class ApplicationViewAppearanceStoreImple: ViewAppearanceStore, @unchecked Sendable {
    
    let appearance: ViewAppearance
    @MainActor weak var window: UIWindow?
    
    @MainActor
    init(_ setting: AppearanceSettings, _ window: UIWindow?) {
        
        self.window = window
        self.appearance = .init(
            setting: setting, 
            isSystemDarkTheme: window?.traitCollection.userInterfaceStyle == .dark
        )
        self.bindSystemColorThemeChanged()
        self.changeNavigationBarAppearnace(self.appearance.colorSet)
    }
    
    @MainActor
    private func bindSystemColorThemeChanged() {
        guard let window = self.window else { return }
        
        window.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (wd: UIWindow, _) in
            let isDark = wd.traitCollection.userInterfaceStyle == .dark
            self.notifySystemColorThemeChangedIfNeed(isDark: isDark)
        }
    }
    
    @MainActor
    private func notifySystemColorThemeChangedIfNeed(isDark: Bool) {
        guard self.appearance.colorSetKey == .systemTheme else { return }
        let newSet = self.appearance.colorSetKey.convert(isSystemDarkTheme: isDark)
        let didSetChanged = type(of: self.appearance.colorSet) != type(of: newSet)
        guard didSetChanged else { return }
        self.changeNavigationBarAppearnace(newSet)
        self.appearance.colorSet = newSet
        self.appearance.forceReloadNavigationBar()
    }
    
    func notifySettingChanged(_ newSetting: AppearanceSettings) {
        self.notifyDefaultEventTagColorChanged(newSetting.defaultTagColor)
        self.notifyCalendarSettingChanged(newSetting.calendar)
    }
    
    func notifyCalendarSettingChanged(_ newSetting: CalendarAppearanceSettings) {
        Task { @MainActor in
            if self.appearance.colorSetKey != newSetting.colorSetKey {
                self.appearance.colorSetKey = newSetting.colorSetKey
                let newSet = newSetting.colorSetKey.convert(
                    isSystemDarkTheme: self.window?.traitCollection.userInterfaceStyle == .dark
                )
                self.changeNavigationBarAppearnace(newSet)
                self.appearance.colorSet = newSet
                self.appearance.forceReloadNavigationBar()
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
    
    func notifyDefaultEventTagColorChanged(_ newSetting: DefaultEventTagColorSetting) {
        Task { @MainActor in
            let newTagColorSet = EventTagColorSet(newSetting)
            if self.appearance.tagColors != newTagColorSet {
                self.appearance.tagColors = newTagColorSet
            }
        }
    }
    
    @MainActor
    private func changeNavigationBarAppearnace(_ newSet: any ColorSet) {
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [.foregroundColor: newSet.text0]
        appearance.largeTitleTextAttributes = [.foregroundColor: newSet.text0]
        appearance.backgroundColor = newSet.bg0
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
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
    private let applicationBase: ApplicationBase
    private var usecaseFactory: (any UsecaseFactory)!
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        applicationBase: ApplicationBase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.applicationBase = applicationBase
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
        
        Task { @MainActor in
            self.viewAppearanceStore = .init(prepareResult.appearnceSetings, self.window)
            self.changeUsecaseFactroy(
                by: prepareResult.latestLoginAcount?.auth
            )
            self.refreshRoot()
            self.setupBaseViewAppearanceSetting()
        }
    }
    
    @MainActor private func setupBaseViewAppearanceSetting() {
        UIDatePicker.appearance().minuteInterval = 5
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
                userId: auth.uid,
                authUsecase: self.authUsecase,
                accountUescase: self.accountUsecase,
                viewAppearanceStore: self.viewAppearanceStore,
                temporaryUserDataFilePath: AppEnvironment.dbFilePath(for: nil),
                applicationBase: self.applicationBase
            )
        } else {
            self.usecaseFactory = NonLoginUsecaseFactoryImple(
                authUsecase: self.authUsecase,
                accountUescase: self.accountUsecase,
                viewAppearanceStore: self.viewAppearanceStore,
                applicationBase: applicationBase
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
            eventDetailSceneBuilder: self.eventDetailSceneBuilder(),
            eventListSceneBuilder: self.eventListSceneBuilder()
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
            appId: AppEnvironment.appId,
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
    
    private func eventListSceneBuilder() -> any EventListSceneBuiler {
        return EventListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory, 
            viewAppearance: self.viewAppearanceStore.appearance
        )
    }
}
