//
//  
//  SelectEventNotificationTimeViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SelectEventNotificationTimeViewController

final class SelectEventNotificationTimeViewController: UIHostingController<SelectEventNotificationTimeContainerView>, SelectEventNotificationTimeScene {
    
    private let viewModel: any SelectEventNotificationTimeViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SelectEventNotificationTimeSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SelectEventNotificationTimeViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = SelectEventNotificationTimeViewEventHandler()
        eventHandlers.onAppear = viewModel.prepare
        eventHandlers.toggleSelectDefaultOption = viewModel.toggleSelectDefaultOption(_:)
        eventHandlers.addCustomTimeOption = viewModel.addCustomTimeOption(_:)
        eventHandlers.removeCustomTimeOption = viewModel.removeCustomTimeOption(_:)
        eventHandlers.close = viewModel.close
        eventHandlers.moveSystemNotificationSetting = viewModel.moveSystemNotificationSetting
        
        let containerView = SelectEventNotificationTimeContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
