//
//  OpenSourceLicenseBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - OpenSourceLicenseSceneBuilerImple

final class OpenSourceLicenseSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension OpenSourceLicenseSceneBuilerImple: OpenSourceLicenseSceneBuiler {
    
    @MainActor
    func makeOpenSourceLicenseScene() -> any OpenSourceLicenseScene {
        
        let viewModel = OpenSourceLicenseViewModelImple()
        
        let viewController = OpenSourceLicenseViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = OpenSourceLicenseRouter()
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
