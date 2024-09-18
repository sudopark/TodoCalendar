//
//  ___FILEHEADER___
//

import UIKit
import Combine
import Scenes
import CommonPresentation


// MARK: - ___VARIABLE_sceneName___ViewController

final class ___VARIABLE_sceneName___ViewController: UIViewController, ___VARIABLE_sceneName___Scene {
    
    private let viewModel: any ___VARIABLE_sceneName___ViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any ___VARIABLE_sceneName___SceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any ___VARIABLE_sceneName___ViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        super.loadView()
        self.setupLayout()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.bind()
    }
}

// MARK: - bind

extension ___VARIABLE_sceneName___ViewController {
    
    private func bind() {
     
        self.viewAppearance.didUpdated
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tuple in
                self?.setupStyling(tuple.1, tuple.2)
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - setup presenting

extension ___VARIABLE_sceneName___ViewController {
    
    
    private func setupLayout() {
        
    }
    
    private func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.view.backgroundColor = colorSet.dayBackground
    }
}
