//
//  
//  EventSettingViewController.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventSettingViewController

final class EventSettingViewController: UIHostingController<EventSettingContainerView>, EventSettingScene {
    
    private let viewModel: any EventSettingViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventSettingSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventSettingViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = EventSettingViewEventHandler()
        eventHandlers.onAppear = viewModel.prepare
        eventHandlers.onWillAppear = viewModel.reloadEventNotificationSetting
        eventHandlers.close = viewModel.close
        eventHandlers.selectTag = viewModel.selectTag
        eventHandlers.selectEventNotificationTime = { viewModel.selectEventNotificationTimeOption(forAllDay: false) }
        eventHandlers.selectAllDayEventNotificationTime = { viewModel.selectEventNotificationTimeOption(forAllDay: true) }
        eventHandlers.selectPeriod = viewModel.selectPeriod(_:)
        eventHandlers.selectDefaultMapApp = viewModel.selectDefaultMapApp
        eventHandlers.connectExternalCalendar = viewModel.connectExternalCalendar(_:)
        eventHandlers.disconnectExternalCalendar = viewModel.disconnectExternalCalendar(_:)
        
        let containerView = EventSettingContainerView(
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
