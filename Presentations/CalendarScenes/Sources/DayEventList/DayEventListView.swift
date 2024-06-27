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
import CommonPresentation


// MARK: - DayEventListViewController

final class DayEventListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published fileprivate var dayModel: SelectedDayModel?
    @Published fileprivate var cellViewModels: [any EventCellViewModel] = []
    @Published fileprivate var tempDoneTodoIds: Set<String> = []
    
    func bind(_ viewModel: any DayEventListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.selectedDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.dayModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] cellViewModels in
                withAnimation {
                    self?.cellViewModels = cellViewModels
                    self?.removeDoneTodoIdsFromTempDoneIds(from: cellViewModels)
                }
            })
            .store(in: &self.cancellables)
        
        viewModel.doneTodoFailed
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] todoId in
                withAnimation {
                    guard let self = self else { return }
                    self.tempDoneTodoIds = self.tempDoneTodoIds |> elem(todoId) .~ false
                }
            })
            .store(in: &self.cancellables)
    }
    
    private func removeDoneTodoIdsFromTempDoneIds(from cellViewModels: [any EventCellViewModel]) {
        let existingTodoIds = cellViewModels.compactMap { $0.todoEventId } |> Set.init
        self.tempDoneTodoIds = tempDoneTodoIds.intersection(existingTodoIds)
    }
}


final class DayEventListViewEventHandler: ObservableObject {
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestAddNewEventWhetherUsingTemplate: (Bool) -> Void = { _ in }
    var addNewTodoQuickly: (String) -> Void = { _ in }
    var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var showDoneTodoList: () -> Void = { }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    
    func bind(_ viewModel: any DayEventListViewModel) {
        self.requestDoneTodo = viewModel.doneTodo(_:)
        self.requestCancelDoneTodo = viewModel.cancelDoneTodo(_:)
        self.requestAddNewEventWhetherUsingTemplate = { use in
            if use { viewModel.makeEventByTemplate() }
            else { viewModel.makeEvent() }
        }
        self.addNewTodoQuickly = viewModel.addNewTodoQuickly(withName:)
        self.makeNewTodoWithGivenNameAndDetails = viewModel.makeTodoEvent(with:)
        self.requestShowDetail = viewModel.selectEvent(_:)
        self.showDoneTodoList = viewModel.showDoneTodoList
        self.handleMoreAction = viewModel.handleMoreAction(_:_:)
    }
}


// MARK: - DayEventListContainerView

struct DayEventListContainerView: View {
    
    @StateObject private var state: DayEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: DayEventListViewEventHandler
    
    var stateBinding: (DayEventListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandler: DayEventListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }
    
    var body: some View {
        return DayEventListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandler)
    }
}

// MARK: - DayEventListView

