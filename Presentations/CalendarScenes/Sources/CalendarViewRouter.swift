//
//  CalendarPagerViewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/30.
//

import Foundation
import Domain
import Scenes

protocol CalendarViewRouting: Routing, Sendable {

    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [any CalendarPaperSceneInteractor]

    @MainActor
    func changeFocus(at index: Int)

    func routeToAICommand()
}

final class CalendarViewRouterImple: BaseRouterImple, CalendarViewRouting, @unchecked Sendable {

    private let paperSceneBuilder: any CalendarPaperSceneBuiler
    private let aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    init(
        _ paperSceneBuilder: any CalendarPaperSceneBuiler,
        aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    ) {
        self.paperSceneBuilder = paperSceneBuilder
        self.aiAgentCommandSceneBuilder = aiAgentCommandSceneBuilder
    }
    private var currentScene: (any CalendarScene)? { self.scene as? (any CalendarScene) }
    private weak var presentedAICommandScene: (any Scene)?
    
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
        Task { @MainActor in
            // 이미 떠 있는 결과 시트가 있으면 닫고 새로 띄운다.
            // dismiss 완료 콜백에서 present해 전환 타이밍 충돌을 방지.
            if self.presentedAICommandScene != nil {
                self.scene?.dismiss(animated: true) { [weak self] in
                    self?.presentAICommandScene()
                }
            } else {
                self.presentAICommandScene()
            }
        }
    }

    @MainActor
    private func presentAICommandScene() {
        let next = self.aiAgentCommandSceneBuilder.makeCommandScene()
        self.presentedAICommandScene = next
        self.showBottomSlide(next)
    }
}
