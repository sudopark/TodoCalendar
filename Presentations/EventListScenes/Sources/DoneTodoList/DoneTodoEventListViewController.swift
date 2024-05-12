//
//  
//  DoneTodoEventListViewController.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - DoneTodoEventListViewController

final class DoneTodoEventListViewController: UIHostingController<DoneTodoEventListContainerView>, DoneTodoEventListScene {
    
    private let viewModel: any DoneTodoEventListViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any DoneTodoEventListSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any DoneTodoEventListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = DoneTodoEventListViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = DoneTodoEventListContainerView(
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
