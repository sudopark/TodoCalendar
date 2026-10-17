//
//  ColorThemeEditViewController.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Extensions
import Scenes
import CommonPresentation


// MARK: - ColorThemeEditViewController

final class ColorThemeEditViewController: UIHostingController<ColorThemeEditContainerView>, ColorThemeEditScene {

    private let viewModel: any ColorThemeEditViewModel
    let viewAppearance: ViewAppearance

    @MainActor
    var interactor: (any ColorThemeEditSceneInteractor)? { self.viewModel }

    init(
        viewModel: any ColorThemeEditViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = ColorThemeEditViewEventHandler()
        eventHandlers.bind(viewModel)

        let containerView = ColorThemeEditContainerView(
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
