//
//  
//  AddEventViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - AddEventViewController

final class AddEventViewController: UIHostingController<AddEventContainerView>, AddEventScene {
    
    private let viewModel: any AddEventViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any AddEventSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any AddEventViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = AddEventContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
