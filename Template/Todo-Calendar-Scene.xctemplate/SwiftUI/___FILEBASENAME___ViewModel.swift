//
//  ___FILEHEADER___
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - ___VARIABLE_sceneName:identifier___ViewModel

protocol ___VARIABLE_sceneName___ViewModel: AnyObject, Sendable, ___VARIABLE_sceneName___SceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - ___VARIABLE_sceneName:identifier___ViewModelImple

final class ___VARIABLE_sceneName___ViewModelImple: ___VARIABLE_sceneName___ViewModel, @unchecked Sendable {
    
    var router: (any ___VARIABLE_sceneName___Routing)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - ___VARIABLE_sceneName:identifier___ViewModelImple Interactor

extension ___VARIABLE_sceneName___ViewModelImple {
    
}


// MARK: - ___VARIABLE_sceneName:identifier___ViewModelImple Presenter

extension ___VARIABLE_sceneName___ViewModelImple {
    
}
