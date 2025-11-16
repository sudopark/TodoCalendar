//
//  
//  SelectMapAppDialogViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SelectMapAppDialogViewController

final class SelectMapAppDialogViewController: UIHostingController<SelectMapAppDialogContainerView>, SelectMapAppDialogScene {
    
    private let viewModel: any SelectMapAppDialogViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SelectMapAppDialogSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SelectMapAppDialogViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = SelectMapAppDialogViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = SelectMapAppDialogContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
