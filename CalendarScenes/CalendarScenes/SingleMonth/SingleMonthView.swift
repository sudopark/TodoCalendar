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


struct SingleMonthView: View {
    
    @State private var weekdaySymbols: [String] = []
    @State private var days: [DayCellViewModel] = []
    @State private var selectedDay: String?
    @State private var today: String?
    
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
                Text(weekDay)
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
        let textColor: Color = day.identifier == self.selectedDay ? .white : .black
        let backgroundColor: Color = day.identifier == self.selectedDay ? .black
            : day.identifier == self.today ? .gray
            : .clear
        return VStack {
            Text("\(day.day)")
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
