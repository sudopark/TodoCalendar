//
//  
//  EventTagSelectViewController.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventTagSelectViewController

final class EventTagSelectViewController: UIHostingController<EventTagSelectContainerView>, EventTagSelectScene {
    
    private let viewModel: any EventTagSelectViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventTagSelectSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventTagSelectViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = EventTagSelectViewEventHandler()
        
        let containerView = EventTagSelectContainerView(
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
