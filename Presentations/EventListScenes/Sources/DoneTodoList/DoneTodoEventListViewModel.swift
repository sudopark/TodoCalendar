//
//  
//  DoneTodoEventListViewModel.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


private struct TimeText {
    
    private let is24Form: Bool
    private let calendar: Calendar
    private let refDate: Date
    
    init(_ time: TimeInterval, _ timeZone: TimeZone, _ is24Form: Bool) {
        self.is24Form = is24Form
        self.calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        self.refDate = Date(timeIntervalSince1970: time)
    }
    
    func text(withTime: Bool) -> String {
        let dateText = self.dateText()
        guard withTime else { return dateText }
        let formatter = DateFormatter()
        formatter.dateFormat = is24Form ? "HH:mm".localized() : "a h:mm".localized()
        return "\(dateText) \(formatter.string(from: self.refDate))"
    }
    
    private func dateText() -> String {
        
        if self.calendar.isDateInToday(self.refDate) {
            return "today".localized()
        } else if self.calendar.isDateInYesterday(self.refDate) {
            return "yesterday".localized()
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd".localized()
            return formatter.string(from: refDate)
        }
    }
    
    func sectionGroupText() -> String {
        if calendar.isDateInToday(refDate) {
            return "today".localized()
        } else  if calendar.isDateInYesterday(refDate) {
            return "yesterday".localized()
        }
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let refDay = calendar.dateComponents([.year, .month, .day], from: refDate)
        if today.year == refDay.year && today.month == refDay.month {
            return "this month".localized()
        } else if today.year == refDay.year {
            return (DateFormatter() |> \.dateFormat .~ "MM".localized()).string(from: refDate)
        } else {
            return (DateFormatter() |> \.dateFormat .~ "yyyy".localized()).string(from: refDate)
        }
    }
}

struct DoneTodoCellViewModel {
    let uuid: String
    let name: String
    let eventTimeText: String?
    fileprivate let doneTime: TimeText
    let doneTimeText: String
    fileprivate let doneTimeSectionText: String
    
    init(_ event: DoneTodoEvent, _ timeZone: TimeZone, _ is24Form: Bool) {
        self.uuid = event.uuid
        self.name = event.name

        switch event.eventTime {
        case .none:
            self.eventTimeText = nil
        case .at(let time):
            self.eventTimeText = TimeText(time, timeZone, is24Form)
                .text(withTime: true)
        case .period(let range):
            let start = TimeText(range.lowerBound, timeZone, is24Form)
                .text(withTime: true)
            let end = TimeText(range.upperBound, timeZone, is24Form)
                .text(withTime: true)
            self.eventTimeText = "\(start) ~ \(end)"
        case .allDay(let range, let secondsFromGMT):
            let range = range.shiftting(secondsFromGMT, to: timeZone)
            let start = TimeText(range.lowerBound, timeZone, is24Form)
                .text(withTime: false)
            let end = TimeText(range.upperBound, timeZone, is24Form)
                .text(withTime: false)
            self.eventTimeText = "\(start) ~ \(end)"
        }
        let doneTime = TimeText(
            event.doneTime.timeIntervalSince1970, timeZone, is24Form
        )
        self.doneTime = doneTime
        self.doneTimeText = doneTime.text(withTime: true)
        self.doneTimeSectionText = doneTime.text(withTime: false)
    }
}

struct DoneTodoListSectionModel {
    let sectionTitle: String
    let sectionGroupTitle: String
    var cells: [DoneTodoCellViewModel] = []
    var shouldShowSectionGroupTitle: Bool = false
    
    fileprivate init(_ sectionTitle: String, _ cells: [DoneTodoCellViewModel]) {
        self.sectionTitle = sectionTitle
        self.cells = cells
        self.sectionGroupTitle = cells.first?.doneTime.sectionGroupText() ?? ""
    }
    
    private func append(_ cell: DoneTodoCellViewModel) -> Self {
        return self |> \.cells .~ (self.cells + [cell])
    }
    
    struct Builder {
        private let timeZone: TimeZone
        private let is24Form: Bool
        fileprivate init(_ timeZone: TimeZone, _ is24Form: Bool) {
            self.timeZone = timeZone
            self.is24Form = is24Form
        }
        
        func build(
            _ events: [DoneTodoEvent]
        ) -> [DoneTodoListSectionModel] {
            let cells = events.map { DoneTodoCellViewModel($0, timeZone, is24Form) }
            let sections = cells.reduce(into: [DoneTodoListSectionModel]()) { acc, cell in
                if acc.last?.sectionTitle != cell.doneTimeSectionText {
                    acc.append(
                        .init(cell.doneTimeSectionText, [cell])
                    )
                } else {
                    acc = acc |> ix(acc.count-1) %~ { $0.append(cell) }
                }
            }
            let sectionWithGroupTitle = sections.enumerated().map { index, section in
                if sections[safe: index-1]?.sectionGroupTitle != section.sectionGroupTitle {
                    return section |> \.shouldShowSectionGroupTitle .~ true
                } else {
                    return section
                }
            }
            return sectionWithGroupTitle
        }
    }
    
