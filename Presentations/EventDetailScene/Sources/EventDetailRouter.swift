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
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventDetailRouting: Routing, Sendable, AnyObject {
    
    func attachInput(
        // TODO: listener 삭제해도됨
        _ listener: (any EventDetailInputListener)?
    ) -> (any EventDetailInputInteractor)?
    
    func showTodoEventGuide()
    
    func showForemostEventGuide()
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
}

// MARK: - Router

final class EventDetailRouter: BaseRouterImple, EventDetailRouting, EventDetailInputRouting, @unchecked Sendable {
    
    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    private let selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    private let selectNotificationTimeSceneBuilder: any SelectEventNotificationTimeSceneBuiler
    private let guideSceneBuilder: any GuideSceneBuilder
    weak var inputViewModel: (any EventDetailInputViewModel)?
    
    init(
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler,
        selectEventTagSceneBuilder: any SelectEventTagSceneBuiler,
        selectNotificationTimeSceneBuilder: any SelectEventNotificationTimeSceneBuiler,
        guideSceneBuilder: any GuideSceneBuilder
    ) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
        self.selectEventTagSceneBuilder = selectEventTagSceneBuilder
        self.selectNotificationTimeSceneBuilder = selectNotificationTimeSceneBuilder
        self.guideSceneBuilder = guideSceneBuilder
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
    
    func openMap(with name: String) {
        // TODO:
    }
}
