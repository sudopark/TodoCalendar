//
//  AppleCalendarEventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - AppleCalendarEventDetailViewController

final class AppleCalendarEventDetailViewController: UIHostingController<AppleCalendarEventDetailContainerView>, AppleCalendarEventDetailScene {

    private let viewModel: any AppleCalendarEventDetailViewModel
    private let viewAppearance: ViewAppearance

    @MainActor
    var interactor: (any AppleCalendarEventDetailSceneInteractor)? { self.viewModel }

    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: any AppleCalendarEventDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = AppleCalendarEventDetailViewEventHandler()
        eventHandlers.bind(viewModel)

        let containerView = AppleCalendarEventDetailContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })

        super.init(rootView: containerView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
