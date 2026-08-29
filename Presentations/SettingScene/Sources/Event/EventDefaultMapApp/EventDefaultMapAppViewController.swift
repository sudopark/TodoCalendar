//
//  
//  EventDefaultMapAppViewController.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Extensions
import Scenes
import CommonPresentation


// MARK: - EventDefaultMapAppViewController

final class EventDefaultMapAppViewController: UIHostingController<EventDefaultMapAppContainerView>, EventDefaultMapAppScene {
    
    private let viewModel: any EventDefaultMapAppViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventDefaultMapAppSceneInteractor)? { self.viewModel }
    
    private let cancellables = CancelBag()
    
    init(
        viewModel: any EventDefaultMapAppViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = EventDefaultMapAppViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = EventDefaultMapAppContainerView(
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
