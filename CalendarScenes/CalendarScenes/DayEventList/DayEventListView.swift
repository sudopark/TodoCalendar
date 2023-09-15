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
    @Published fileprivate var cellViewModels: [EventCellViewModel] = []
    @Published fileprivate var tempDoneTodoIds: Set<String> = []
    
    func bind(_ viewModel: DayEventListViewModel) {
        
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
                self?.cellViewModels = cellViewModels
                self?.removeDoneTodoIdsFromTempDoneIds(from: cellViewModels)
            })
            .store(in: &self.cancellables)
        
        viewModel.doneTodoFailed
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] todoId in
                guard let self = self else { return }
                self.tempDoneTodoIds = self.tempDoneTodoIds |> elem(todoId) .~ false
                // elem 함수 자체가
                // 세터로 넣어줄 함수(contain) == true 이면 insert
                // 세터로 넣어줄 함수(contain) == false 이면 remove
                // set false 함수가 들어가 버리면 -> contain 여부와 관련없이 결과는 false여서 remove / true이면 반대여서 insert -> set은 읽지는 않으니(내부에 입력한 결과로만 반환하게 const)
                // over가 들어가서 { !$0 } 이라면 -> contain의 invert가 되기 때문에
                // 없다면 insert / 있으면 delete
            })
            .store(in: &self.cancellables)
    }
    
    private func removeDoneTodoIdsFromTempDoneIds(from cellViewModels: [EventCellViewModel]) {
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
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return DayEventListView()
            .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.state.dateText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(self.appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
                .padding(.bottom, 3)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(self.state.cellViewModels, id: \.presentingCompareKey) { cellViewModel in
                    
                    EventListCellView(cellViewModel: cellViewModel)
                        .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            addNewButton()
        }
        .padding()
    }
    
    private func addNewButton() -> some View {
        return Text("Button")
    }
}


// MARK: - event list cellView

private struct EventListCellView: View {
    
    @EnvironmentObject private var state: DayEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    fileprivate var requestDoneTodo: (String) -> Void = { _ in }
    
    private let cellViewModel: EventCellViewModel
    init(cellViewModel: EventCellViewModel) {
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
        .background(self.appearance.colorSet.eventList.asColor)
    }
    
    private func eventLeftView(_ cellViewModel: EventCellViewModel) -> some View {
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
        case .anyTime:
            return singleText("Always".localized()).asAnyView()
        case .allDay:
            return singleText("Allday".localized()).asAnyView()
        case .atTime(let time):
            return singleText(time).asAnyView()
        case .inToday(let start, let end):
            return doubleText(start, end).asAnyView()
        case .fromTodayToFuture(let start, let end):
            return doubleText(start, end).asAnyView()
        case .fromPastToToday(let start, let end):
            return doubleText(start, end).asAnyView()
        default:
            return EmptyView().asAnyView()
        }
    }
    
    private func eventRightView(_ cellViewModel: EventCellViewModel) -> some View {
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

private extension EventId {
    
    var presentingCompareKey: String {
        switch self {
        case .todo(let id): return "todo:\(id)"
        case .schedule(let id, let turn): return "scheudle:\(id)-\(turn)"
        case .holiday(let holiday): return "\(holiday.dateString)-\(holiday.name)"
        }
    }
}

private extension EventCellViewModel.PeriodText {
    
    var presentingCompareKey: String {
        switch self {
        case .anyTime: return "anyTime"
        case .allDay: return "allDay"
        case .atTime(let time): return "atTime-\(time)"
        case .inToday(let start, let end): return "inToday-\(start)~\(end)"
        case .fromTodayToFuture(let start, let end): return "fromTodayToFuture\(start)~\(end)"
        case .fromPastToToday(let start, let end): return "fromPastToToday-\(start)~\(end)"
        }
    }
}

private extension EventCellViewModel {
    
    var presentingCompareKey: String {
        let components: [String?] = [
            self.eventId.presentingCompareKey,
            self.name, self.periodText?.presentingCompareKey,
            self.periodDescription, self.colorHex
        ]
        return components.map { $0 ?? "nil" }.joined(separator: "-")
    }
}


// MARK: - preview

struct DayEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let state = DayEventListViewState()
        state.dateText = "2020년 9월 15일(금)"
        state.cellViewModels = EventCellViewModel.dummies()
        let containerView = DayEventListView()
            .eventHandler(\.requestDoneTodo) { id in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    // 완료처리 실패하게 하던지
//                    state.requestDoneTodoIds = []
                    
                    // 혹은 완료처리 성공 이후 셀 목록 업데이트 시뮬레이션
                    let newCells = state.cellViewModels.filter { $0.todoEventId != id }
                    state.cellViewModels = newCells
                }
            }
            .environmentObject(viewAppearance)
            .environmentObject(state)
        return containerView
    }
}

private extension EventCellViewModel {
    
    // period랑 allday만 설명 있음
    
    static func dummies() -> [EventCellViewModel] {
        let currentTodoCells: [EventCellViewModel] = [
            .init(eventId: .todo("current-todo1"), name: "current todo 1")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .anyTime,
            .init(eventId: .todo("current-todo2"), name: "current todo 2")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .anyTime
        ]
        let todoCells: [EventCellViewModel] = [
//            .init(eventId: .todo("todo1"), name: "todo with anyTime")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .anyTime,
//            .init(eventId: .todo("todo2"), name: "todo with all day")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .allDay,
//            .init(eventId: .todo("todo3"), name: "todo with at time")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .atTime("10:30"),
//            .init(eventId: .todo("todo4"), name: "todo with in today")
//                |> \.colorHex .~ "#0000ff"
//                |> \.periodText .~ .inToday("9:30", "20:30")
//                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
            .init(eventId: .todo("todo5"), name: "todo with today to future")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .fromTodayToFuture("09:30", "9 (Sat)")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init(eventId: .todo("todo6"), name: "todo with past to today")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .fromPastToToday("9 (Sat)", "20:00")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        let scheduleCells: [EventCellViewModel] = [
            .init(eventId: .schedule("sc1", turn: 1), name: "schdule with anyTime")
                |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .anyTime,
            .init(eventId: .schedule("sc2", turn: 1), name: "schdule with all day")
            |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .allDay,
            .init(eventId: .schedule("sc3", turn: 1), name: "schdule with at time")
            |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .atTime("10:30"),
            .init(eventId: .schedule("sc4", turn: 1), name: "schdule with in today")
            |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .inToday("9:30", "20:30")
                |> \.periodDescription .~ "Sep 10 09:30 ~ Sep 10 20:30(11hours)",
            .init(eventId: .schedule("sc5", turn: 1), name: "schdule with today to future")
            |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .fromTodayToFuture("09:30", "9 (Sat)")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)",
            .init(eventId: .schedule("sc6", turn: 1), name: "schdule with past to today")
            |> \.colorHex .~ "#0000ff"
                |> \.periodText .~ .fromPastToToday("9 (Sat)", "20:00")
                |> \.periodDescription .~ "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)"
        ]
        
        let holidayCell = EventCellViewModel(.init(dateString: "2023-09-30", localName: "추석", name: "추석"))
            |> \.colorHex .~ "#ff0000"
        
        return currentTodoCells + (
            scheduleCells + todoCells + [holidayCell]
        )
//        .shuffled()
    }
}
