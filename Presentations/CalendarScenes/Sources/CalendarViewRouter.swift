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

    @MainActor
    func slideFocus(to index: Int, isNext: Bool, completed: @escaping @Sendable () -> Void)

    func routeToAICommand(listener: (any AIAgentCommandSceneListener)?)

    func routeToPaywall()

    func routeToSignIn()

    func openSystemSetting()
}

final class CalendarViewRouterImple: BaseRouterImple, CalendarViewRouting, @unchecked Sendable {

    private let paperSceneBuilder: any CalendarPaperSceneBuiler
    private let aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    private let memberSceneBuilder: any MemberSceneBuilder
    private let paywallSceneBuilder: any PaywallSceneBuilder
    init(
        _ paperSceneBuilder: any CalendarPaperSceneBuiler,
        aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder,
        memberSceneBuilder: any MemberSceneBuilder,
        paywallSceneBuilder: any PaywallSceneBuilder
    ) {
        self.paperSceneBuilder = paperSceneBuilder
        self.aiAgentCommandSceneBuilder = aiAgentCommandSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
        self.paywallSceneBuilder = paywallSceneBuilder
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

    @MainActor
    func slideFocus(to index: Int, isNext: Bool, completed: @escaping @Sendable () -> Void) {
        guard let current = self.currentScene else { return }
        current.slideFocus(to: index, isNext: isNext, completed: completed)
    }

    func routeToAICommand(listener: (any AIAgentCommandSceneListener)?) {
        self.dismissPresented(animated: true) { [weak self] in
            Task { @MainActor in
                self?.presentAICommandScene(listener: listener)
            }
        }
    }

    @MainActor
    private func presentAICommandScene(listener: (any AIAgentCommandSceneListener)?) {
        let next = self.aiAgentCommandSceneBuilder.makeCommandScene(listener: listener)
        self.showBottomSlide(next)
    }

    // 시트를 얹은 채로 paywall을 올리면 top-up 후 복귀해도 시트가 다시 드러난다
    func routeToPaywall() {
        self.dismissPresented(animated: true) { [weak self] in
            Task { @MainActor in
                self?.presentPaywallScene()
            }
        }
    }

    @MainActor
    private func presentPaywallScene() {
        let next = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
        self.showFullScreen(next)
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
