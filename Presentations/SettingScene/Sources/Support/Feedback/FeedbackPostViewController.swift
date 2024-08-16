//
//  
//  FeedbackPostViewController.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - FeedbackPostViewController

final class FeedbackPostViewController: UIHostingController<FeedbackPostContainerView>, FeedbackPostScene {
    
    private let viewModel: any FeedbackPostViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any FeedbackPostSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any FeedbackPostViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = FeedbackPostViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = FeedbackPostContainerView(
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
