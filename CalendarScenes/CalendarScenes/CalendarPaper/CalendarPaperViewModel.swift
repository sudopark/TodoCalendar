//
//  
//  CalendarPaperViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - CalendarPaperViewModel

protocol CalendarPaperViewModel: AnyObject, Sendable, CalendarPaperSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - CalendarPaperViewModelImple

final class CalendarPaperViewModelImple: CalendarPaperViewModel, @unchecked Sendable {
    
    var router: CalendarPaperRouting?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - CalendarPaperViewModelImple Interactor

extension CalendarPaperViewModelImple {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        // TODO: send update message to month scene
    }
}


// MARK: - CalendarPaperViewModelImple Presenter

extension CalendarPaperViewModelImple {
    
}
