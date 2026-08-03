//
//  PaywallViewController.swift
//  BillingScenes
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class PaywallViewController: UIHostingController<PaywallContainerView>, PaywallScene {

    var interactor: (any PaywallSceneInteractor)? { nil }

    private let viewModel: any PaywallViewModel
    private let viewAppearance: ViewAppearance

    init(
        viewModel: any PaywallViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = PaywallViewEventHandler()
        eventHandlers.bind(viewModel)
        var containerView = PaywallContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        containerView.stateBinding = { $0.bind(viewModel) }
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
