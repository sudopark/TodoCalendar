//
//  
//  ColorThemeSelectViewController.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - ColorThemeSelectViewController

final class ColorThemeSelectViewController: UIHostingController<ColorThemeSelectContainerView>, ColorThemeSelectScene {
    
    private let viewModel: any ColorThemeSelectViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any ColorThemeSelectSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any ColorThemeSelectViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = ColorThemeSelectViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = ColorThemeSelectContainerView(
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
