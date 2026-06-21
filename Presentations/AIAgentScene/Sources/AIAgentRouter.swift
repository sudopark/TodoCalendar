//
//  AIAgentRouter.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


// MARK: - AIAgentRouting

protocol AIAgentRouting: Routing, Sendable {
    func openSystemSetting()
    func showCommandSheet(_ viewModel: any AIAgentCommandViewModel)
    func dismissCommandSheet()
}


// MARK: - AIAgentRouter

final class AIAgentRouter: BaseRouterImple, AIAgentRouting, @unchecked Sendable {

    private let viewAppearance: ViewAppearance

    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
        super.init()
    }
}

extension AIAgentRouter {

    func openSystemSetting() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else { return }
            UIApplication.shared.open(url)
        }
    }

    func showCommandSheet(_ viewModel: any AIAgentCommandViewModel) {
        Task { @MainActor in
            let eventHandlers = AIAgentCommandViewEventHandler()
            eventHandlers.bind(viewModel)
            var containerView = AIAgentCommandStageContainerView(
                viewAppearance: self.viewAppearance,
                eventHandlers: eventHandlers
            )
            containerView.stateBinding = { $0.bind(viewModel) }
            let vc = UIHostingController(rootView: containerView)
            vc.view.backgroundColor = .clear
            self.showBottomSlide(vc)
        }
    }

    func dismissCommandSheet() {
        self.dismissPresented(animated: true, nil)
    }
}
