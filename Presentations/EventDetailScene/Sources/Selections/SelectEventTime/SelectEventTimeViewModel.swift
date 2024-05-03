//
//  
//  SelectEventTimeViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - SelectEventTimeViewModel



protocol SelectEventTimeViewModel: AnyObject, Sendable, SelectEventTimeSceneInteractor {

    // interactor
    func removeEventTime()
    func toggleIsAllDay()
    func selectStartTime(_ date: Date)
    func selectEndTime(_ date: Date)
    func removeEndTime()
    func confirm()
    func close()
    
    // presenter
    var selectedTime: AnyPublisher<SelectedTime?, Never> { get }
    var isConfirmable: AnyPublisher<Bool, Never> { get }
}


// MARK: - SelectEventTimeViewModelImple

final class SelectEventTimeViewModelImple: SelectEventTimeViewModel, @unchecked Sendable {
    
    private let timeZone: TimeZone
    var router: (any SelectEventTimeRouting)?
    var listener: (any SelectEventTimeSceneListener)?
    
    init(
        startWith previousTime: SelectedTime?,
        at timeZone: TimeZone
    ) {
        self.timeZone = timeZone
        self.subject.selectedTime.send(previousTime)
    }
    
    
    private struct EventTimeAndTimeZone {
        let time: SelectedTime?
        let timeZone: TimeZone
    }
    
    private struct Subject {
        let selectedTime = CurrentValueSubject<SelectedTime??, Never>(nil)
        
        func mutateTimeIfPossible(
            _ mutating: (SelectedTime?) -> SelectedTime?
        ) {
            guard let old = self.selectedTime.value else { return }
            let new = mutating(old)
            self.selectedTime.send(new)
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SelectEventTimeViewModelImple Interactor

extension SelectEventTimeViewModelImple {

    
    func removeEventTime() {
        self.subject.mutateTimeIfPossible { _ in
            return nil
        }
    }
    
    func toggleIsAllDay() {
        self.subject.mutateTimeIfPossible {
            return $0?.toggleIsAllDay(self.timeZone)
        }
    }
    
    func selectStartTime(_ date: Date) {
        self.subject.mutateTimeIfPossible {
            return $0.periodStartChanged(date, self.timeZone)
        }
    }
    
    func selectEndTime(_ date: Date) {
        self.subject.mutateTimeIfPossible {
            return $0.periodEndTimeChanged(date, self.timeZone)
        }
    }
    
    func removeEndTime() {
        self.subject.mutateTimeIfPossible { old in
            guard let new = old.removePeriodEndTime(self.timeZone)
            else { return old }
            return new
        }
    }
    
    func confirm() {
        guard let time = self.subject.selectedTime.value,
              time?.isValid ?? true
        else { return }
        
        self.router?.closeScene()
        self.listener?.select(eventTime: time)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - SelectEventTimeViewModelImple Presenter

extension SelectEventTimeViewModelImple {
    
    var selectedTime: AnyPublisher<SelectedTime?, Never> {
        return self.subject.selectedTime
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isConfirmable: AnyPublisher<Bool, Never> {
        return self.subject.selectedTime
            .compactMap { $0 }
            .map { $0?.isValid ?? true }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
