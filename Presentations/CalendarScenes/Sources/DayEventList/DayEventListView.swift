//
//
//  DayEventListView.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//


import SwiftUI
import Combine
import AudioToolbox
import Prelude
import Optics
import Domain
import Scenes
import Extensions
import CommonPresentation


// MARK: - AICommandBadge

private enum AICommandBadge: Equatable {
    case processing
    case needConfirm
    case done
    case failed
}


// MARK: - DayEventListViewController

@Observable final class DayEventListViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    fileprivate var foremostModel: (any EventCellViewModel)?
    fileprivate var uncompletedTodos: [TodoEventCellViewModel] = []
    fileprivate var dayModel: SelectedDayModel?
    fileprivate var cellViewModels: [any EventCellViewModel] = []
    fileprivate var foremostEventMarkingStatus: ForemostMarkingStatus = .idle
    fileprivate var aiAgentState: AIAgentState = .idle
    fileprivate var recognizingText: String = ""
    fileprivate var voiceLevel: Float = 0

    fileprivate var isListening: Bool {
        if case .listening = aiAgentState { return true }
        return false
    }

    fileprivate var isAIIdle: Bool {
        if case .idle = aiAgentState { return true }
        return false
    }

    fileprivate var aiCommandBadge: AICommandBadge? {
        switch self.aiAgentState {
        case .processing: return .processing
        case .confirm: return .needConfirm
        case .done: return .done
        case .failed: return .failed
        case .idle, .listening: return nil
        }
    }

    func bind(_ viewModel: any DayEventListViewModel, _ appearance: ViewAppearance) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.foremostEventModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] model in
                appearance?.withAnimationIfNeed {
                    self?.foremostModel = model
                }
            })
            .store(in: &self.cancellables)

        viewModel.uncompletedTodoEventModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] models in
                appearance?.withAnimationIfNeed {
                    self?.uncompletedTodos = models
                }
            })
            .store(in: &self.cancellables)

        viewModel.selectedDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.dayModel = model
            })
            .store(in: &self.cancellables)

        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] cellViewModels in
                appearance?.withAnimationIfNeed {
                    self?.cellViewModels = cellViewModels
                }
            })
            .store(in: &self.cancellables)

        viewModel.foremostEventMarkingStatus
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] status in
                appearance?.withAnimationIfNeed {
                    self?.foremostEventMarkingStatus = status
                }
            })
            .store(in: &self.cancellables)

        viewModel.aiAgentState
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] state in
                self?.aiAgentState = state
            })
            .store(in: &self.cancellables)

        viewModel.recognizingText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.recognizingText = text }
            .store(in: &self.cancellables)

        viewModel.voiceLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in self?.voiceLevel = level }
            .store(in: &self.cancellables)
    }
}


final class DayEventListViewEventHandler: Observable {
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestAddNewEventWhetherUsingTemplate: (Bool) -> Void = { _ in }
    var addNewTodoQuickly: (String) -> Void = { _ in }
    var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var showDoneTodoList: () -> Void = { }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    var refreshUncompletedTodos: () -> Void = { }
    var enterVoiceInput: () -> Void = { }
    var finishVoiceInput: () -> Void = { }
    var enterKeyboardInput: () -> Void = { }
    var stopAIAgentInput: () -> Void = { }
    var submitAIAgent: (String) -> Void = { _ in }
    var handleAIEntryButtonTap: () -> Void = { }
    var showAIGuide: () -> Void = { }

    func bind(
        _ viewModel: any DayEventListViewModel,
        _ eventListCellEventHandleViewModel: any EventListCellEventHanleViewModel
    ) {
        self.requestDoneTodo = eventListCellEventHandleViewModel.doneTodo(_:)
        self.requestCancelDoneTodo = eventListCellEventHandleViewModel.cancelDoneTodo(_:)
        self.requestAddNewEventWhetherUsingTemplate = { use in
            if use { viewModel.makeEventByTemplate() }
            else { viewModel.makeEvent() }
        }
        self.addNewTodoQuickly = viewModel.addNewTodoQuickly(withName:)
        self.makeNewTodoWithGivenNameAndDetails = viewModel.makeTodoEvent(with:)
        self.requestShowDetail = eventListCellEventHandleViewModel.selectEvent(_:)
        self.showDoneTodoList = viewModel.showDoneTodoList
        self.handleMoreAction = eventListCellEventHandleViewModel.handleMoreAction(_:_:)
        self.refreshUncompletedTodos = viewModel.refreshUncompletedTodoEvents
        self.enterVoiceInput = viewModel.enterVoiceInput
        self.finishVoiceInput = viewModel.finishVoiceInput
        self.enterKeyboardInput = viewModel.enterKeyboardInput
        self.stopAIAgentInput = viewModel.stopAIAgentInput
        self.submitAIAgent = viewModel.submitAIAgent(_:)
        self.handleAIEntryButtonTap = viewModel.handleAIEntryButtonTap
        self.showAIGuide = viewModel.showAIGuide
    }
}


