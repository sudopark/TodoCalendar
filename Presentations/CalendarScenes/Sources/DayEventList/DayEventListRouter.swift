//
//
//  DayEventListRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DayEventListRouting: Routing, Sendable {

    func routeToMakeNewEvent(_ withParams: MakeEventParams)
    // TODO: tempplate 관련해서 초기 파라미터 필요할 수 있음
    func routeToSelectTemplateForMakeEvent()
    func showDoneTodoList()
    func routeToSignIn()
    func routeToAIKeyboardInput()
    func routeToAICommand()
}

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable {

    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    private let memberSceneBuilder: any MemberSceneBuilder
    private let aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder
    private let aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    private let viewAppearance: ViewAppearance

    private weak var presentedAICommandScene: (any Scene)?

    init(
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler,
        memberSceneBuilder: any MemberSceneBuilder,
        aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder,
        aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder,
        viewAppearance: ViewAppearance
    ) {
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
        self.aiKeyboardInputSceneBuilder = aiKeyboardInputSceneBuilder
        self.aiAgentCommandSceneBuilder = aiAgentCommandSceneBuilder
        self.viewAppearance = viewAppearance
    }
}


extension DayEventListRouter {

    // TODO: router implememnts

    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        Task { @MainActor in

            let next = self.eventDetailSceneBuilder.makeNewEventScene(withParams)
            self.scene?.present(next, animated: true)
        }
    }

    func routeToSelectTemplateForMakeEvent() {
        // TODO: route to tempplate select scene
    }

    func showDoneTodoList() {
        Task { @MainActor in
            let next = self.eventListSceneBuilder.makeDoneTodoEventListScene()
            self.scene?.present(next, animated: true)
        }
    }

    func routeToSignIn() {
        Task { @MainActor in
            let next = self.memberSceneBuilder.makeSignInScene()
            self.showBottomSlide(next)
        }
    }

    func routeToAIKeyboardInput() {
        Task { @MainActor in
            let next = self.aiKeyboardInputSceneBuilder.makeScene()
            self.showBottomSlide(next)
        }
    }

    func routeToAICommand() {
        Task { @MainActor in
            guard self.presentedAICommandScene == nil else { return }
            let next = self.aiAgentCommandSceneBuilder.makeCommandScene()
            self.presentedAICommandScene = next
            self.showBottomSlide(next)
        }
    }
}
