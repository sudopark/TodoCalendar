//
//  SharePreviewViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions


// MARK: - SharePreviewTagCellViewModel

struct SharePreviewTagCellViewModel: Equatable, Identifiable {
    let tagId: EventTagId
    let name: String
    var isOn: Bool
    var id: EventTagId { self.tagId }
}


// MARK: - SharePreviewViewModel

protocol SharePreviewViewModel: AnyObject, Sendable, SharePreviewSceneInteractor {

    // interactor
    func prepare()
    func toggleTagFilterExpanded()
    func toggleTag(_ tagId: EventTagId)
    func selectAllTags()
    func deselectAllTags()
    func toggleLine(_ eventId: String)
    func toggleIncludeTagName(_ newValue: Bool)
    func share()
    func close()

    // presenter
    var isTagFilterExpanded: AnyPublisher<Bool, Never> { get }
    var tagCellViewModels: AnyPublisher<[SharePreviewTagCellViewModel], Never> { get }
    var lineModels: AnyPublisher<[SharePreviewLineModel], Never> { get }
    var sectionModels: AnyPublisher<[SharePreviewSectionModel], Never> { get }
    var dateHeaderText: AnyPublisher<String, Never> { get }
    var includeTagName: AnyPublisher<Bool, Never> { get }
    var isShareEnabled: AnyPublisher<Bool, Never> { get }
}


// MARK: - SharePreviewViewModelImple

final class SharePreviewViewModelImple: SharePreviewViewModel, @unchecked Sendable {

    private let range: Range<TimeInterval>
    private let kind: CalendarShareRangeKind
    private let eventListUsecase: any CalendarEventListhUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventShareSettingUsecase: any EventShareSettingUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let appleCalendarUsecase: any AppleCalendarUsecase
    var router: (any SharePreviewRouting)?

    init(
        range: Range<TimeInterval>,
        kind: CalendarShareRangeKind,
        eventListUsecase: any CalendarEventListhUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventShareSettingUsecase: any EventShareSettingUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase
    ) {
        self.range = range
        self.kind = kind
        self.eventListUsecase = eventListUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventShareSettingUsecase = eventShareSettingUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.appleCalendarUsecase = appleCalendarUsecase
    }

    private struct Subject {
        let rawLines = CurrentValueSubject<[SharePreviewLineModel]?, Never>(nil)
        let knownTagIds = CurrentValueSubject<Set<EventTagId>, Never>([])
        let excludedEventIds = CurrentValueSubject<Set<String>, Never>([])
        let userTagOverrides = CurrentValueSubject<[EventTagId: Bool], Never>([:])
        let isTagFilterExpanded = CurrentValueSubject<Bool, Never>(false)
        let includeTagName = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


// MARK: - SharePreviewViewModelImple Interactor

extension SharePreviewViewModelImple {

    func prepare() {
        self.rawLineModelsPublisher
            .sink { [weak self] lines in
                self?.subject.rawLines.send(lines)
                self?.subject.knownTagIds.send(Set(lines.compactMap { $0.tagId }))
            }
            .store(in: &self.cancellables)

        self.subject.includeTagName.send(
            self.eventShareSettingUsecase.loadEventShareSetting().includeTagName
        )
    }

    func toggleTagFilterExpanded() {
        self.subject.isTagFilterExpanded.send(!self.subject.isTagFilterExpanded.value)
    }

    func toggleTag(_ tagId: EventTagId) {
        self.eventTagUsecase.offEventTagIdsOnCalendar()
            .first()
            .sink { [weak self] offTagIdsOnCalendar in
                guard let self else { return }
                let isCurrentlyOn = self.subject.userTagOverrides.value[tagId]
                    ?? !offTagIdsOnCalendar.contains(tagId)
                var overrides = self.subject.userTagOverrides.value
                overrides[tagId] = !isCurrentlyOn
                self.subject.userTagOverrides.send(overrides)
            }
            .store(in: &self.cancellables)
    }

    func selectAllTags() {
        self.subject.userTagOverrides.send(self.overrides(for: self.subject.knownTagIds.value, isOn: true))
    }

    func deselectAllTags() {
        self.subject.userTagOverrides.send(self.overrides(for: self.subject.knownTagIds.value, isOn: false))
    }

    func toggleLine(_ eventId: String) {
        var excludedIds = self.subject.excludedEventIds.value
        if excludedIds.contains(eventId) {
            excludedIds.remove(eventId)
        } else {
            excludedIds.insert(eventId)
        }
        self.subject.excludedEventIds.send(excludedIds)
    }

