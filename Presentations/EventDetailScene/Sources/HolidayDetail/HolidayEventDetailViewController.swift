//
//  
//  HolidayEventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - HolidayEventDetailViewController

final class HolidayEventDetailViewController: UIHostingController<HolidayEventDetailContainerView>, HolidayEventDetailScene {
    
    private let viewModel: any HolidayEventDetailViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any HolidayEventDetailSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any HolidayEventDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = HolidayEventDetailViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = HolidayEventDetailContainerView(
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
