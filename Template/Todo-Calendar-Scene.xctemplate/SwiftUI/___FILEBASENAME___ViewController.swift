//
//  ___FILEHEADER___
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - ___VARIABLE_sceneName___ViewController

final class ___VARIABLE_sceneName___ViewController: UIHostingController<___VARIABLE_sceneName___ContainerView>, ___VARIABLE_sceneName___Scene {
    
    private let viewModel: ___VARIABLE_sceneName___ViewModel
    private let viewAppearance: ViewAppearance
    
//    var interactor: ___VARIABLE_sceneName___SceneInteractor? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: ___VARIABLE_sceneName___ViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = ___VARIABLE_sceneName___ContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}