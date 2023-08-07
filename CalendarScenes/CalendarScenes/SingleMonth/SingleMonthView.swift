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

struct SingleMonthView: View {
    
    @State private var weekdays: [WeekDayModel] = []
    @State private var days: [DayCellViewModel] = []
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
            gridWeeksView
        }
        .padding([.leading, .trailing], 8)
        .background(self.appearance.colorSet.dayBackground.asColor)
        .onReceive(self.viewModel.weekDays.receive(on: RunLoop.main)) { self.weekdays = $0 }
        .onReceive(self.viewModel.allDays.receive(on: RunLoop.main)) {
            self.days = $0
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
    
    private var gridWeeksView: some View {
        
        return VStack {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 0), count: 7), spacing: 0) {
                ForEach(self.days, id: \.identifier) {
                    self.dayView($0)
                }
            }
        }
    }
    
    private func dayView(_ day: DayCellViewModel) -> some View {
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
        .frame(minHeight: 80)
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

private extension SingleMonthViewModel {
    
    var allDays: AnyPublisher<[DayCellViewModel], Never> {
        return self.weekModels
            .map { weeks in weeks.flatMap { $0.days } }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .eraseToAnyPublisher()
    }
}
