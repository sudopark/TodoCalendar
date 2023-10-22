//
//  
//  SelectEventRepeatOptionViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - SelectEventRepeatOptionViewModel

protocol SelectEventRepeatOptionViewModel: AnyObject, Sendable, SelectEventRepeatOptionSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - SelectEventRepeatOptionViewModelImple

final class SelectEventRepeatOptionViewModelImple: SelectEventRepeatOptionViewModel, @unchecked Sendable {
    
    var router: (any SelectEventRepeatOptionRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SelectEventRepeatOptionViewModelImple Interactor

extension SelectEventRepeatOptionViewModelImple {
    
}


// MARK: - SelectEventRepeatOptionViewModelImple Presenter

extension SelectEventRepeatOptionViewModelImple {
    
}
