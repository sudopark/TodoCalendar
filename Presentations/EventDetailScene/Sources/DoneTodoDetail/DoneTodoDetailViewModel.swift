//
//  
//  DoneTodoDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - DoneTodoDetailViewModel

struct DoneAndOriginEventTimeModel: Equatable {
    let doneTime: String
    var eventTime: SelectedTime?
}

protocol DoneTodoDetailViewModel: AnyObject, Sendable, DoneTodoDetailSceneInteractor {

    // interactor
    func prepare()
    func revert()
    
    // presenter
    var eventName: AnyPublisher<String, Never> { get }
    var eventTag: AnyPublisher<SelectedTag?, Never> { get }
    var timeModel: AnyPublisher<DoneAndOriginEventTimeModel, Never> { get }
    var notificationTimeText: AnyPublisher<String?, Never> { get }
    var url: AnyPublisher<String?, Never> { get }
    var memo: AnyPublisher<String?, Never> { get }
    var placeModel: AnyPublisher<SelectedPlaceModel?, Never> { get }
    var isReverting: AnyPublisher<Bool, Never> { get }
}


// MARK: - DoneTodoDetailViewModelImple

final class DoneTodoDetailViewModelImple: DoneTodoDetailViewModel, @unchecked Sendable {
    
    private let uuid: String
    private let todoEventUsecase: any TodoEventUsecase
    private let doneDetailUsecase: any EventDetailDataUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any DoneTodoDetailRouting)?
    var listener: (any DoneTodoDetailSceneListener)?
    
    init(
        uuid: String,
        todoEventUsecase: any TodoEventUsecase,
        doneDetailUsecase: any EventDetailDataUsecase,
        eventTagUsecase: any EventTagUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uuid = uuid
        self.todoEventUsecase = todoEventUsecase
        self.doneDetailUsecase = doneDetailUsecase
        self.eventTagUsecase = eventTagUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    
    private struct Subject {
        let doneToddo = CurrentValueSubject<DoneTodoEvent?, Never>(nil)
        let doneTodoDetail = CurrentValueSubject<EventDetailData?, Never>(nil)
        let isReverting = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - DoneTodoDetailViewModelImple Interactor

extension DoneTodoDetailViewModelImple {
 
    func prepare() {
        
        self.todoEventUsecase.doneTodoEvent(self.uuid)
            .sink(receiveValue: { [weak self] done in
                self?.subject.doneToddo.send(done)
            }, receiveError: self.handleError())
            .store(in: &self.cancellables)
        
        self.doneDetailUsecase.loadDetail(self.uuid)
            .mapAsOptional()
            .catch { _ in Just(nil).eraseToAnyPublisher() }
            .sink(receiveValue: { [weak self] detail in
                self?.subject.doneTodoDetail.send(detail)
            })
            .store(in: &self.cancellables)
    }
    
    func revert() {
        guard !self.subject.isReverting.value else { return }
        self.subject.isReverting.send(true)
        
        let doneTodoId = self.uuid; let usecase = self.todoEventUsecase
        Task { [weak self] in
            
            do {
                let todo = try await usecase.revertCompleteTodo(doneTodoId)
                self?.subject.isReverting.send(false)
                self?.handleReverted(todo)
                
            } catch {
                self?.subject.isReverting.send(false)
                self?.handleError()(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func handleReverted(_ todo: TodoEvent) {
        let uuid = self.uuid
        self.router?.closeScene { [weak self] in
            self?.listener?.doneTodoDetail(revert: uuid, to: todo)
        }
    }
    
    private func handleError() -> (any Error) -> Void {
        return { [weak self] error in
            self?.router?.showError(error)
        }
    }
}


// MARK: - DoneTodoDetailViewModelImple Presenter

extension DoneTodoDetailViewModelImple {
    
    var eventName: AnyPublisher<String, Never> {
        return self.subject.doneToddo.compactMap { $0 }
            .map { $0.name }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventTag: AnyPublisher<SelectedTag?, Never> {
        let usecase = self.eventTagUsecase
        return self.subject.doneToddo.compactMap { $0 }
            .map { $0.eventTagId }
            .map { tagId -> AnyPublisher<(any EventTag)?, Never> in
                guard let tagId
                else {
                    return Just(nil).eraseToAnyPublisher()
                }
                return usecase.eventTag(id: tagId)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .map { t in t.map { SelectedTag($0)} }
            .eraseToAnyPublisher()
    }
    
    var timeModel: AnyPublisher<DoneAndOriginEventTimeModel, Never> {
        
        let transform: (DoneTodoEvent, TimeZone, Bool) -> DoneAndOriginEventTimeModel = { done, timeZone, is24Form in
            
            let selectTime = done.eventTime.map { SelectedTime($0, timeZone) }
            
            let formatter = DateFormatter()
            |> \.dateFormat .~ (is24Form ? "date_form:yyyy.MM_dd_hh:mm".localized() : "date_form:yyyy.MM_dd_h:mm".localized())
            
            return DoneAndOriginEventTimeModel(
                doneTime: formatter.string(from: done.doneTime),
                eventTime: selectTime
            )
        }
        
        return Publishers.CombineLatest3(
            self.subject.doneToddo.compactMap { $0 },
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var notificationTimeText: AnyPublisher<String?, Never> {
        let transform: (DoneTodoEvent) -> String? = { done in
            guard !done.notificationOptions.isEmpty else { return nil }
            let texts = done.notificationOptions.map { $0.text }
            return texts.andJoin()
        }
        return self.subject.doneToddo.compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var url: AnyPublisher<String?, Never> {
        return self.subject.doneTodoDetail.compactMap { $0 }
            .map { $0.url }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var memo: AnyPublisher<String?, Never> {
        return self.subject.doneTodoDetail.compactMap { $0 }
            .map { $0.memo }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var placeModel: AnyPublisher<SelectedPlaceModel?, Never> {
        let transform: (Place?) -> SelectedPlaceModel? = { place in
            guard let place, !place.placeName.isEmpty
            else { return nil }
            
            if let coordinate = place.coordinate {
                return .landmark(
                    .init(name: place.placeName, coordinate: coordinate, address: place.addressText)
                )
            } else {
                return .customPlace(place.placeName)
            }
        }
        
        return self.subject.doneTodoDetail.compactMap { $0 }
            .map { $0.place }
            .map(transform)
            .removeAllDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isReverting: AnyPublisher<Bool, Never> {
        return self.subject.isReverting
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
