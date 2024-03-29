//
//  ___FILEHEADER___
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - ___VARIABLE_sceneName___SceneBuilerImple

final class ___VARIABLE_sceneName___SceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension ___VARIABLE_sceneName___SceneBuilerImple: ___VARIABLE_sceneName___SceneBuiler {
    
    @MainActor
    func make___VARIABLE_sceneName___Scene() -> any ___VARIABLE_sceneName___Scene {
        
        let viewModel = ___VARIABLE_sceneName___ViewModelImple(
            
        )
        
        let viewController = ___VARIABLE_sceneName___ViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = ___VARIABLE_sceneName___Router(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
