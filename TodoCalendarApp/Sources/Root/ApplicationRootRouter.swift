//
//  ApplicationRootRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import SwiftUI
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
            
            if self.appearance.rowHeightOnCalendar != newSetting.rowHeight {
                self.appearance.rowHeightOnCalendar = newSetting.rowHeight
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
    
    func applyEventTagColors(_ tags: [any EventTag]) {
        self.appearance.updateEventColorMap(by: tags)
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

extension ApplicationViewAppearanceStoreImple: GoogleCalendarViewAppearanceStore {

    func applyColors(_ colors: GoogleCalendar.Colors, for accountId: String) {
        Task { @MainActor in
            self.appearance.googleCalendarColors[accountId] = colors
        }
    }

    func clearColors(for accountId: String) {
        Task { @MainActor in
            self.appearance.googleCalendarColors[accountId] = nil
        }
    }

    func applyCalendarTags(_ tags: [GoogleCalendar.Tag], for accountId: String) {
        Task { @MainActor in
            self.appearance.applyCalendarTags(tags, for: accountId)
        }
    }

    func clearCalendarTags(for accountId: String) {
        Task { @MainActor in
            self.appearance.clearCalendarTags(for: accountId)
        }
    }

}

extension ApplicationViewAppearanceStoreImple: AppleCalendarViewAppearanceStore {

    func applyCalendarTags(_ tags: [AppleCalendar.Tag]) {
        Task { @MainActor in
            self.appearance.applyCalendarTags(tags)
        }
    }

    func clearCalendarTags() {
        Task { @MainActor in
            self.appearance.clearCalendarTags()
        }
    }
}


// MARK: - ApplicationRootRouter

protocol ApplicationRouting: Routing {

    func setupInitialScene(_ prepareResult: ApplicationPrepareResult)
    func changeRootSceneAfter(signIn auth: Auth?)
    func showUpdatePopup(_ requirement: AppUpdateRequirement)
}

final class ApplicationRootRouter: ApplicationRouting, @unchecked Sendable {
    
    
    @MainActor var window: UIWindow!
    @MainActor private weak var updatePopupViewController: UIViewController?
    var viewAppearanceStore: ApplicationViewAppearanceStoreImple!
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    private let backgroundEventSyncUsecase: any BackgroundEventSyncUsecase
    private let applicationBase: ApplicationBase
    private let deepLinkHandler: ApplicationDeepLinkHandlerImple
    private var usecaseFactory: (any UsecaseFactory)!

    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        backgroundEventSyncUsecase: any BackgroundEventSyncUsecase,
        applicationBase: ApplicationBase,
        deepLinkHandler: ApplicationDeepLinkHandlerImple
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
        self.backgroundEventSyncUsecase = backgroundEventSyncUsecase
        self.applicationBase = applicationBase
        self.deepLinkHandler = deepLinkHandler
    }
    
    func showError(_ error: any Error) {
        // TODO:
    }
    
    func showActionSheet(_ form: ActionSheetForm) {
        // TODO: 
    }
    
    func showToast(_ message: String) {
        // TODO: 
    }
    
    func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        // TODO: 
    }
    
    func openSafari(_ path: String) {
        Task { @MainActor in
            
            guard let url = path.asURL() else { return }
            UIApplication.shared.open(url)
        }
    }
    
    func pop(animate: Bool) {
        // ignore
    }
    
    func dismissPresented(animated: Bool, _ completed: (() -> Void)?) {
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
    
    func showConfirm(dialog info: ConfirmDialogInfo) {
        Task { @MainActor in
            guard let topViewController = self.window.rootViewController?.topPresentedViewController()
            else { return }

            let alertController = info.asAlertViewController()
            topViewController.present(alertController, animated: true)
        }
    }

    func showUpdatePopup(_ requirement: AppUpdateRequirement) {
        Task { @MainActor in
            guard self.updatePopupViewController == nil else { return }
            guard let topViewController = self.window.rootViewController?.topPresentedViewController()
            else { return }

            let onUpdate: () -> Void = {
                if let url = URL(string: AppEnvironment.appstoreLinkPath) {
                    UIApplication.shared.open(url)
                }
            }
            let onClose: (() -> Void)? = requirement == .recommended ? { [weak self] in
                self?.updatePopupViewController?.dismiss(animated: false)
                self?.updatePopupViewController = nil
            } : nil

            let view = ForceUpdatePopupView(
                requirement: requirement,
                onUpdate: onUpdate,
                onClose: onClose
            )
            .environment(self.viewAppearanceStore.appearance)
            let hostingVC = UIHostingController(rootView: view)
            hostingVC.modalPresentationStyle = .overFullScreen
            hostingVC.isModalInPresentation = true
            hostingVC.view.backgroundColor = .clear

            self.updatePopupViewController = hostingVC
            topViewController.present(hostingVC, animated: false)
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
                externalCalenarIntegrationUsecase: self.externalCalenarIntegrationUsecase,
                viewAppearanceStore: self.viewAppearanceStore,
                temporaryUserDataFilePath: AppEnvironment.dbFilePath(for: nil),
                applicationBase: self.applicationBase
            )
        } else {
            self.usecaseFactory = NonLoginUsecaseFactoryImple(
                authUsecase: self.authUsecase,
                accountUescase: self.accountUsecase,
                externalCalenarIntegrationUsecase: self.externalCalenarIntegrationUsecase,
                viewAppearanceStore: self.viewAppearanceStore,
                applicationBase: applicationBase
            )
        }
        self.backgroundEventSyncUsecase.change(factory: self.usecaseFactory)
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
        let builder = CalendarSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder(),
            eventListSceneBuilder: self.eventListSceneBuilder()
        )
        self.deepLinkHandler.attach(calendarHandler: builder.calendarDeepLinkHandler)
        return builder
    }
    
    private func holidayEventDetailSceneBuilder() -> any HolidayEventDetailSceneBuiler {
        return HolidayEventDetailSceneBuilerImple(
            usecaseFactory: self.usecaseFactory, viewAppearance: self.viewAppearanceStore.appearance
        )
    }
    
    private func googleCalendarEventDetailBuilder() -> any GoogleCalendarEventDetailSceneBuiler {
        return GoogleCalendarEventDetailSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance
        )
    }

    private func appleCalendarEventDetailBuilder() -> any AppleCalendarEventDetailSceneBuilder {
        return AppleCalendarEventDetailSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance
        )
    }

    private func eventDetailSceneBuilder() -> any EventDetailSceneBuilder {
        return EventDetailSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearanceStore.appearance,
            holidayEventDetailSceneBuilder: self.holidayEventDetailSceneBuilder(),
            googleCalendarEventDetailSceneBuilder: self.googleCalendarEventDetailBuilder(),
            appleCalendarEventDetailSceneBuilder: self.appleCalendarEventDetailBuilder(),
            settingSceneBuilder: settingSceneBuilder()
        )
    }
    
    private func settingSceneBuilder() -> any SettingSceneBuiler {
        return SettingSceneBuilderImple(
            appstoreLinkPath: AppEnvironment.appstoreLinkPath,
            supportExternalCalendarServices: AppEnvironment.supportExternalCalendarServices,
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
            viewAppearance: self.viewAppearanceStore.appearance,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder()
        )
    }
}
