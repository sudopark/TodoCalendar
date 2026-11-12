//
//  
//  EventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Prelude
import Optics
import CommonPresentation
import EventDetailSceneInterface
import EventDomainInterface
import SceneInfra
import SettingDomainInterface


// MARK: - Routing

protocol EventDetailRouting: Routing, Sendable, AnyObject {

    func attachInput(
        // TODO: listener 삭제해도됨
        _ listener: (any EventDetailInputListener)?
    ) -> (any EventDetailInputInteractor)?

    func showTodoEventGuide()

    func showForemostEventGuide()

    func showShareSheet(text: String)

    func closeSceneThenRequestAppReview()

    func closeSceneThenShowFullScreenAd()
}


extension EventDetailRouting {
    
    func showConfirmClose() {
        let confirmed: () -> Void = { [weak self] in
            self?.closeScene(animate: true, nil)
        }
        
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("eventDetail.cancel_edit::title".localized())
            |> \.message .~ pure("eventDetail.cancel_edit::message".localized())
            |> \.confirmText .~ "common.close".localized()
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
            |> \.cancelText .~ "eventDetail.cancel_edit::continue::button".localized()
        self.showConfirm(dialog: info)
    }

    func closeSceneAfterEventSaved(isFullScreenAdTurn: Bool) {
        if isFullScreenAdTurn {
            self.closeSceneThenShowFullScreenAd()
        } else {
            self.closeScene(animate: true, nil)
        }
    }
}

// MARK: - Router

final class EventDetailRouter: BaseRouterImple, EventDetailRouting, EventDetailInputRouting, @unchecked Sendable {
    
    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    private let selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    private let selectNotificationTimeSceneBuilder: any SelectEventNotificationTimeSceneBuiler
    private let guideSceneBuilder: any GuideSceneBuilder
    private let selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler
    private let appStoreReviewRouter: any AppStoreReviewRouter
    private let fullScreenAdRouter: any FullScreenAdRouter
    weak var inputViewModel: (any EventDetailInputViewModel)?
    
    init(
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler,
        selectEventTagSceneBuilder: any SelectEventTagSceneBuiler,
        selectNotificationTimeSceneBuilder: any SelectEventNotificationTimeSceneBuiler,
        guideSceneBuilder: any GuideSceneBuilder,
        selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler,
        appStoreReviewRouter: any AppStoreReviewRouter,
        fullScreenAdRouter: any FullScreenAdRouter
    ) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
        self.selectEventTagSceneBuilder = selectEventTagSceneBuilder
        self.selectNotificationTimeSceneBuilder = selectNotificationTimeSceneBuilder
        self.guideSceneBuilder = guideSceneBuilder
        self.selectMapSceneBuilder = selectMapSceneBuilder
        self.appStoreReviewRouter = appStoreReviewRouter
        self.fullScreenAdRouter = fullScreenAdRouter
    }
}


extension EventDetailRouter {
    
    private var currentScene: (any EventDetailScene)? {
        self.scene as? (any EventDetailScene)
    }
    
    func attachInput(
        _ listener: (any EventDetailInputListener)?
    ) -> (any EventDetailInputInteractor)? {
        inputViewModel?.listener = listener
        return inputViewModel
    }
    
    func closeSceneThenRequestAppReview() {
        Task { @MainActor in
            // 리뷰 시트는 씬에 붙어야 뜬다 — 화면을 닫기 전에 붙일 창을 잡아 둔다
            guard let windowScene = self.scene?.view.window?.windowScene
            else {
                self.scene?.dismiss(animated: true)
                return
            }
            await self.scene?.dismiss(animated: true)
            self.appStoreReviewRouter.requestAppReview(in: windowScene)
        }
    }

    func closeSceneThenShowFullScreenAd() {
        Task { @MainActor in
            // 전환 중인 화면에서는 AdMob 이 표시를 거절한다 (Code=17)
            let presenting = self.scene?.presentingViewController
            self.scene?.dismiss(animated: true) { [fullScreenAdRouter] in
                guard let presenting else { return }
                fullScreenAdRouter.showFullScreenAd(from: presenting)
            }
        }
    }

    func showTodoEventGuide() {
        Task { @MainActor in
            let vc = self.guideSceneBuilder.makeTodoEventGuide()
            self.showBottomSlide(vc)
        }
    }
    
    func showForemostEventGuide() {
        Task { @MainActor in
            let vc = self.guideSceneBuilder.makeForemostEventGuide()
            self.showBottomSlide(vc)
        }
    }
    
    func routeToEventRepeatOptionSelect(
        selectTime: Date,
        with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        Task { @MainActor in
            
            let next = self.selectRepeatOptionSceneBuilder.makeSelectEventRepeatOptionScene(
                selectTime: selectTime,
                previousSelected: initalOption,
                rruleRepresentableOnly: false,
                listener: listener
            )
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToEventTagSelect(
        currentSelectedTagId: EventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) {
        Task { @MainActor in
            
            let next = self.selectEventTagSceneBuilder.makeSelectEventTagScene(
                startWith: currentSelectedTagId,
                listener: listener
            )
            
            let navigationController = UINavigationController(rootViewController: next)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
    
    func routeToEventNotificationTimeSelect(
        isForAllDay: Bool,
        current selecteds: [EventNotificationTimeOption],
        eventTimeComponents: DateComponents,
        listener: (any SelectEventNotificationTimeSceneListener)?
    ) {
        
        Task { @MainActor in
            
            let next = self.selectNotificationTimeSceneBuilder.makeSelectEventNotificationTimeScene(
                isForAllDay: isForAllDay,
                startWith: selecteds,
                eventTimeComponents: eventTimeComponents,
                listener: listener
            )
            
            let navigationController = UINavigationController(rootViewController: next)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
    
    func openMap(with query: String, using mapApp: SupportMapApps) {
        Task { @MainActor in
            guard let url = mapApp.appURL(with: query) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                self.showToast("eventDetail.place::no_map_app".localized())
            }
        }
    }
    
    func openMap(with query: String, afterSelect mapApps: [SupportMapApps]) {
        Task { @MainActor in
            let next = self.selectMapSceneBuilder.makeSelectMapAppDialogScene(query: query, supportMapApps: mapApps)
            self.showBottomSlide(next)
        }
    }
}
