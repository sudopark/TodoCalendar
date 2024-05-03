//
//  
//  SelectEventTimeViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SelectEventTimeViewController

final class SelectEventTimeViewController: UIHostingController<SelectEventTimeContainerView>, SelectEventTimeScene {
    
    private let viewModel: any SelectEventTimeViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SelectEventTimeSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SelectEventTimeViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = SelectEventTimeViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = SelectEventTimeContainerView(
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