struct DayEventListView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandler: DayEventListViewEventHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            // 상단 날짜 표시 헤더
            VStack(alignment: .leading) {
                
                if let holidayName = self.state.dayModel?.holidayName, self.appearance.showHoliday {
                    Text(holidayName)
                        .font(appearance.eventSubNormalTextFontOnList().asFont)
                        .foregroundStyle(appearance.colorSet.calendarAccentColor.asColor)
                }
                
                // 상단 날짜표시 헤더 - 날짜 및 음력 표시
                HStack {
                    
                    Text(self.state.dayModel?.dateText ?? "")
                        .font(self.appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont)
                        .foregroundColor(self.appearance.colorSet.normalText.asColor)
                        
                    
                    if self.appearance.showLunarCalendarDate {
                        Text(self.state.dayModel?.lunarDateText ?? "")
                            .font(
                                self.appearance.fontSet.size(20+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                            )
                            .foregroundColor(self.appearance.colorSet.subSubNormalText.asColor)
                    }
                    
                    Spacer()
                    
                    Button {
                        self.eventHandler.showDoneTodoList()
                    } label: {
                        Image(systemName: "checklist.checked")
                    }
                }
                .padding(.bottom, 3)
            }
            
            // 이벤트 리스트
            VStack(alignment: .leading, spacing: 6) {
                ForEach(self.state.cellViewModels, id: \.customCompareKey) { cellViewModel in
                    
                    EventListCellView(cellViewModel: cellViewModel)
                        .eventHandler(\.requestDoneTodo, eventHandler.requestDoneTodo)
                        .eventHandler(\.requestCancelDoneTodo, eventHandler.requestCancelDoneTodo)
                        .eventHandler(\.requestShowDetail, eventHandler.requestShowDetail)
                        .eventHandler(\.handleMoreAction, eventHandler.handleMoreAction)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            // todo 추가
            QuickAddNewTodoView()
                .eventHandler(\.addNewTodoQuickly, eventHandler.addNewTodoQuickly)
                .eventHandler(\.makeNewTodoWithGivenNameAndDetails, eventHandler.makeNewTodoWithGivenNameAndDetails)
            
            addNewButton()
        }
        .padding()
    }
    
    private func addNewButton() -> some View {
        return HStack {
            Button {
                self.eventHandler.requestAddNewEventWhetherUsingTemplate(false)
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .tint(self.appearance.colorSet.normalText.asColor)
                    Text("Add New Event")
                        .font(
                            self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.normalText.asColor)
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .backgroundAsRoundedRectForEventList(self.appearance)
            }
            
            Button {
                self.eventHandler.requestAddNewEventWhetherUsingTemplate(true)
            } label: {
                Image(systemName: "list.bullet.clipboard")
                    .tint(self.appearance.colorSet.normalText.asColor)
                    .frame(width: 50, height: 50)
                    .backgroundAsRoundedRectForEventList(self.appearance)
            }
        }
    }
}


// MARK: - event list cellView

