//
//  
//  ManageAccountViewController.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Extensions
import Scenes
import CommonPresentation


// MARK: - ManageAccountViewController

final class ManageAccountViewController: UIHostingController<ManageAccountContainerView>, ManageAccountScene {
    
    private let viewModel: any ManageAccountViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any ManageAccountSceneInteractor)? { self.viewModel }
    
    private let cancellables = CancelBag()
    
    init(
        viewModel: any ManageAccountViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = ManageAccountViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = ManageAccountContainerView(
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
