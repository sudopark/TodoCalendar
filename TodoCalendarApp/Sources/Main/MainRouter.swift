//
//  
//  MainRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol MainRouting: Routing, Sendable {
    
    @MainActor
    func attachCalendar() -> (any CalendarSceneInteractor)?
    
    func routeToEventTypeFilterSetting()
    func routeToSettingScene()
    func showJumpDaySelectDialog(current: CalendarDay)
    func showColorThemeLicenseExpiredGuide(
        _ reason: PaidFeatureGateFailReason,
        onFinished: @escaping @Sendable (Bool) -> Void,
        onUseDefault: @escaping @Sendable () -> Void
    )
    func showTrackingGuide(
        onContinue: @escaping @Sendable () -> Void,
        onDecline: @escaping @Sendable () -> Void
    )
    func showLaunchFullScreenAd()
}

// MARK: - Router

final class MainRouter: BaseRouterImple, MainRouting, @unchecked Sendable {
    
    private let calendarSceneBulder: any CalendarSceneBuilder
    private let settingSceneBuilder: any SettingSceneBuiler
    private let fullScreenAdRouter: (any FullScreenAdRouter)?
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    init(
        calendarSceneBulder: any CalendarSceneBuilder,
        settingSceneBuilder: any SettingSceneBuiler,
        fullScreenAdRouter: (any FullScreenAdRouter)?,
        adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder
    ) {
        self.calendarSceneBulder = calendarSceneBulder
        self.settingSceneBuilder = settingSceneBuilder
        self.fullScreenAdRouter = fullScreenAdRouter
        self.adGuideSceneBuilder = adGuideSceneBuilder
    }
}


extension MainRouter {
    
    private var currentScene: (any MainScene)? {
        self.scene as? (any MainScene)
    }
    
    // TODO: router implememnts
    
    @MainActor
    func attachCalendar() -> (any CalendarSceneInteractor)? {
        guard let current = self.currentScene else { return nil }
        let calendarScene = self.calendarSceneBulder.makeCalendarScene(
            listener: current.interactor
        )
        current.addCalendar(calendarScene)
        
        return calendarScene.interactor
    }
    
    func routeToEventTypeFilterSetting() {
        Task { @MainActor in
            
            let eventSettingScene = self.settingSceneBuilder.makeEventTagListScene(
                isRootNavigation: true,
                listener: nil
            )
            let navigationController = UINavigationController(rootViewController: eventSettingScene)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
    
    func routeToSettingScene() {
        Task { @MainActor in

            let scene = self.settingSceneBuilder.makeSettingItemListScene()
            let navigation = SettingNavigationController(rootViewController: scene)
            navigation.onDismissed = { [weak self] in self?.showFullScreenAdAfterSettingExit() }
            self.currentScene?.present(navigation, animated: true)
        }
    }

    @MainActor
    private func showFullScreenAdAfterSettingExit() {
        self.presentFullScreenAd(isFromAppLaunch: false)
    }

    func showLaunchFullScreenAd() {
        Task { @MainActor in
            self.presentFullScreenAd(isFromAppLaunch: true)
        }
    }

    @MainActor
    private func presentFullScreenAd(isFromAppLaunch: Bool) {
        guard let scene = self.currentScene, let adRouter = self.fullScreenAdRouter else { return }
        adRouter.showFullScreenAd(
            from: scene, scope: .application, isFromAppLaunch: isFromAppLaunch
        )
    }
    
    func showJumpDaySelectDialog(current: CalendarDay) {
        Task { @MainActor in
            
            let dialog = self.calendarSceneBulder.makeSelectDialog(
                current: current, self.currentScene?.interactor
            )
            self.showBottomSlide(dialog)
        }
    }

    func showColorThemeLicenseExpiredGuide(
        _ reason: PaidFeatureGateFailReason,
        onFinished: @escaping @Sendable (Bool) -> Void,
        onUseDefault: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            let guide = self.adGuideSceneBuilder.makePaidFeatureAdGuideScene(
                reason: reason, onFinished: onFinished, onUseDefault: onUseDefault
            )
            self.showBottomSlide(guide)
        }
    }

    func showTrackingGuide(
        onContinue: @escaping @Sendable () -> Void,
        onDecline: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            // 안내를 못 띄우는 자리에서도 거절로 흘려 뒤따르는 광고 단계가 멈추지 않게 한다
            guard let appearance = self.currentScene?.viewAppearance else {
                onDecline()
                return
            }
            let guide = TrackingGuideHostingViewController(
                appearance: appearance,
                onContinue: { [weak self] in
                    self?.dismissPresented(animated: true) { onContinue() }
                },
                onDecline: { [weak self] in
                    self?.dismissPresented(animated: true) { onDecline() }
                }
            )
            self.showBottomSlide(guide, onPullDismissed: onDecline)
        }
    }
}