// MARK: - DayEventListContainerView

struct DayEventListContainerView: View {

    @State private var state: DayEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: DayEventListViewEventHandler
    private let pendingDoneState: PendingCompleteTodoState

    var stateBinding: (DayEventListViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandler: DayEventListViewEventHandler,
        pendingDoneState: PendingCompleteTodoState
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
        self.pendingDoneState = pendingDoneState
    }

    var body: some View {
        return DayEventListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environment(state)
            .environment(pendingDoneState)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}

// MARK: - DayEventListView

struct DayEventListView: View {

    @Environment(DayEventListViewState.self) private var state
    @Environment(PendingCompleteTodoState.self) private var pendingDoneState
    @Environment(DayEventListViewEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance
    @FocusState var isFocusInput: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.large) {

            if let foremost = self.state.foremostModel {
                self.foremostSectionView(foremost)
            }

            if !self.state.uncompletedTodos.isEmpty {
                self.uncompletedTodosSectionView(self.state.uncompletedTodos)
            }

            // 날짜 및 이벤트 목록
            VStack(alignment: .leading, spacing: Metric.Spacing.small) {

                // 상단 날짜 표시 헤더
                self.dateInfoView()

                // 이벤트 리스트
                self.eventListView()

                VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                    QuickAddNewTodoView(isFocusInput: $isFocusInput)
                        .eventHandler(\.addNewTodoQuickly, eventHandler.addNewTodoQuickly)
                        .eventHandler(\.makeNewTodoWithGivenNameAndDetails, eventHandler.makeNewTodoWithGivenNameAndDetails)
                    addNewButton()
                }
                .animation(.easeInOut(duration: 0.3), value: self.state.isListening)
            }
        }
        .onTapGesture {
            self.isFocusInput = false
        }
        .padding()
        .background(self.appearance.colorSet.bg0.asColor)
        .onChange(of: self.state.isListening) { _, listening in
            // listening on/off 전환에 반대되는 세기의 햅틱 + 녹음 시작/종료 시스템 사운드.
            self.appearance.impactIfNeed(listening ? .medium : .soft)
            AudioServicesPlaySystemSound(listening ? 1113 : 1114)
        }
    }

    private func addNewButton() -> some View {
        return HStack {
            Button {
                self.eventHandler.requestAddNewEventWhetherUsingTemplate(false)
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .tint(self.appearance.colorSet.text0.asColor)
                    Text(R.String.calednarEventAddNew)
                        .font(
                            self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text0.asColor)
                    Spacer()
                }
                .padding(.leading, spacing: .large)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .backgroundAsRoundedRectForEventList(self.appearance)
            }

            // TODO: 템플릿 추가버튼 임시 비활성화
//            Button {
//                self.eventHandler.requestAddNewEventWhetherUsingTemplate(true)
//            } label: {
//                Image(systemName: "list.bullet.clipboard")
//                    .tint(self.appearance.colorSet.text0.asColor)
//                    .frame(width: 50, height: 50)
//                    .backgroundAsRoundedRectForEventList(self.appearance)
//            }
        }
    }

    private func foremostSectionView(_ foremost: any EventCellViewModel) -> some View {
        ForemostEventView(viewModel: foremost, foremostEventMarkingStatus: state.foremostEventMarkingStatus)
            .eventHandler(\.requestDoneTodo) {
                self.isFocusInput = false
                eventHandler.requestDoneTodo($0)
            }
            .eventHandler(\.requestCancelDoneTodo) {
                self.isFocusInput = false
                eventHandler.requestCancelDoneTodo($0)
            }
            .eventHandler(\.requestShowDetail) {
                self.isFocusInput = false
                eventHandler.requestShowDetail($0)
            }
            .eventHandler(\.handleMoreAction) {
                self.isFocusInput = false
                eventHandler.handleMoreAction($0, $1)
            }
    }

    private func uncompletedTodosSectionView(_ models: [TodoEventCellViewModel]) -> some View {
        UncompletedTodoView(models, state.foremostEventMarkingStatus)
            .eventHandler(\.requestDoneTodo) {
                self.isFocusInput = false
                eventHandler.requestDoneTodo($0)
            }
            .eventHandler(\.requestCancelDoneTodo) {
                self.isFocusInput = false
                eventHandler.requestCancelDoneTodo($0)
            }
            .eventHandler(\.requestShowDetail) {
                self.isFocusInput = false
                eventHandler.requestShowDetail($0)
            }
            .eventHandler(\.handleMoreAction) {
                self.isFocusInput = false
                eventHandler.handleMoreAction($0, $1)
            }
            .eventHandler(\.refreshList) {
                self.isFocusInput = false
                self.appearance.impactIfNeed()
                eventHandler.refreshUncompletedTodos()
            }
    }

    private func dateInfoView() -> some View {
        VStack(alignment: .leading) {

            if let holidayName = self.state.dayModel?.holidayName, self.appearance.showHoliday {
                Text(holidayName)
                    .font(appearance.eventSubNormalTextFontOnList().asFont)
                    .foregroundStyle(appearance.colorSet.holidayOrWeekEndWithAccent.asColor)
            }

            // 상단 날짜표시 헤더 - 날짜 및 음력 표시
            HStack {

                Text(self.state.dayModel?.dateText ?? "")
                    .font(self.appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont)
                    .foregroundColor(self.appearance.colorSet.text0.asColor)


                if self.appearance.showLunarCalendarDate {
                    Text(self.state.dayModel?.lunarDateText ?? "")
                        .font(
                            self.appearance.fontSet.size(20+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text2.asColor)
                }

                Spacer()

                Button {
                    self.isFocusInput = false
                    self.eventHandler.showDoneTodoList()
                } label: {
                    Image(systemName: "checklist.checked")
                }
            }
            .padding(.bottom, spacing: .xsmall)
        }
    }

    private func eventListView() -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            ForEach(self.state.cellViewModels, id: \.eventIdentifier) { cellViewModel in

                EventListCellView(cellViewModel: cellViewModel, foremostEventMarkingStatus: state.foremostEventMarkingStatus)
                    .eventHandler(\.requestDoneTodo) {
                        self.isFocusInput = false
                        eventHandler.requestDoneTodo($0)
                    }
                    .eventHandler(\.requestCancelDoneTodo) {
                        self.isFocusInput = false
                        eventHandler.requestCancelDoneTodo($0)
                    }
                    .eventHandler(\.requestShowDetail) {
                        self.isFocusInput = false
                        eventHandler.requestShowDetail($0)
                    }
                    .eventHandler(\.handleMoreAction) {
                        self.isFocusInput = false
                        eventHandler.handleMoreAction($0, $1)
                    }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct QuickAddNewTodoView: View {

    @Environment(DayEventListViewState.self) private var state
    @Environment(DayEventListViewEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance

    @State private var newTodoName: String = ""
    @FocusState.Binding var isFocusInput: Bool
    private var isEntering: Bool { !self.newTodoName.isEmpty }

    private func resetStates() {
        self.newTodoName = ""
        self.isFocusInput = false
    }

    fileprivate var addNewTodoQuickly: (String) -> Void = { _ in }
    fileprivate var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }

    // 입력 전 todo 필드만 흐리게. AI 진입 버튼은 딤 대상 아님.
    private var inputDimOpacity: Double {
        (self.state.isListening || self.isEntering) ? 1.0 : 0.5
    }

    var body: some View {
        quickAddField()
            .padding(.vertical, spacing: .xsmall).padding(.horizontal, spacing: .small)
            .frame(height: 50)
            .backgroundAsRoundedRectForEventList(self.appearance)
            .overlay {
                if self.state.isListening {
                    NeonListeningBorder(cornerRadius: 5)
                        .transition(.opacity)
                }
            }
    }

    private func quickAddField() -> some View {
        HStack(spacing: Metric.Spacing.small) {

            self.leadingLabel()
                .frame(width: 52)
                .opacity(self.inputDimOpacity)

            if self.state.isListening {
                self.listeningContent()
            } else {
                self.defaultContent()
            }
        }
    }

    @ViewBuilder
    private func leadingLabel() -> some View {
        if self.state.isListening {
            // pill + 테두리로 "누르면 설명" affordance. 탭 시 안내 표시.
            Button {
                self.eventHandler.showAIGuide()
            } label: {
                HStack(alignment: .center, spacing: 3) {
                    Text("AI")
                        .font(
                            self.appearance.fontSet.size(12, weight: .bold).asFont
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                }
                .minimumScaleFactor(0.7)
                .foregroundColor(self.appearance.colorSet.text0.asColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(self.appearance.colorSet.accentAI.withAlphaComponent(0.15).asColor)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(self.appearance.colorSet.accentAI.asColor.opacity(0.6), lineWidth: 1)
                )
            }
        } else {
            Text(R.String.calendarEventTimeTodo)
                .minimumScaleFactor(0.7)
                .font(
                    self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                )
                .foregroundColor(self.appearance.colorSet.text0.asColor)
        }
    }

    // 평소: 색상바 + todo 직접 입력 + AI 음성 진입 버튼
    private func defaultContent() -> some View {
        HStack(spacing: Metric.Spacing.small) {
            HStack(spacing: Metric.Spacing.small) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(self.appearance.tagColors.defaultColor.asColor)
                    .frame(width: 6)

                self.todoInputField()
            }
            .opacity(self.inputDimOpacity)

            AIAgentEntryButton(badge: self.state.aiCommandBadge) {
                self.isFocusInput = false
                self.eventHandler.handleAIEntryButtonTap()
            }
        }
    }

    // listening: WAVE + 키보드 전환 + 중지 + 전송
    private func listeningContent() -> some View {
        HStack(spacing: 8) {
            VoiceWaveformView(
                level: self.state.voiceLevel,
                tintColor: self.appearance.colorSet.text1.asColor
            )
            .frame(maxWidth: .infinity)

            self.circleControlButton(icon: "keyboard", isPrimary: false) {
                self.eventHandler.enterKeyboardInput()
            }
            self.circleControlButton(icon: "stop.fill", isPrimary: false) {
                self.eventHandler.stopAIAgentInput()
            }
            self.circleControlButton(icon: "arrow.up", isPrimary: true) {
                self.eventHandler.finishVoiceInput()
            }
        }
    }

    private func circleControlButton(
        icon: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(
                    isPrimary
                    ? self.appearance.colorSet.accentAI.asColor
                    : self.appearance.colorSet.secondaryBtnBackground.asColor
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(
                            isPrimary
                            ? self.appearance.colorSet.primaryBtnText.asColor
                            : self.appearance.colorSet.secondaryBtnText.asColor
                        )
                )
        }
    }

    private func todoInputField() -> some View {
        HStack(spacing: Metric.Spacing.small) {
            TextField(
                "",
                text: $newTodoName,
                prompt: Text(
                    R.String.calednarEventAddNewPlaceHolder
                ).foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .focused($isFocusInput, equals: true)
            .autocorrectionDisabled()
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
            .textInputAutocapitalization(.never)
            .onSubmit {
                guard !self.newTodoName.isEmpty else { return }
                self.addNewTodoQuickly(self.newTodoName)
                self.resetStates()
            }
            .submitLabel(.done)

            if !self.newTodoName.isEmpty {
                Button {
                    let newName = self.newTodoName
                    self.resetStates()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.makeNewTodoWithGivenNameAndDetails(newName)
                    }
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }

}


// MARK: - NeonListeningBorder

// listening 중 입력창을 감싸는 네온 그라데이션 테두리. Siri 입력처럼 색이 흐른다.
private struct NeonListeningBorder: View {

    let cornerRadius: CGFloat

    private var neonColors: [Color] {
        [0xbd93f9, 0xff79c6, 0x8be9fd, 0x6272a4, 0xbd93f9]
            .map { UIColor(rgb: $0).asColor }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t * 70).truncatingRemainder(dividingBy: 360))
            RoundedRectangle(cornerRadius: self.cornerRadius)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: self.neonColors),
                        center: .center,
                        angle: angle
                    ),
                    lineWidth: 2
                )
                .shadow(color: UIColor(rgb: 0xbd93f9).asColor.opacity(0.5), radius: 4)
        }
    }
}


