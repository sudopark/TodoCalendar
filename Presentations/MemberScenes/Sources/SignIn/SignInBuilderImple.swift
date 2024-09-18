//
//  
//  SignInBuilderImple.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SignInSceneBuilerImple

final class SignInSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SignInSceneBuilerImple: SignInSceneBuiler {
    
    @MainActor
    func makeSignInScene() -> any SignInScene {
        
        let viewModel = SignInViewModelImple(
            authUsecase: self.usecaseFactory.authUsecase
        )
        
        let viewController = SignInViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance,
            signInButtonProvider: SignInButtonProviderImple()
        )
    
        let router = SignInRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
