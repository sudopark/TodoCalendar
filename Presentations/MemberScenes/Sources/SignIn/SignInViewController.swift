//
//  
//  SignInViewController.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SignInViewController

final class SignInViewController: UIHostingController<SignInContainerView>, SignInScene {
    
    private let viewModel: any SignInViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SignInSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SignInViewModel,
        viewAppearance: ViewAppearance,
        signInButtonProvider: any SignInButtonProvider
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = SignInViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = SignInContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers,
            signInButtonProvider: signInButtonProvider
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
