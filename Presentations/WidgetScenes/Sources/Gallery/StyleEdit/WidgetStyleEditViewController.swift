//
//  WidgetStyleEditViewController.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Domain
import Extensions
import Scenes
import CommonPresentation


final class WidgetStyleEditViewController: UIHostingController<WidgetStyleEditContainerView>, WidgetStyleEditScene {
    
    private let viewModel: any WidgetStyleEditViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any WidgetStyleEditSceneInteractor)? { self.viewModel }
    
    init(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings,
        viewModel: any WidgetStyleEditViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = WidgetStyleEditViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = WidgetStyleEditContainerView(
            variant: variant,
            setting: setting,
            eventHandler: eventHandlers,
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