    static func builder(_ timeZone: TimeZone, _ is24Form: Bool) -> Builder {
        return .init(timeZone, is24Form)
    }
}

enum RemoveDoneTodoRange: CaseIterable {
    case all
    case olderThan3Months
    case olderThan6Months
    case olderThan1Year
    
    func scope(_ timeZone: TimeZone) -> RemoveDoneTodoScope? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        switch self {
        case .all: return .all
        case .olderThan3Months:
            let ref = calendar.addMonth(-3, from: Date())
            return ref.map { .pastThan($0.timeIntervalSince1970) }
        case .olderThan6Months:
            let ref = calendar.addMonth(-6, from: Date())
            return ref.map { .pastThan($0.timeIntervalSince1970) }
        case .olderThan1Year:
            let ref = calendar.addYear(-1, from: Date())
            return ref.map { .pastThan($0.timeIntervalSince1970) }
        }
    }
}

// MARK: - DoneTodoEventListViewModel

protocol DoneTodoEventListViewModel: AnyObject, Sendable, DoneTodoEventListSceneInteractor {

    // interactor
    func loadList()
    func loadMoreList()
    func revertDoneTodo(_ uuid: String)
    func cancelRevertDoneTodo(_ uuid: String)
    func removeDoneTodos()
    func close()
    
    // presenter
    var isRemovingTodos: AnyPublisher<Bool, Never> { get }
    var sectionModels: AnyPublisher<[DoneTodoListSectionModel], Never> { get }
}


// MARK: - DoneTodoEventListViewModelImple

final class DoneTodoEventListViewModelImple: DoneTodoEventListViewModel, @unchecked Sendable {
    
    private let todoUsecase: any TodoEventUsecase
    private let pagingUsecase: any DoneTodoEventsPagingUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any DoneTodoEventListRouting)?
    
    init(
        todoUsecase: any TodoEventUsecase,
        pagingUsecase: any DoneTodoEventsPagingUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.todoUsecase = todoUsecase
        self.pagingUsecase = pagingUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        
        self.internalBinding()
    }
    
    
    private struct Subject {
        let isRemovingTodos = CurrentValueSubject<Bool, Never>(false)
        let currentTimeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let revertedIdSet = CurrentValueSubject<Set<String>, Never>([])
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private var todoRevertingTasks: [String: Task<Void, any Error>] = [:]
    
    private func internalBinding() {
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] zone in
                self?.subject.currentTimeZone.send(zone)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - DoneTodoEventListViewModelImple Interactor

extension DoneTodoEventListViewModelImple {
 
    func loadList() {
        self.pagingUsecase.reload()
    }
    
    func loadMoreList() {
        self.pagingUsecase.loadMore()
    }
    
    func revertDoneTodo(_ uuid: String) {
        self.cancelRevertDoneTodo(uuid)
        self.todoRevertingTasks[uuid] = Task { [weak self] in
            do {
                _ = try await self?.todoUsecase.revertCompleteTodo(uuid)
                self?.insertAndUpdateReverted(uuid)
            } catch {
                self?.router?.showError(error)
            }
        }
    }
    
    private func insertAndUpdateReverted(_ uuid: String) {
        let newSet = self.subject.revertedIdSet.value <> [uuid]
        self.subject.revertedIdSet.send(newSet)
    }
    
    func cancelRevertDoneTodo(_ uuid: String) {
        self.todoRevertingTasks[uuid]?.cancel()
        self.todoRevertingTasks[uuid] = nil
    }
    
    func removeDoneTodos() {
        self.router?.showSelectRemoveDoneTodoRangePicker { [weak self] selected in
            self?.removeDoneTodos(selected)
        }
    }
    
    private func removeDoneTodos(_ selected: RemoveDoneTodoRange) {
        guard let timeZone = self.subject.currentTimeZone.value,
              let scope = selected.scope(timeZone)
        else { return }
        
        self.subject.isRemovingTodos.send(true)
        Task { [weak self] in
            do {
                try await self?.todoUsecase.removeDoneTodos(scope)
                self?.subject.isRemovingTodos.send(false)
                self?.loadList()
            } catch {
                self?.subject.isRemovingTodos.send(false)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - DoneTodoEventListViewModelImple Presenter

extension DoneTodoEventListViewModelImple {
    
    var isRemovingTodos: AnyPublisher<Bool, Never> {
        return self.subject.isRemovingTodos
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var sectionModels: AnyPublisher<[DoneTodoListSectionModel], Never> {
        
        let transform: ([DoneTodoEvent], TimeZone, Bool, Set<String>) -> [DoneTodoListSectionModel]
        transform = { events, timeZone, is24Form, reverted in
            let events = events.filter { !reverted.contains($0.uuid) }
            return DoneTodoListSectionModel.builder(timeZone, is24Form).build(events)
        }
        
        return Publishers.CombineLatest4(
            self.pagingUsecase.events.compactMap { $0 },
            self.subject.currentTimeZone.compactMap { $0 },
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.is24hourForm },
            self.subject.revertedIdSet
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
}
