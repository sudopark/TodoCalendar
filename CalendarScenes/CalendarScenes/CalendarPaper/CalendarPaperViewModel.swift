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
    func prepare()
    
    // presenter
}


// MARK: - CalendarPaperViewModelImple

final class CalendarPaperViewModelImple: CalendarPaperViewModel, @unchecked Sendable {
    
    // TODO: 삭제 예정
    private let month: CalendarMonth
    
    var router: CalendarPaperRouting?
    private var monthInteractor: MonthSceneInteractor?
    private var eventListInteractor: DayEventListSceneInteractor?
    
    init(month: CalendarMonth) {
        self.month = month
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - CalendarPaperViewModelImple Interactor

extension CalendarPaperViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            // TODO: attach childs
            let interactors = self.router?.attachMonthAndEventList(self.month) ?? nil
            self.monthInteractor = interactors?.0
            self.eventListInteractor = interactors?.1
        }
    }
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        self.monthInteractor?.updateMonthIfNeed(newMonth)
    }
}


// MARK: - CalendarPaperViewModelImple Presenter

extension CalendarPaperViewModelImple {
    
}
