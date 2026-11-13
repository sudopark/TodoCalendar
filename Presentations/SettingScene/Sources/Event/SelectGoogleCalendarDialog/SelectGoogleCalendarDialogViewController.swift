//
//  SelectGoogleCalendarDialogViewController.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Extensions
import CommonPresentation


// MARK: - SelectGoogleCalendarDialogViewController

final class SelectGoogleCalendarDialogViewController: UIHostingController<SelectGoogleCalendarDialogContainerView>, SelectGoogleCalendarDialogScene {

    private let viewModel: any SelectGoogleCalendarDialogViewModel
    let viewAppearance: ViewAppearance

    @MainActor
    var interactor: (any SelectGoogleCalendarDialogSceneInteractor)? { self.viewModel }

    init(
        viewModel: any SelectGoogleCalendarDialogViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = SelectGoogleCalendarDialogViewEventHandler()
        eventHandlers.bind(viewModel)

        let containerView = SelectGoogleCalendarDialogContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })

        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
