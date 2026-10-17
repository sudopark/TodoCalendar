//
//  WidgetGalleryDetailViewController.swift
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


final class WidgetGalleryDetailViewController: UIHostingController<WidgetGalleryDetailContainerView>, WidgetGalleryDetailScene {
    
    private let viewModel: any WidgetGalleryDetailViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any WidgetGalleryDetailSceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any WidgetGalleryDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = WidgetGalleryDetailViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = WidgetGalleryDetailContainerView(
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