    func toggleIncludeTagName(_ newValue: Bool) {
        do {
            let params = EditEventShareSettingsParams() |> \.includeTagName .~ newValue
            let updated = try self.eventShareSettingUsecase.changeEventShareSetting(params)
            self.subject.includeTagName.send(updated.includeTagName)
        } catch {
            self.router?.showError(error)
        }
    }

    func share() {
        Publishers.CombineLatest(self.lineModels, self.calendarSettingUsecase.currentTimeZone)
            .first()
            .sink { [weak self] lines, timeZone in
                guard let self else { return }
                let text = EventShareTextBuilder(timeZone: timeZone).build(
                    lines, in: self.range, kind: self.kind,
                    includeTagName: self.subject.includeTagName.value
                )
                guard !text.isEmpty else { return }
                self.router?.showShareSheet(text: text)
            }
            .store(in: &self.cancellables)
    }

    func close() {
        self.router?.closeScene()
    }

    private func overrides(for tagIds: Set<EventTagId>, isOn: Bool) -> [EventTagId: Bool] {
        return tagIds.reduce(into: [EventTagId: Bool]()) { acc, tagId in
            acc[tagId] = isOn
        }
    }
}


// MARK: - SharePreviewViewModelImple Presenter

extension SharePreviewViewModelImple {

    var isTagFilterExpanded: AnyPublisher<Bool, Never> {
        return self.subject.isTagFilterExpanded.eraseToAnyPublisher()
    }

    var tagCellViewModels: AnyPublisher<[SharePreviewTagCellViewModel], Never> {
        return Publishers.CombineLatest3(
            self.subject.rawLines.compactMap { $0 },
            self.eventTagUsecase.offEventTagIdsOnCalendar(),
            self.subject.userTagOverrides
        )
        .map(self.makeTagCellViewModels)
        .eraseToAnyPublisher()
    }

    var lineModels: AnyPublisher<[SharePreviewLineModel], Never> {
        return Publishers.CombineLatest4(
            self.subject.rawLines.compactMap { $0 },
            self.subject.excludedEventIds,
            self.eventTagUsecase.offEventTagIdsOnCalendar(),
            self.subject.userTagOverrides
        )
        .map(self.filteredLineModels)
        .eraseToAnyPublisher()
    }

    var sectionModels: AnyPublisher<[SharePreviewSectionModel], Never> {
        return Publishers.CombineLatest(
            self.lineModels, self.calendarSettingUsecase.currentTimeZone
        )
        .map { lines, timeZone in
            SharePreviewSectionComposer(timeZone: timeZone).sections(of: lines)
        }
        .eraseToAnyPublisher()
    }

    var dateHeaderText: AnyPublisher<String, Never> {
        return Publishers.CombineLatest(
            self.sectionModels, self.calendarSettingUsecase.currentTimeZone
        )
        .map { [range, kind] sections, timeZone in
            SharePreviewSectionComposer(timeZone: timeZone)
                .rangeHeaderText(of: sections, in: range, kind: kind)
        }
        .eraseToAnyPublisher()
    }

    var includeTagName: AnyPublisher<Bool, Never> {
        return self.subject.includeTagName.eraseToAnyPublisher()
    }

    var isShareEnabled: AnyPublisher<Bool, Never> {
        return self.lineModels
            .map { lines in lines.contains { !$0.isExcluded } }
            .eraseToAnyPublisher()
    }