private struct EventListCellView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    fileprivate var requestDoneTodo: (String) -> Void = { _ in }
    fileprivate var requestCancelDoneTodo: (String) -> Void = { _ in }
    fileprivate var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    fileprivate var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    
    private let cellViewModel: any EventCellViewModel
    init(cellViewModel: any EventCellViewModel) {
        self.cellViewModel = cellViewModel
    }
    
    var body: some View {
        let tagLineColor = cellViewModel.tagColor?.color(with: self.appearance).asColor ?? .clear
        return HStack(spacing: 8) {
            // left
            self.eventLeftView(cellViewModel)
                .frame(width: 52)
                
            // tag line
            RoundedRectangle(cornerRadius: 3)
                .fill(tagLineColor)
                .frame(width: 6)
            
            // right
            self.eventRightView(cellViewModel)
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .frame(idealHeight: 50)
        .backgroundAsRoundedRectForEventList(self.appearance)
        .onTapGesture {
            self.requestShowDetail(self.cellViewModel)
        }
        .contextMenu {
            if cellViewModel.isSupportContextMenu {
                if cellViewModel.isRepeating {
                    removeButton(true)
                }
                removeButton(false)
                
                Divider()
                
                toggleForemostButton(cellViewModel.isForemost)
            }
        }
    }
    
    private func removeButton(_ onlyThisTime: Bool) -> some View {
        return Button(role: .destructive) {
            self.handleMoreAction(
                self.cellViewModel, .remove(onlyThisTime: onlyThisTime)
            )
        } label: {
            Text(onlyThisTime ? "remove event only this time".localized() : "remove event".localized())
        }
    }
    
    private func toggleForemostButton(_ isForemost: Bool) -> some View {
        return Button {
            self.handleMoreAction(
                self.cellViewModel, .toggleTo(isForemost: !isForemost)
            )
        } label: {
            Text(isForemost ? "unmark as foremost".localized() : "mark as foremost".localized())
        }
    }
    
    private func eventLeftView(_ cellViewModel: any EventCellViewModel) -> some View {
        
        func pmOrAmView(_ amOrPm: String) -> some View {
            Text(amOrPm)
                .minimumScaleFactor(0.7)
                .font(appearance.fontSet.size(8+appearance.eventTextAdditionalSize).asFont)
                .foregroundStyle(appearance.colorSet.normalText.asColor)
        }
        
        func singleText(_ text: EventTimeText) -> some View {
            return VStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text.text)
                        .minimumScaleFactor(0.7)
                        .font(
                            self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.normalText.asColor)
                    
                    if let amPm = text.pmOram {
                        pmOrAmView(amPm)
                    }
                }
            }
        }
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(top.text)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont)
                        .foregroundColor(self.appearance.colorSet.normalText.asColor)
                    
                    if let amPm = top.pmOram {
                        pmOrAmView(amPm)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                 
                    Text(bottom.text)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(14+appearance.eventTextAdditionalSize).asFont)
                        .foregroundColor(self.appearance.colorSet.subNormalText.asColor)
                    
                    if let amPm = bottom.pmOram {
                        pmOrAmView(amPm)
                    }
                }
            }
        }
        switch cellViewModel.periodText {
        case .singleText(let text):
            return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText):
            return doubleText(topText, bottomText).asAnyView()
        default:
            return EmptyView().asAnyView()
        }
    }
    
    private func eventRightView(_ cellViewModel: any EventCellViewModel) -> some View {
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cellViewModel.name)
                    .minimumScaleFactor(0.7)
                    .font(
                        self.appearance.eventTextFontOnList(isForemost: cellViewModel.isForemost).asFont
                    )
                    .foregroundColor(self.appearance.colorSet.normalText.asColor)
                
                if let periodDescription = cellViewModel.periodDescription {
                    Text(periodDescription)
                        .minimumScaleFactor(0.7)
                        .font(
                            self.appearance.fontSet.size(13+appearance.eventTextAdditionalSize).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.subNormalText.asColor)
                }
            }
            Spacer()
            if let todoId = cellViewModel.todoEventId {
                todoDoneButton(todoId)
            }
        }
    }
    
    private func todoDoneButton(_ todoId: String) -> some View {
        Button {
            let isUnderCompleteProcessing = self.state.tempDoneTodoIds.contains(todoId)
            if !isUnderCompleteProcessing {
                withAnimation { _ = self.state.tempDoneTodoIds.insert(todoId) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    guard self.state.tempDoneTodoIds.contains(todoId) else { return }
                    self.requestDoneTodo(todoId)
                }
            } else {
                withAnimation { _ = self.state.tempDoneTodoIds.remove(todoId) }
                self.requestCancelDoneTodo(todoId)
            }
            
        } label: {
            if self.state.tempDoneTodoIds.contains(todoId) {
                Image(systemName: "circle.inset.filled")
            } else {
                Image(systemName: "circle")
            }
        }
    }
}

