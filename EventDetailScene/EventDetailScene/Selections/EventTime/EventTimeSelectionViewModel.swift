//
//  
//  EventTimeSelectionViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - EventTimeSelectionViewModel

protocol EventTimeSelectionViewModel: AnyObject, Sendable, EventTimeSelectionSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - EventTimeSelectionViewModelImple

final class EventTimeSelectionViewModelImple: EventTimeSelectionViewModel, @unchecked Sendable {
    
    var router: (any EventTimeSelectionRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventTimeSelectionViewModelImple Interactor

extension EventTimeSelectionViewModelImple {
    
}


// MARK: - EventTimeSelectionViewModelImple Presenter

extension EventTimeSelectionViewModelImple {
    
}
