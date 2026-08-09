//
//  CalendarPagerViewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/30.
//

import UIKit
import Domain
import Scenes

protocol CalendarViewRouting: Routing, Sendable {

    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [any CalendarPaperSceneInteractor]

    @MainActor
    func changeFocus(at index: Int)

    func routeToAICommand()

    func routeToSignIn()

    func openSystemSetting()
}

final class CalendarViewRouterImple: BaseRouterImple, CalendarViewRouting, @unchecked Sendable {

    private let paperSceneBuilder: any CalendarPaperSceneBuiler
    private let aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    private let memberSceneBuilder: any MemberSceneBuilder
    init(
        _ paperSceneBuilder: any CalendarPaperSceneBuiler,
        aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder,
        memberSceneBuilder: any MemberSceneBuilder
    ) {
        self.paperSceneBuilder = paperSceneBuilder
        self.aiAgentCommandSceneBuilder = aiAgentCommandSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
    }
    private var currentScene: (any CalendarScene)? { self.scene as? (any CalendarScene) }

    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [any CalendarPaperSceneInteractor] {
        guard let current = self.currentScene else { return [] }
        
        let childScenes = months.map {
            self.paperSceneBuilder.makeCalendarPaperScene(
                $0, listener: current.interactor as? CalendarPaperSceneListener
            )
        }
        current.addChildMonths(childScenes)
        return childScenes.compactMap { $0.interactor }
    }
    
    @MainActor
    func changeFocus(at index: Int) {
        guard let current = self.currentScene else { return }
        current.changeFocus(at: index)
    }

    func routeToAICommand() {
        self.dismissPresented(animated: true) { [weak self] in
            Task { @MainActor in
                self?.presentAICommandScene()
            }
        }
    }

    @MainActor
    private func presentAICommandScene() {
        let next = self.aiAgentCommandSceneBuilder.makeCommandScene()
        self.showBottomSlide(next)
    }

    func routeToSignIn() {
        Task { @MainActor in
            let next = self.memberSceneBuilder.makeSignInScene()
            self.showBottomSlide(next)
        }
    }

    func openSystemSetting() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else { return }
            UIApplication.shared.open(url)
        }
    }
}