// MARK: - AIAgentEntryButton

private struct AIAgentEntryButton: View {

    @Environment(ViewAppearance.self) private var appearance

    let badge: AICommandBadge?
    var onTap: () -> Void = { }

    var body: some View {
        Button {
            self.onTap()
        } label: {
            Circle()
                .fill(self.appearance.colorSet.accentAI.asColor)
                .frame(width: 36, height: 36)
                .overlay { self.entryButtonIcon() }
                .overlay(alignment: .topTrailing) {
                    if let badge = self.badge, badge != .processing {
                        self.badgeView(badge)
                    }
                }
        }
    }

    @ViewBuilder
    private func entryButtonIcon() -> some View {
        if self.badge == .processing {
            LoadingCircleView(self.appearance.colorSet.primaryBtnText.asColor, lineWidth: 2)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "sparkles")
                .foregroundColor(self.appearance.colorSet.primaryBtnText.asColor)
        }
    }

    private func badgeView(_ badge: AICommandBadge) -> some View {
        let style = self.badgeStyle(badge)
        return Image(systemName: style.symbol)
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(style.color)
            .frame(width: 18, height: 18)
            .background(Circle().fill(self.appearance.colorSet.bg0.asColor))
            .overlay(Circle().stroke(style.color, lineWidth: 1.5))
            .offset(x: 5, y: -5)
    }

    private func badgeStyle(_ badge: AICommandBadge) -> (symbol: String, color: Color) {
        switch badge {
        case .processing, .needConfirm:
            return ("questionmark", self.appearance.colorSet.accentInfo.asColor)
        case .done:
            return ("checkmark", self.appearance.colorSet.accent.asColor)
        case .failed:
            return ("exclamationmark", self.appearance.colorSet.accentWarn.asColor)
        }
    }
}


