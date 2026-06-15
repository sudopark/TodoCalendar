//
//  AIAgentViewController.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


final class AIAgentViewController: UIHostingController<AIAgentContainerView>, AIAgentScene {

    private let viewModel: any AIAgentViewModel
    private let viewAppearance: ViewAppearance

    @MainActor
    var interactor: (any AIAgentSceneInteractor)? { self.viewModel }

    init(
        viewModel: any AIAgentViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = AIAgentViewEventHandler()
        eventHandlers.bind(viewModel)

        let inputEventHandlers = AIAgentInputViewEventHandler()
        inputEventHandlers.bind(viewModel.inputViewModel)

        let commandEventHandlers = AIAgentCommandViewEventHandler()
        commandEventHandlers.bind(viewModel.commandViewModel)

        let stageViewBuilder = AIAgentStageViewBuilder(
            viewAppearance: viewAppearance,
            inputViewModel: viewModel.inputViewModel,
            commandViewModel: viewModel.commandViewModel,
            inputEventHandlers: inputEventHandlers,
            commandEventHandlers: commandEventHandlers
        )

        let containerView = AIAgentContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers,
            stageViewBuilder: stageViewBuilder
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })

        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
