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

    // 진입 시점에 떠 있는 시트는 이전 결과 시트일 수도, 키보드 입력 시트(다른 라우터가 띄운다)일 수도 있다.
    // 무엇이 떠 있든 닫고 완료 콜백에서 present — 겹쳐 띄우면 UIKit이 예외를 던진다.
    // 뜬 게 없으면 dismissPresented가 즉시 completion을 부르므로 음성 입력 경로도 그대로 통과한다.
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
