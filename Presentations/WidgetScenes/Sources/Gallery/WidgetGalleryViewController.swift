//
//  WidgetGalleryViewController.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Extensions
import Scenes
import CommonPresentation


final class WidgetGalleryViewController: UIHostingController<WidgetGalleryContainerView>, WidgetGalleryScene {
    
    private let viewModel: any WidgetGalleryViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any WidgetGallerySceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any WidgetGalleryViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = WidgetGalleryViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = WidgetGalleryContainerView(
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
