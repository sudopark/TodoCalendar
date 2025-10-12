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
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


// MARK: - DayEventListViewController

@Observable final class DayEventListViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    fileprivate var foremostModel: (any EventCellViewModel)?
    fileprivate var uncompletedTodos: [TodoEventCellViewModel] = []
    fileprivate var dayModel: SelectedDayModel?
    fileprivate var cellViewModels: [any EventCellViewModel] = []
    fileprivate var foremostEventMarkingStatus: ForemostMarkingStatus = .idle
    
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
        VStack(alignment: .leading, spacing: 16) {
         
            if let foremost = self.state.foremostModel {
                self.foremostSectionView(foremost)
            }
            
            if !self.state.uncompletedTodos.isEmpty {
                self.uncompletedTodosSectionView(self.state.uncompletedTodos)
            }
         
            // 날짜 및 이벤트 목록
            VStack(alignment: .leading, spacing: 6) {
                
                // 상단 날짜 표시 헤더
                self.dateInfoView()
                
                // 이벤트 리스트
                self.eventListView()
                
                QuickAddNewTodoView(isFocusInput: $isFocusInput)
                    .eventHandler(\.addNewTodoQuickly, eventHandler.addNewTodoQuickly)
                    .eventHandler(\.makeNewTodoWithGivenNameAndDetails, eventHandler.makeNewTodoWithGivenNameAndDetails)
                
                addNewButton()
            }
        }
        .onTapGesture {
            self.isFocusInput = false
        }
        .padding()
        .background(self.appearance.colorSet.bg0.asColor)
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
                .padding(.leading, 16)
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
            .padding(.bottom, 3)
        }
    }
    
    private func eventListView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
    
    var body: some View {
        HStack(spacing: 8) {
            
            Text(R.String.calendarEventTimeTodo)
                .minimumScaleFactor(0.7)
                .font(
                    self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                )
                .foregroundColor(self.appearance.colorSet.text0.asColor)
                .frame(width: 52)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(self.appearance.tagColors.defaultColor.asColor)
                .frame(width: 6)
            
            HStack(spacing: 8) {
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
        .opacity(self.isEntering ? 1.0 : 0.5)
        .padding(.vertical, 4).padding(.horizontal, 8)
        .frame(height: 50)
        .backgroundAsRoundedRectForEventList(self.appearance)
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
        
        let google = GoogleCalendar.Event("some", "cal", name: "google event", colorId: "colorId", time: .at(100))
        let googleEvent = GoogleCalendarEvent(google, in: TimeZone.current)
        let googleCell = GoogleCalendarEventCellViewModel(googleEvent, in: 0..<200, TimeZone.current, true)
        
        let basicCells: [any EventCellViewModel] = currentTodoCells + scheduleCells
//        + todoCells
        return basicCells + [holidayCell] + [googleCell!]
//        .shuffled()
    }
}
