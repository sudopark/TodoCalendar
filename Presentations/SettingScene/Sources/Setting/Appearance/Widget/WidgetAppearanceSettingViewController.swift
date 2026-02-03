//
//  WidgetAppearanceSettingViewController.swift
//  SettingScene
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


final class WidgetAppearanceSettingViewController: UIHostingController<WidgetAppearanceSettingContainerView>, WidgetAppearanceSettingScene {
    
    private let viewModel: any WidgetAppearanceSettingViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any WidgetAppearanceSettingSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any WidgetAppearanceSettingViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = WidgetAppearanceSettingViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = WidgetAppearanceSettingContainerView(
            eventHandler: eventHandlers,
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