// MARK: - preview

struct DayEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
//        viewAppearance.eventTextAdditionalSize = 4
        viewAppearance.showHoliday = true
        viewAppearance.showLunarCalendarDate = true
        let state = DayEventListViewState()
        state.dayModel = .init(dateText: "2020년 9월 15일(금)", lunarDateText: "6월 4일")
        state.dayModel?.holidayName = "크리스마스"
        let cells = self.makeDummyCells()
        state.cellViewModels = cells
        state.foremostModel = cells.randomElement()
        state.uncompletedTodos = self.dummyUncompleteds()
        state.foremostEventMarkingStatus = .unmarking
        let eventHandler = DayEventListViewEventHandler()
        eventHandler.requestDoneTodo = { id in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // 완료처리 실패하게 하던지
                withAnimation {
//                    state.requestDoneTodoIds = []

                    // 혹은 완료처리 성공 이후 셀 목록 업데이트 시뮬레이션
                    let newCells = state.cellViewModels.filter { $0.todoEventId != id }
                    state.cellViewModels = newCells
                }
            }
        }
        eventHandler.addNewTodoQuickly = { name in
            let pending = PendingTodoEventCellViewModel(name: name, defaultTagId: nil)
            let index = state.cellViewModels.firstIndex(where: { !$0.name.starts(with: "current todo") })!

            withAnimation {
                state.cellViewModels.insert(pending, at: index)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let index = state.cellViewModels.firstIndex(where: { $0.eventIdentifier == pending.eventIdentifier }) {
                        withAnimation {
                            // 삭제하여 실패했을때 가정
//                                state.cellViewModels.remove(at: index)

                            // 추가하여 성공했을때 가정
                            let newCell = TodoEventCellViewModel("new-current-todo", name: name)
                                |> \.periodText .~ .singleText(.init(text: "Todo".localized()))
                            state.cellViewModels[index] = newCell
                        }
                    }
                }
            }
        }
        let containerView = DayEventListView()
            .environment(state)
            .environment(eventHandler)
            .environment(PendingCompleteTodoState())
            .environment(viewAppearance)
        return containerView
    }

    private static func dummyUncompleteds() -> [TodoEventCellViewModel] {
        return [
            .init("uncompleted-todo1", name: "uncompleted - todo1")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "10:30", pmOram: "AM")
                ),
                .init("uncompleted-todo2", name: "uncompleted - todo2")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "9 (Sat)")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
        ]
    }

    private static func makeDummyCells() -> [any EventCellViewModel] {
        let currentTodoCells: [TodoEventCellViewModel] = [
            .init("current-todo1", name: "current todo 1")
                |> \.periodText .~ .singleText(.init(text: "Todo".localized())),
            .init("current-todo2", name: "current todo 2")
                |> \.periodText .~ .singleText(.init(text: "Todo".localized()))
        ]
        let todoCells: [TodoEventCellViewModel] = [
//            .init(eventId: .todo("todo1"), name: "todo with anyTime")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .anyTime,
//            .init("todo2", name: "todo with all day")
//                |> \.tagColor .~ .default
//                |> \.periodText .~ .doubleText(
//                    .init(text: "Todo".localized()),
//                    .init(text: "Allday")
//                ),
            .init("todo3", name: "todo with at time")
                |> \.isForemost .~ true
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "10:30", pmOram: "AM")
                )
                |> \.isRepeating .~ true,
