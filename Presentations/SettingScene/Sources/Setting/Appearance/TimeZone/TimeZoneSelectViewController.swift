//
//  
//  TimeZoneSelectViewController.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - TimeZoneSelectViewController

final class TimeZoneSelectViewController: UIHostingController<TimeZoneSelectContainerView>, TimeZoneSelectScene {
    
    private let viewModel: any TimeZoneSelectViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any TimeZoneSelectSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any TimeZoneSelectViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = TimeZoneSelectViewEventHandler()
        
        let containerView = TimeZoneSelectContainerView(
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
