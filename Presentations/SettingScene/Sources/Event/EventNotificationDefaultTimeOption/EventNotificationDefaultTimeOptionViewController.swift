//
//  
//  EventNotificationDefaultTimeOptionViewController.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventNotificationDefaultTimeOptionViewController

final class EventNotificationDefaultTimeOptionViewController: UIHostingController<EventNotificationDefaultTimeOptionContainerView>, EventNotificationDefaultTimeOptionScene {
    
    private let viewModel: any EventNotificationDefaultTimeOptionViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventNotificationDefaultTimeOptionSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventNotificationDefaultTimeOptionViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = EventNotificationDefaultTimeOptionViewEventHandler()
        eventHandlers.viewOnAppear = viewModel.reload
        eventHandlers.requestPermission = viewModel.requestPermission
        eventHandlers.selectOption = viewModel.selectOption(_:)
        eventHandlers.close = viewModel.close
        
        let containerView = EventNotificationDefaultTimeOptionContainerView(
            isForAllDay: viewModel.forAllDay,
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
