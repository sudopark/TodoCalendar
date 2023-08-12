//
//  SingleMonthView.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/03.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


extension DayCellViewModel: Identifiable {
    
    typealias ID = String
    var id: String { self.identifier }
}

struct SingleMonthContainerView: View {
    
    private let viewModel: SingleMonthViewModel
    private let viewAppearance: ViewAppearance
    
    init(viewModel: SingleMonthViewModel, viewAppearance: ViewAppearance) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return SingleMonthView(viewModel)
            .environmentObject(viewAppearance)
    }
}


private enum Metric {
    static let dayMinHeight: CGFloat = 80
    static let dayMaxHeight: CGFloat = 100
    static let eventRowHeight: CGFloat = 15
    static let eventTopMargin: CGFloat = 10
}

struct SingleMonthView: View {
    
    @State private var weekdays: [WeekDayModel] = []
    @State private var weeks: [WeekRowModel] = []
    @State private var selectedDay: String?
    @State private var today: String?
    
    @EnvironmentObject private var appearance: ViewAppearance
    
    private let viewModel: SingleMonthViewModel
    init(_ viewModel: SingleMonthViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            GeometryReader { proxy in
                self.gridWeeksView(proxy)
            }
        }
        .padding([.leading, .trailing], 8)
        .background(self.appearance.colorSet.dayBackground.asColor)
        .onReceive(self.viewModel.weekDays.receive(on: RunLoop.main)) { self.weekdays = $0 }
        .onReceive(self.viewModel.weekModels.receive(on: RunLoop.main)) {
            self.weeks = $0
        }
        .onReceive(self.viewModel.currentSelectDayIdentifier.receive(on: RunLoop.main)) { self.selectedDay = $0 }
        .onReceive(self.viewModel.todayIdentifier.receive(on: RunLoop.main)) { self.today = $0 }
    }
    
    private var headerView: some View {
        let textColor: (WeekDayModel) -> Color = {
            return $0.isWeekEnd
            ? self.appearance.colorSet.weekEndText.asColor
            : self.appearance.colorSet.weekDayText.asColor
        }
        return HStack {
            ForEach(self.weekdays, id: \.symbol) { weekDay in
                Text(weekDay.symbol)
                    .font(self.appearance.fontSet.weekday.asFont)
                    .foregroundColor(textColor(weekDay))
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func gridWeeksView(_ proxy: GeometryProxy) -> some View {
        let height: CGFloat = {
            let rowCount = self.weeks.count
            guard rowCount > 0 else { return 0 }
            let expectHeight = proxy.size.height / CGFloat(rowCount)
            return max(
                Metric.dayMinHeight,
                min(Metric.dayMaxHeight, expectHeight)
            )
        }()
        let expectSize = CGSize(width: proxy.size.width, height: height)
        return VStack {
            ForEach(self.weeks, id: \.id) {
                WeekRowView(week: $0, viewModel, expectSize, $selectedDay, $today)
                    .environmentObject(appearance)
            }
        }
    }
}

private struct WeekRowView: View {
    
    private let week: WeekRowModel
    private let viewModel: SingleMonthViewModel
    private let expectSize: CGSize
    @EnvironmentObject private var appearance: ViewAppearance
    
    @State private var eventStackModel: WeekEventStackViewModel = []
    @Binding private var selectedDay: String?
    @Binding private var today: String?
    
    init(
        week: WeekRowModel,
        _ viewModel: SingleMonthViewModel,
        _ expectSize: CGSize,
        _ selectedDay: Binding<String?>,
        _ today: Binding<String?>
    ) {
        self.week = week
        self.viewModel = viewModel
        self.expectSize = expectSize
        self._selectedDay = selectedDay
        self._today = today
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(week.days, id: \.identifier) { dayView($0) }
            }
            eventStackView()
        }
        .onReceive(viewModel.eventStack(at: week.id).receive(on: RunLoop.main)) {
            self.eventStackModel = $0
        }
    }
    
    private func dayView(
        _ day: DayCellViewModel
    ) -> some View {
        let textColor: Color = {
            if day.identifier == selectedDay {
                return self.appearance.colorSet.selectedDayText.asColor
            } else if day.isHoliday {
                return self.appearance.colorSet.holidayText.asColor
            } else if day.isWeekEnd {
                return self.appearance.colorSet.weekEndText.asColor
            } else {
                return self.appearance.colorSet.weekDayText.asColor
            }
        }()
        let backgroundColor: Color = {
            if day.identifier == self.selectedDay {
                return self.appearance.colorSet.selectedDayBackground.asColor
            } else if day.identifier == self.today {
                return self.appearance.colorSet.todayBackground.asColor
            } else {
                return self.appearance.colorSet.dayBackground.asColor
            }
        }()
        let opacity: Double = {
            return day.identifier == self.selectedDay || day.isNotCurrentMonth == false
            ? 1.0 : 0.5
        }()
        return VStack {
            Text("\(day.day)")
                .font(self.appearance.fontSet.day.asFont)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            Spacer()
        }
        .frame(height: expectSize.height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .opacity(opacity)
        .onTapGesture {
            self.viewModel.select(day)
        }
    }
    
    private func eventStackView() -> some View {
        
        let totalHeight = self.expectSize.height - Metric.eventTopMargin
        let drawableRowCount = Int(totalHeight / Metric.eventRowHeight)
        let maxDrawableEventRowCount = drawableRowCount - 1
        guard maxDrawableEventRowCount > 0 else { return EmptyView().asAnyView() }
        
        let size = min(maxDrawableEventRowCount, self.eventStackModel.count)
        // TODO: 각 일자별 more 필요한 지점 구해야함 + 지점별 개별 more count 구해야함
        let dayWidth = expectSize.width / 7
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<size, id: \.self) {
                return eventRowView(self.eventStackModel[$0], dayWith: dayWidth)
            }
        }
        .padding(.top, Metric.eventTopMargin)
        .asAnyView()
    }
    
    private func eventRowView(_ lines: [WeekEventLineModel], dayWith: CGFloat) -> some View {
        return ZStack() {
            ForEach(0..<lines.count, id: \.self) {
                return eventLineView(lines[$0], dayWidth: dayWith)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func eventLineView(_ line: WeekEventLineModel, dayWidth: CGFloat) -> some View {
        let offsetX = CGFloat(line.eventOnWeek.daysSequence.lowerBound-1) * dayWidth
        let width = CGFloat(line.eventOnWeek.daysSequence.count) * dayWidth
        return Text(line.eventOnWeek.name)
            .font(self.appearance.fontSet.eventOnDay.asFont)
            .frame(width: width, alignment: .leading)
            .background(Color.from(line.colorHex))
            .offset(x: offsetX)
    }
}

// MARK: - preview

final class DummySingleMonthViewModel: SingleMonthViewModel {
    
    func select(_ day: DayCellViewModel) { }

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return Just([
            .init(symbol: "SUN", isWeekEnd: true),
            .init(symbol: "MON", isWeekEnd: false),
            .init(symbol: "TUE", isWeekEnd: false),
            .init(symbol: "WED", isWeekEnd: false),
            .init(symbol: "THU", isWeekEnd: false),
            .init(symbol: "FRI", isWeekEnd: false),
            .init(symbol: "SAT", isWeekEnd: true)
        ])
        .eraseToAnyPublisher()
    }

    var weekModels: AnyPublisher<[WeekRowModel], Never> {
        let days: [DayCellViewModel] = (0..<31).map { int -> DayCellViewModel in
            return  DayCellViewModel(year: 2023, month: 09, day: int+1, isNotCurrentMonth: false, isWeekEnd: false, isHoliday: false)
        }
        let models = days.enumerated().reduce(into: [WeekRowModel]()) { acc, pair in
            let isSunday = pair.offset % 7 == 0
            let weekIndex = pair.offset / 7
            if isSunday {
                let newWeek = WeekRowModel("id:\(weekIndex)", [pair.element])
                acc.append(newWeek)
            } else {
                let newWeek = WeekRowModel(acc.last!.id, acc.last!.days + [pair.element])
                acc[acc.count-1] = newWeek
            }
        }
        return Just(models).eraseToAnyPublisher()
    }
    
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        if weekId == "id:0" {
            let event1_5 = EventOnWeek(0..<1, [1, 2, 3, 4, 5], (1...5), .todo("t1_5"), "ev:1_5")
            let event2_6 = EventOnWeek(0..<1, [2, 3, 4, 5, 6], (2...6), .todo("t2_6"), "ev:2_6")
            
            let event2_3 = EventOnWeek(0..<1, [2, 3], (2...3), .todo("t2_3"), "ev:2_3")
            let event5_6 = EventOnWeek(0..<1, [5, 6], (5...6), .todo("t5-6"), "ev:5_6")
            
            let event2_3_1 = EventOnWeek(0..<1, [2, 3], (2...3), .todo("t2_3_1"), "ev:2_3_1")
            let event2_3_2 = EventOnWeek(0..<1, [2, 3], (2...3), .todo("t2_3_2"), "ev:2_3_2")
            let event2_3_3 = EventOnWeek(0..<1, [2, 3], (2...3), .todo("t2_3_3"), "ev:2_3_3")
            
            return Just([
                [.init(event1_5, nil)],
                [.init(event2_6, nil)],
                [.init(event2_3, nil), .init(event5_6, nil)],
                [.init(event2_3_1, nil)],
                [.init(event2_3_2, nil)],
                [.init(event2_3_3, nil)]
            ])
            .eraseToAnyPublisher()
            
        } else {
            return Just([]).eraseToAnyPublisher()
        }
    }

    var currentSelectDayIdentifier: AnyPublisher<String?, Never> { Empty().eraseToAnyPublisher() }

    var todayIdentifier: AnyPublisher<String, Never> { Empty().eraseToAnyPublisher() }

    func updateMonthIfNeed(_ newMonth: Domain.CalendarMonth) { }
}


struct SingleMonthViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewModel = DummySingleMonthViewModel()
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        return SingleMonthView(viewModel)
            .environmentObject(viewAppearance)
    }
}