//            .init(eventId: .todo("todo4"), name: "todo with in today")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .inToday("9:30", "20:30")
//                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
            .init("todo5", name: "todo with today to future")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "9 (Sat)")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init("todo6", name: "todo with past to today")
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "20:00")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        let scheduleCells: [ScheduleEventCellViewModel] = [
            .init("sc1", name: "schdule with at time")
                |> \.periodText .~ .singleText(
                    .init(text: "8:30", pmOram: "AM")
                ),
            .init("sc2", name: "schdule with all day")
                |> \.periodText .~ .singleText(
                    .init(text: "Allday".localized())
                ),
//            .init(eventId: .schedule("sc3", turn: 1), name: "schdule with at time")
//            |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .atTime("10:30"),
            .init("sc4", name: "schdule with in today")
                |> \.periodText .~ .doubleText(
                    .init(text: "9:30", pmOram: "AM"),
                    .init(text: "8:30", pmOram: "PM")
                )
                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
//            .init(eventId: .schedule("sc5", turn: 1), name: "schdule with today to future")
//            |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .fromTodayToFuture("09:30", "9 (Sat)")
//                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init("sc6", name: "schdule with past to today")
                |> \.periodText .~ .doubleText(
                    .init(text: "9 (Sat)"),
                    .init(text: "20:00")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]

        let holidayCell = HolidayEventCellViewModel(
            HolidayCalendarEvent(.init(uuid: "hd", dateString: "2023-09-30", name: "추석"), in: TimeZone.current)!
        )

        let google = GoogleCalendar.Event("some", "cal", accountId: "preview@gmail.com", name: "google event", colorId: "colorId", time: .at(100))
        let googleEvent = GoogleCalendarEvent(google, in: TimeZone.current)
        let googleCell = GoogleCalendarEventCellViewModel(googleEvent, in: 0..<200, TimeZone.current, true)

        let basicCells: [any EventCellViewModel] = currentTodoCells + scheduleCells
//        + todoCells
        return basicCells + [holidayCell] + [googleCell!]
//        .shuffled()
    }
}


