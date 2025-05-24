//
//  
//  GoogleCalendarEventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventDetailViewController

final class GoogleCalendarEventDetailViewController: UIHostingController<GoogleCalendarEventDetailContainerView>, GoogleCalendarEventDetailScene {
    
    private let viewModel: any GoogleCalendarEventDetailViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any GoogleCalendarEventDetailSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any GoogleCalendarEventDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = GoogleCalendarEventDetailViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = GoogleCalendarEventDetailContainerView(
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