    private var rawLineModelsPublisher: AnyPublisher<[SharePreviewLineModel], Never> {
        let rawLines = Publishers.CombineLatest4(
            self.eventListUsecase.allCalendarEvents(in: self.range),
            self.eventListUsecase.allCurrentTodoEvents(),
            self.calendarSettingUsecase.currentTimeZone,
            self.uiSettingUsecase.currentCalendarUISeting.map { !$0.is24hourForm }.removeDuplicates()
        )
        .map { [weak self, range] events, currentTodos, timeZone, isShort -> [SharePreviewLineModel] in
            guard let self else { return [] }
            return self.rawLineModels(
                events: events, currentTodos: currentTodos, range: range, timeZone: timeZone, isShort: isShort
            )
        }

        return rawLines
            .map { [eventTagUsecase, googleCalendarUsecase, appleCalendarUsecase] lines -> AnyPublisher<[SharePreviewLineModel], Never> in
                guard !lines.isEmpty else {
                    return Just(lines).eraseToAnyPublisher()
                }
                let tagIds = Array(Set(lines.compactMap { $0.tagId }).union([.default]))
                let customTagMap = eventTagUsecase.eventTags(tagIds)
                let externalTagMap = Publishers.CombineLatest(
                    googleCalendarUsecase.calendarTags.map { $0.map(ExternalCalendarEventTag.init) },
                    appleCalendarUsecase.calendarTags.map { $0.map(ExternalCalendarEventTag.init) }
                )
                .map { google, apple -> [EventTagId: any EventTag] in
                    (google + apple).reduce(into: [EventTagId: any EventTag]()) { acc, tag in acc[tag.tagId] = tag }
                }

                return Publishers.CombineLatest(customTagMap, externalTagMap)
                    .map { [weak self] customMap, externalMap -> [SharePreviewLineModel] in
                        guard let self else { return lines }
                        return self.resolveTags(lines, customMap.merging(externalMap) { current, _ in current })
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}


// MARK: - pure composition

extension SharePreviewViewModelImple {

    private func filteredLineModels(
        rawLines: [SharePreviewLineModel],
        excludedEventIds: Set<String>,
        offTagIdsOnCalendar: Set<EventTagId>,
        userTagOverrides: [EventTagId: Bool]
    ) -> [SharePreviewLineModel] {
        return rawLines.map { line in
            let isTagOff = line.tagId.map {
                self.isTagOff($0, offTagIdsOnCalendar: offTagIdsOnCalendar, userTagOverrides: userTagOverrides)
            } ?? false
            let isExcluded = isTagOff || excludedEventIds.contains(line.eventId)
            return line
                |> \.isExcluded .~ isExcluded
                |> \.isExcludedByTag .~ isTagOff
        }
    }

    private func makeTagCellViewModels(
        rawLines: [SharePreviewLineModel],
        offTagIdsOnCalendar: Set<EventTagId>,
        userTagOverrides: [EventTagId: Bool]
    ) -> [SharePreviewTagCellViewModel] {
        var seenTagIds = Set<EventTagId>()
        let uniqueTagLines = rawLines.compactMap { line -> (EventTagId, String)? in
            guard let tagId = line.tagId, seenTagIds.insert(tagId).inserted else { return nil }
            return (tagId, line.tagName ?? "")
        }
        return uniqueTagLines.map { tagId, name in
            let isOff = self.isTagOff(tagId, offTagIdsOnCalendar: offTagIdsOnCalendar, userTagOverrides: userTagOverrides)
            return SharePreviewTagCellViewModel(tagId: tagId, name: name, isOn: !isOff)
        }
    }

    private func isTagOff(
        _ tagId: EventTagId,
        offTagIdsOnCalendar: Set<EventTagId>,
        userTagOverrides: [EventTagId: Bool]
    ) -> Bool {
        if let overrideIsOn = userTagOverrides[tagId] {
            return !overrideIsOn
        }
        return offTagIdsOnCalendar.contains(tagId)
    }

    private func rawLineModels(
        events: [any CalendarEvent],
        currentTodos: [TodoCalendarEvent],
        range: Range<TimeInterval>,
        timeZone: TimeZone,
        isShort: Bool
    ) -> [SharePreviewLineModel] {
        // 반복 이벤트는 시리즈 전체가 range와 겹치면 모든 turn을 내보낸다(EventRepeating.isOverlap) —
        // 여기서 turn 단위로 다시 겹침을 재판정해야 범위 밖 회차가 섞이지 않는다.
        let overlappingEvents = events.filter { $0.eventTimeOnCalendar?.clamped(to: range) != nil }
        let currentTodoLines = currentTodos.sortedByCreateTime().map {
            SharePreviewLineModel($0, range: range, timeZone: timeZone, isShort: isShort)
        }
        let eventLines = overlappingEvents.sortedByEventTime().map {
            SharePreviewLineModel($0, range: range, timeZone: timeZone, isShort: isShort)
        }
        return currentTodoLines + eventLines
    }

    private func resolveTags(
        _ lines: [SharePreviewLineModel], _ tagMap: [EventTagId: any EventTag]
    ) -> [SharePreviewLineModel] {
        return lines.map { line in
            guard let tagId = line.tagId else { return line }
            let resolvedId = self.tagIdFallingBackToDefault(tagId, in: tagMap)
            return line
                |> \.tagId .~ resolvedId
                |> \.tagName .~ tagMap[resolvedId]?.name
        }
    }

    // 삭제된 커스텀 태그 이벤트는 앱 전반에서 기본 태그로 간주된다 (ViewAppearance.color(_:)).
    // externalCalendar는 별도 스트림이라 미도착과 미존재를 구분 못 해 폴백 대상이 아니다.
    private func tagIdFallingBackToDefault(
        _ tagId: EventTagId, in tagMap: [EventTagId: any EventTag]
    ) -> EventTagId {
        guard case .custom = tagId, tagMap[tagId] == nil else { return tagId }
        return .default
    }
}
