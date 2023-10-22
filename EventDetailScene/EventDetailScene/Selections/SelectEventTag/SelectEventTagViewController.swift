//
//  
//  SelectEventTagViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SelectEventTagViewController

final class SelectEventTagViewController: UIHostingController<SelectEventTagContainerView>, SelectEventTagScene {
    
    private let viewModel: any SelectEventTagViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SelectEventTagSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SelectEventTagViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = SelectEventTagContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
