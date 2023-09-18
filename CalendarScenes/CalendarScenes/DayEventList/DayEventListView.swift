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
import CommonPresentation


// MARK: - DayEventListViewController

final class DayEventListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published fileprivate var dateText: String = ""
    @Published fileprivate var cellViewModels: [any EventCellViewModel] = []
    @Published fileprivate var tempDoneTodoIds: Set<String> = []
    
    func bind(_ viewModel: any DayEventListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.selectedDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.dateText = text
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


// MARK: - DayEventListContainerView

struct DayEventListContainerView: View {
    
    @StateObject private var state: DayEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (DayEventListViewState) -> Void = { _ in }
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestAddNewEventWhetherUsingTemplate: (Bool) -> Void = { _ in }
    var addNewTodoQuickly: (String) -> Void = { _ in }
    var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return DayEventListView()
            .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
            .eventHandler(\.requestAddNewEventWhetherUsingTemplate, self.requestAddNewEventWhetherUsingTemplate)
            .eventHandler(\.addNewTodoQuickly, self.addNewTodoQuickly)
            .eventHandler(\.makeNewTodoWithGivenNameAndDetails, self.makeNewTodoWithGivenNameAndDetails)
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - DayEventListView

struct DayEventListView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    fileprivate var requestDoneTodo: (String) -> Void = { _ in }
    fileprivate var requestAddNewEventWhetherUsingTemplate: (Bool) -> Void = { _ in }
    fileprivate var addNewTodoQuickly: (String) -> Void = { _ in }
    fileprivate var makeNewTodoWithGivenNameAndDetails: (String) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.state.dateText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(self.appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
                .padding(.bottom, 3)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(self.state.cellViewModels, id: \.customCompareKey) { cellViewModel in
                    
                    EventListCellView(cellViewModel: cellViewModel)
                        .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            QuickAddNewTodoView()
                .eventHandler(\.addNewTodoQuickly, self.addNewTodoQuickly)
                .eventHandler(\.makeNewTodoWithGivenNameAndDetails, self.makeNewTodoWithGivenNameAndDetails)
            
            addNewButton()
        }
        .padding()
    }
    
    private func addNewButton() -> some View {
        return HStack {
            Button {
                self.requestAddNewEventWhetherUsingTemplate(false)
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .tint(self.appearance.colorSet.normalText.asColor)
                    Text("Add New Event")
                        .font(self.appearance.fontSet.size(15).asFont)
                        .foregroundColor(self.appearance.colorSet.normalText.asColor)
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .backgroundAsRoundedRectForEventList(self.appearance)
            }
            
            Button {
                self.requestAddNewEventWhetherUsingTemplate(true)
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
    
    private let cellViewModel: any EventCellViewModel
    init(cellViewModel: any EventCellViewModel) {
        self.cellViewModel = cellViewModel
    }
    
    var body: some View {
        let tagLineColor = cellViewModel.colorHex.flatMap { Color.from($0) } ?? .clear
        return HStack(spacing: 8) {
            // left
            self.eventLeftView(cellViewModel)
                .frame(width: 50)
                
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
    }
    
    private func eventLeftView(_ cellViewModel: any EventCellViewModel) -> some View {
        func singleText(_ text: String) -> some View {
            return VStack(alignment: .center) {
                Text(text)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(15, weight: .regular).asFont)
                    .foregroundColor(self.appearance.colorSet.normalText.asColor)
            }
        }
        func doubleText(_ top: String, _ bottom: String) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                Text(top)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(15, weight: .regular).asFont)
                    .foregroundColor(self.appearance.colorSet.normalText.asColor)
                Text(bottom)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundColor(self.appearance.colorSet.subNormalText.asColor)
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
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundColor(self.appearance.colorSet.normalText.asColor)
                
                if let periodDescription = cellViewModel.periodDescription {
                    Text(periodDescription)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(13).asFont)
                        .foregroundColor(self.appearance.colorSet.subNormalText.asColor)
                }
            }
            Spacer()
            if let todoId = cellViewModel.todoEventId {
                Button {
                    withAnimation {
                        _ = self.state.tempDoneTodoIds.insert(todoId)
                    }
                    self.requestDoneTodo(todoId)
                    
                } label: {
                    if self.state.tempDoneTodoIds.contains(todoId) {
                        Image(systemName: "circle.fill")
                    } else {
                        Image(systemName: "circle")
                    }
                }
            }
        }
    }
}

private struct QuickAddNewTodoView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    @State private var newTodoName: String = ""
    @FocusState private var isFocusInput: Bool
    
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
                .font(self.appearance.fontSet.size(15, weight: .regular).asFont)
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
            .frame(width: 50)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(self.appearance.colorSet.subNormalText.asColor)
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
        .opacity(self.isFocusInput ? 1.0 : 0.5)
        .animation(.default, value: self.isFocusInput)
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
}

// MARK: - preview

struct DayEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let state = DayEventListViewState()
        state.dateText = "2020년 9월 15일(금)"
        state.cellViewModels = self.makeDummyCells()
        let containerView = DayEventListView()
            .eventHandler(\.requestDoneTodo) { id in
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
            .eventHandler(\.addNewTodoQuickly) { name in
                let pending = PendingTodoEventCellViewModel(name: name, defaultTagId: nil)
                    |> \.colorHex .~ "#ffff00"
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
                                    |> \.periodText .~ .singleText("Todo".localized())
                                    |> \.colorHex .~ pending.colorHex
                                state.cellViewModels[index] = newCell
                            }
                        }
                    }
                }
            }
            .environmentObject(viewAppearance)
            .environmentObject(state)
        return containerView
    }
    
    private static func makeDummyCells() -> [any EventCellViewModel] {
        let currentTodoCells: [TodoEventCellViewModel] = [
            .init("current-todo1", name: "current todo 1")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .singleText("Todo".localized()),
            .init("current-todo2", name: "current todo 2")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .singleText("Todo".localized())
        ]
        let todoCells: [TodoEventCellViewModel] = [
//            .init(eventId: .todo("todo1"), name: "todo with anyTime")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .anyTime,
            .init("todo2", name: "todo with all day")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("Todo".localized(), "Allday"),
            .init("todo3", name: "todo with at time")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("Todo".localized(), "10:30"),
//            .init(eventId: .todo("todo4"), name: "todo with in today")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .inToday("9:30", "20:30")
//                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
            .init("todo5", name: "todo with today to future")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("Todo".localized(), "9 (Sat)")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init("todo6", name: "todo with past to today")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("Todo".localized(), "20:00")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        let scheduleCells: [ScheduleEventCellViewModel] = [
            .init("sc1", name: "schdule with at time")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .singleText("8:30"),
            .init("sc2", name: "schdule with all day")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .singleText("Allday".localized()),
//            .init(eventId: .schedule("sc3", turn: 1), name: "schdule with at time")
//            |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .atTime("10:30"),
            .init("sc4", name: "schdule with in today")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("9:30", "20:30")
                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
//            .init(eventId: .schedule("sc5", turn: 1), name: "schdule with today to future")
//            |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .fromTodayToFuture("09:30", "9 (Sat)")
//                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init("sc6", name: "schdule with past to today")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .doubleText("9 (Sat)", "20:00")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        
        let holidayCell = HolidayEventCellViewModel(
            .init(dateString: "2023-09-30", localName: "추석", name: "추석")
        )
        |> \.colorHex .~ "#ff0000"
        
        return currentTodoCells + (
            scheduleCells + todoCells + [holidayCell]
        )
//        .shuffled()
    }
}