private struct QuickAddNewTodoView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    @State private var newTodoName: String = ""
    @FocusState private var isFocusInput: Bool
    private var isEntering: Bool { !self.newTodoName.isEmpty }
    
    private func resetStates() {
        self.newTodoName = ""
        self.isFocusInput = false
    }
    
    fileprivate var addNewTodoQuickly: (String) -> Void = { _ in }
    fileprivate var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }
    
    var body: some View {
        HStack(spacing: 8) {
            
            Text("Todo".localized())
                .minimumScaleFactor(0.7)
                .font(
                    self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                )
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
                .frame(width: 52)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(self.appearance.tagColors.defaultColor.asColor)
                .frame(width: 6)
            
            HStack(spacing: 8) {
                TextField("Add a new todo quickly".localized(), text: $newTodoName)
                    .focused($isFocusInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        guard !self.newTodoName.isEmpty else { return }
                        self.addNewTodoQuickly(self.newTodoName)
                        self.resetStates()
                    }
                    .submitLabel(.done)
                
                if !self.newTodoName.isEmpty {
                    Button {
                        self.makeNewTodoWithGivenNameAndDetails(self.newTodoName)
                        self.resetStates()
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

private extension View {
    
    func backgroundAsRoundedRectForEventList(_ appearance: ViewAppearance) -> some View {
        
        return self
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(appearance.colorSet.eventList.asColor)
            )
    }
}

private extension EventCellViewModel {
    
    var todoEventId: String? {
        return (self as? TodoEventCellViewModel)?.eventIdentifier
    }
    
    var isSupportContextMenu: Bool {
        switch self {
        case is TodoEventCellViewModel: return true
        case is ScheduleEventCellViewModel: return true
        default: return false
        }
    }
}

// MARK: - preview

struct DayEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting)
//        viewAppearance.eventTextAdditionalSize = 4
        viewAppearance.showHoliday = true
        viewAppearance.showLunarCalendarDate = true
        let state = DayEventListViewState()
        state.dayModel = .init(dateText: "2020년 9월 15일(금)", lunarDateText: "6월 4일")
        state.dayModel?.holidayName = "크리스마스"
        state.cellViewModels = self.makeDummyCells()
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
                |> \.tagColor .~ .default
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
                                |> \.tagColor .~ pending.tagColor
                            state.cellViewModels[index] = newCell
                        }
                    }
                }
            }
        }
        let containerView = DayEventListView()
            .environmentObject(viewAppearance)
            .environmentObject(state)
            .environmentObject(eventHandler)
        return containerView
    }
    
    private static func makeDummyCells() -> [any EventCellViewModel] {
        let currentTodoCells: [TodoEventCellViewModel] = [
            .init("current-todo1", name: "current todo 1")
                |> \.tagColor .~ .default
                |> \.periodText .~ .singleText(.init(text: "Todo".localized())),
            .init("current-todo2", name: "current todo 2")
                |> \.tagColor .~ .default
                |> \.periodText .~ .singleText(.init(text: "Todo".localized()))
        ]
        let todoCells: [TodoEventCellViewModel] = [
//            .init(eventId: .todo("todo1"), name: "todo with anyTime")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .anyTime,
            .init("todo2", name: "todo with all day")
                |> \.tagColor .~ .default
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "Allday")
                ),
            .init("todo3", name: "todo with at time")
                |> \.tagColor .~ .default
                |> \.isForemost .~ true
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "10:30", pmOram: "AM")
                ),
//            .init(eventId: .todo("todo4"), name: "todo with in today")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .inToday("9:30", "20:30")
//                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
            .init("todo5", name: "todo with today to future")
                |> \.tagColor .~ .default
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "9 (Sat)")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init("todo6", name: "todo with past to today")
                |> \.tagColor .~ .default
                |> \.periodText .~ .doubleText(
                    .init(text: "Todo".localized()),
                    .init(text: "20:00")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        let scheduleCells: [ScheduleEventCellViewModel] = [
            .init("sc1", name: "schdule with at time")
                |> \.tagColor .~ .default
                |> \.periodText .~ .singleText(
                    .init(text: "8:30", pmOram: "AM")
                ),
            .init("sc2", name: "schdule with all day")
                |> \.tagColor .~ .default
                |> \.periodText .~ .singleText(
                    .init(text: "Allday".localized())
                ),
//            .init(eventId: .schedule("sc3", turn: 1), name: "schdule with at time")
//            |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .atTime("10:30"),
            .init("sc4", name: "schdule with in today")
                |> \.tagColor .~ .default
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
                |> \.tagColor .~ .default
                |> \.periodText .~ .doubleText(
                    .init(text: "9 (Sat)"),
                    .init(text: "20:00")
                )
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        
        let holidayCell = HolidayEventCellViewModel(
            HolidayCalendarEvent(.init(dateString: "2023-09-30", localName: "추석", name: "추석"), in: TimeZone.current)!
        )
            |> \.tagColor .~ .holiday
        
        return currentTodoCells + (
            scheduleCells + todoCells + [holidayCell]
        )
//        .shuffled()
    }
}