// MARK: - AI Command Badge Preview

struct DayEventListBadgePreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let eventHandler = DayEventListViewEventHandler()

        func makeView(state: DayEventListViewState, label: String) -> some View {
            DayEventListView()
                .environment(state)
                .environment(eventHandler)
                .environment(PendingCompleteTodoState())
                .environment(viewAppearance)
                .previewDisplayName(label)
        }

        let processingState = DayEventListViewState()
        processingState.aiAgentState = .processing(command: "내일 오전 9시 회의 추가")

        let confirmState = DayEventListViewState()
        confirmState.aiAgentState = .confirm(
            command: "내일 오전 9시 회의 추가",
            message: "확인이 필요합니다",
            action: AIConfirmCommandAction()
        )

        let doneState = DayEventListViewState()
        doneState.aiAgentState = .done(command: "회의 추가", message: "이벤트가 추가됐어요")

        let failedState = DayEventListViewState()
        failedState.aiAgentState = .failed(command: "회의 추가", reason: "처리 실패")

        let idleState = DayEventListViewState()

        return Group {
            makeView(state: processingState, label: "Badge - processing")
            makeView(state: confirmState, label: "Badge - confirm")
            makeView(state: doneState, label: "Badge - done")
            makeView(state: failedState, label: "Badge - failed")
            makeView(state: idleState, label: "Badge - idle (no badge)")
        }
    }
}


// MARK: - AIAgentInlineInputView Preview (listening state)

struct DayEventListInlineInputPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let eventHandler = DayEventListViewEventHandler()

        let listeningState = DayEventListViewState()
        listeningState.dayModel = .init(dateText: "2020년 9월 15일(금)", lunarDateText: "6월 4일")
        listeningState.aiAgentState = .listening(.voice)
        listeningState.voiceLevel = 0.0
        listeningState.recognizingText = "내일 오전 9시 회의 추가"

        return DayEventListView()
            .environment(listeningState)
            .environment(eventHandler)
            .environment(PendingCompleteTodoState())
            .environment(viewAppearance)
            .previewDisplayName("Inline input - listening")
    }
}
