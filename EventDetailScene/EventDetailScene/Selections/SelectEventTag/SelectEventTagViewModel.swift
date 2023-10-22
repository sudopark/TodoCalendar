//
//  
//  SelectEventTagViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - SelectEventTagViewModel

protocol SelectEventTagViewModel: AnyObject, Sendable, SelectEventTagSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - SelectEventTagViewModelImple

final class SelectEventTagViewModelImple: SelectEventTagViewModel, @unchecked Sendable {
    
    var router: (any SelectEventTagRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SelectEventTagViewModelImple Interactor

extension SelectEventTagViewModelImple {
    
}


// MARK: - SelectEventTagViewModelImple Presenter

extension SelectEventTagViewModelImple {
    
}
