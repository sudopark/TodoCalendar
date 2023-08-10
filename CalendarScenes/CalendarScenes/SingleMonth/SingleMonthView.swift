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
        return VStack {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 0), count: 7), spacing: 0) {
                ForEach(self.weeks.flatMap { $0.days }, id: \.identifier) {
                    self.dayView($0, height)
                }
            }
        }
    }
    
    private func dayView(
        _ day: DayCellViewModel,
        _ expectHeight: CGFloat
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
        .frame(height: expectHeight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .opacity(opacity)
        .onTapGesture {
            self.viewModel.select(day)
        }
    }
}

// MARK: - preview

//final class DummySingleMonthViewModel: SingleMonthViewModel {
//
//    func select(_ day: DayCellViewModel) { }
//
//    var weekDays: AnyPublisher<[WeekDayModel], Never> {
//        return Just([
//            .init(symbol: "SUN", isWeekEnd: true),
//            .init(symbol: "MON", isWeekEnd: false),
//            .init(symbol: "TUE", isWeekEnd: false),
//            .init(symbol: "WED", isWeekEnd: false),
//            .init(symbol: "THU", isWeekEnd: false),
//            .init(symbol: "FRI", isWeekEnd: false),
//            .init(symbol: "SAT", isWeekEnd: true)
//        ])
//        .eraseToAnyPublisher()
//    }
//
//    var weekModels: AnyPublisher<[WeekRowModel], Never> {
//        let days: [DayCellViewModel] = (0..<31).map { int -> DayCellViewModel in
//            return  DayCellViewModel(year: 2023, month: 09, day: int+1, isNotCurrentMonth: false, isWeekEnd: false, isHoliday: false)
//        }
//        let models = days.enumerated().reduce(into: [WeekRowModel]()) { acc, pair in
//            let isSunday = pair.offset % 7 == 0
//            if isSunday {
//                let newWeek = WeekRowModel(days: [pair.element])
//                acc.append(newWeek)
//            } else {
//                let newWeek = WeekRowModel(days: acc.last!.days + [pair.element])
//                acc[acc.count-1] = newWeek
//            }
//        }
//        return Just(models).eraseToAnyPublisher()
//    }
//
//    var currentSelectDayIdentifier: AnyPublisher<String?, Never> { Empty().eraseToAnyPublisher() }
//
//    var todayIdentifier: AnyPublisher<String, Never> { Empty().eraseToAnyPublisher() }
//
//    func updateMonthIfNeed(_ newMonth: Domain.CalendarMonth) { }
//}
//
//
//struct SingleMonthViewPreviewProvider: PreviewProvider {
//
//    static var previews: some View {
//        let viewModel = DummySingleMonthViewModel()
//        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
//        return SingleMonthView(viewModel)
//            .environmentObject(viewAppearance)
//    }
//}
