//
//  
//  EventDefaultTagSelectViewController.swift
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


// MARK: - EventDefaultTagSelectViewController

final class EventDefaultTagSelectViewController: UIHostingController<EventDefaultTagSelectContainerView>, EventDefaultTagSelectScene {
    
    private let viewModel: any EventDefaultTagSelectViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventDefaultTagSelectSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventDefaultTagSelectViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = EventDefaultTagSelectViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = EventDefaultTagSelectContainerView(
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
