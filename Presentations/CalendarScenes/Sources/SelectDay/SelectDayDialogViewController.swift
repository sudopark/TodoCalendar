//
//  SelectDayDialogViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 3/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class SelectDayDialogViewController: UIHostingController<SelectDayDialogContainerView>, SelectDayDialogScene {
    
    var interactor: EmptyInteractor? { nil }
    
    private let viewModel: any SelectDayDialogViewModel
    private let viewAppearance: ViewAppearance
    
    public init(
        viewModel: any SelectDayDialogViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandler = SelectDayDialogEventHandler()
        eventHandler.bind(viewModel)
        let containerView = SelectDayDialogContainerView(
            viewAppearance: viewAppearance,
            eventHandler: eventHandler
        )
            .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
