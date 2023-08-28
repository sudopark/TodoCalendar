//
//  
//  DayEventListViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - DayEventListViewModel

protocol DayEventListViewModel: AnyObject, Sendable, DayEventListSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - DayEventListViewModelImple

final class DayEventListViewModelImple: DayEventListViewModel, @unchecked Sendable {
    
    var router: DayEventListRouting?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - DayEventListViewModelImple Interactor

extension DayEventListViewModelImple {
    
}


// MARK: - DayEventListViewModelImple Presenter

extension DayEventListViewModelImple {
    
}
