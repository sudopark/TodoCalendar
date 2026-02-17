//
//  
//  DoneTodoDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - DoneTodoDetailViewController

final class DoneTodoDetailViewController: UIHostingController<DoneTodoDetailContainerView>, DoneTodoDetailScene {
    
    private let viewModel: any DoneTodoDetailViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any DoneTodoDetailSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any DoneTodoDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = DoneTodoDetailViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = DoneTodoDetailContainerView(
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
