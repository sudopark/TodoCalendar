//
//  
//  EventTimeSelectionViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventTimeSelectionViewController

final class EventTimeSelectionViewController: UIHostingController<EventTimeSelectionContainerView>, EventTimeSelectionScene {
    
    private let viewModel: any EventTimeSelectionViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventTimeSelectionSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventTimeSelectionViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = EventTimeSelectionContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
