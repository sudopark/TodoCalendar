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
    
    @State private var weekdaySymbols: [String] = []
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
        .onReceive(self.viewModel.weekDaysSymbols.receive(on: RunLoop.main)) { self.weekdaySymbols = $0 }
        .onReceive(self.viewModel.allDays.receive(on: RunLoop.main)) {
            self.days = $0
        }
        .onReceive(self.viewModel.currentSelectDayIdentifier.receive(on: RunLoop.main)) { self.selectedDay = $0 }
        .onReceive(self.viewModel.todayIdentifier.receive(on: RunLoop.main)) { self.today = $0 }
    }
    
    private var headerView: some View {
        return HStack {
            ForEach(self.weekdaySymbols, id: \.self) { weekDay in
                // TODO: 주말이면 텍스트 색 변경
                Text(weekDay)
                    .font(self.appearance.fontSet.weekday.asFont)
                    .foregroundColor(self.appearance.colorSet.weekDayText.asColor)
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
        // TODO: 주말이면 텍스트 컬러 변경
        // TODO: 이번달 아니면 텍스트 색 변경
        let textColor: Color = {
            return day.identifier == selectedDay
            ? self.appearance.colorSet.selectedDayText.asColor
            : self.appearance.colorSet.weekDayText.asColor
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
