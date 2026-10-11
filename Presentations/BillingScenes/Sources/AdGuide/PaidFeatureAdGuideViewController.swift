//
//  PaidFeatureAdGuideViewController.swift
//  BillingScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class PaidFeatureAdGuideViewController: UIHostingController<PaidFeatureAdGuideContainerView>, Scenes.Scene {

    var interactor: EmptyInteractor? { nil }
    let viewAppearance: ViewAppearance
    private let viewModel: any PaidFeatureAdGuideViewModel

    init(viewModel: any PaidFeatureAdGuideViewModel, viewAppearance: ViewAppearance) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        let eventHandlers = PaidFeatureAdGuideViewEventHandler()
        eventHandlers.bind(viewModel)
        var containerView = PaidFeatureAdGuideContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        containerView.stateBinding = { $0.bind(viewModel) }
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    /// 시트를 끌어내려 닫으면 버튼을 거치지 않아 여기서 닫힘을 알린다
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard self.isBeingDismissed else { return }
        self.viewModel.handleSheetDismissed()
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
