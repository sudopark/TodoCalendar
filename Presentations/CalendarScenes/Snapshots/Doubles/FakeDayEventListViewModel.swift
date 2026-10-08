//
//  FakeDayEventListViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import CommonPresentation

@testable import CalendarScenes
import CalendarPresentation


/// DayEventListViewState의 필드가 fileprivate라 state를 직접 채울 수 없어
/// production의 bind(viewModel:appearance:) 경로로 상태를 주입하기 위한 최소 스텁.
final class FakeDayEventListViewModel: DayEventListViewModel, @unchecked Sendable {

    private let dayModel: SelectedDayModel
    private let foremostModel: (any EventCellViewModel)?
    private let uncompletedModels: [TodoEventCellViewModel]
    private let cellModels: [any EventCellViewModel]
    private let stubAIAgentState: AIAgentState

    init(
        dayModel: SelectedDayModel,
        foremostModel: (any EventCellViewModel)? = nil,
        uncompletedModels: [TodoEventCellViewModel] = [],
        cellModels: [any EventCellViewModel],
        aiAgentState: AIAgentState = .idle
    ) {
        self.dayModel = dayModel
        self.foremostModel = foremostModel
        self.uncompletedModels = uncompletedModels
        self.cellModels = cellModels
        self.stubAIAgentState = aiAgentState
    }

    // 스냅샷 카탈로그는 AI 상태 화면까지 캡처해야 하므로 항상 노출

    var foremostEventModel: AnyPublisher<(any EventCellViewModel)?, Never> {
        Just(self.foremostModel).eraseToAnyPublisher()
    }
    var uncompletedTodoEventModels: AnyPublisher<[TodoEventCellViewModel], Never> {
        Just(self.uncompletedModels).eraseToAnyPublisher()
    }
    var selectedDay: AnyPublisher<SelectedDayModel, Never> {
        Just(self.dayModel).eraseToAnyPublisher()
    }
    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        Just(self.cellModels).eraseToAnyPublisher()
    }
    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        Just(.idle).eraseToAnyPublisher()
    }
    var aiAgentState: AnyPublisher<AIAgentState, Never> {
        Just(self.stubAIAgentState).eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        Just("").eraseToAnyPublisher()
    }
    var voiceLevel: AnyPublisher<Float, Never> {
        Just(0).eraseToAnyPublisher()
    }

    var isShowReturnToToday: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    func selectedDayChanaged(_ newDay: CurrentSelectDayModel, and eventThatDay: [any CalendarEvent]) { }
    func selectedDayIsToday(_ isToday: Bool) { }
    func addNewTodoQuickly(withName: String) { }
    func makeTodoEvent(with givenName: String) { }
    func makeEvent() { }
    func makeEventByTemplate() { }
    func showDoneTodoList() { }
    func showSharePreview() { }
    func refreshUncompletedTodoEvents() { }
    func enterVoiceInput() { }
    func finishVoiceInput() { }
    func enterKeyboardInput() { }
    func enterImageInput() { }
    func stopAIAgentInput() { }
    func submitAIAgent(_ text: String) { }
    func handleAIEntryButtonTap() { }
    func showAIGuide() { }
    func returnToToday() { }
    func attachListener(_ listener: any DayEventListSceneListener) { }
}
