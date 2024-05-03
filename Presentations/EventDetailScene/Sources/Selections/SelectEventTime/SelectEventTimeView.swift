//
//  
//  SelectEventTimeView.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SelectEventTimeViewState

final class SelectEventTimeViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var selectedTime: SelectedTime?
    @Published var isSelectingEventTime = true
    
    @Published var isAllDay: Bool = false
    @Published var isSelectingStartDate = false
    @Published var selectedStartDate: Date = Date()
    @Published var selectedEndDate: Date = Date().addingTimeInterval(60)
    
    func bind(_ viewModel: any SelectEventTimeViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.selectedTime
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] time in
                self?.selectedTime = time
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedTime
            .first()
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] time in
                self?.isSelectingEventTime = time != nil
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - SelectEventTimeViewEventHandler

final class SelectEventTimeViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var removeEventTime: () -> Void = { }
    var selectStartDate: (Date) -> Void = { _ in }
    var selectEndDate: (Date) -> Void = { _ in }
    var selectHasNoEndDate: () -> Void = { }
    var toggleIsAllDay: () -> Void = { }

    func bind(_ viewModel: any SelectEventTimeViewModel) {
        self.close = viewModel.close
        self.removeEventTime = viewModel.removeEventTime
        self.selectStartDate = viewModel.selectStartTime(_:)
        self.selectEndDate = viewModel.selectEndTime(_:)
        self.selectHasNoEndDate = viewModel.removeEndTime
        self.toggleIsAllDay = viewModel.toggleIsAllDay
    }
}


// MARK: - SelectEventTimeContainerView

struct SelectEventTimeContainerView: View {
    
    @StateObject private var state: SelectEventTimeViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectEventTimeViewEventHandler
    
    var stateBinding: (SelectEventTimeViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectEventTimeViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectEventTimeView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SelectEventTimeView

struct SelectEventTimeView: View {
    
    @EnvironmentObject private var state: SelectEventTimeViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SelectEventTimeViewEventHandler
    
    var body: some View {
        NavigationStack {
            VStack {
                selectButton("No event time", selected: !state.isSelectingEventTime) {
                    withAnimation {
                        state.isSelectingEventTime = false
                    }
                    eventHandlers.removeEventTime()
                }
                selectButton("Has event time", selected: state.isSelectingEventTime) {
                    withAnimation { state.isSelectingEventTime = true }
                }
                if state.isSelectingEventTime {
                    timeSelectView
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .navigationTitle("Event Time".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                        .eventHandler(\.onTap, eventHandlers.close)
                }
            }
        }
    }
    
    private func selectButton(
        _ title: String, selected: Bool, _ handler: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.normalText.asColor)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.eventList.asColor)
        )
        .onTapGesture(perform: handler)
    }
    
    // NARK: time select view
    
    private var timeSelectView: some View {
     
        VStack {
            HStack {
                Text("Start: ")
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                Spacer()
                
                timeView(state.selectedTime?.start, isInvalid: state.selectedTime?.isValid == false)
                    .onTapGesture {
                        self.state.isSelectingStartDate = true
                    }
                
                if state.isSelectingStartDate {
                    
                }
            }
        }
        .padding(.leading, 6)
    }
    
    private func timeView(_ timeText: SelectTimeText?, isInvalid: Bool) -> some View {
        
        guard let timeText 
        else {
            return Text("Not selected")
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(appearance.colorSet.eventList.asColor)
                )
                .asAnyView()
        }
        
        return HStack() {
            
            if let year = timeText.year {
                Text(year)
                    .strikethrough(isInvalid)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            }
            
            Text(timeText.day)
                .lineLimit(1)
                .strikethrough(isInvalid)
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            
            if let time = timeText.time {
                Text(time)
                    .strikethrough(isInvalid)
                    .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(appearance.colorSet.eventList.asColor)
        )
        .asAnyView()
    }
}

private extension SelectedTime {
    
    var start: SelectTimeText {
        switch self {
        case .at(let text): return text
        case .period(let start, _): return start
        case .singleAllDay(let text): return text
        case .alldayPeriod(let start, _): return start
        }
    }
}


// MARK: - preview

struct SelectEventTimeViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let tagSetting = DefaultEventTagColorSetting(
            holiday: "#ff0000", default: "#ff00ff"
        )
        let setting = AppearanceSettings(
            calendar: calendar, defaultTagColor: tagSetting
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = SelectEventTimeViewState()
        let eventHandlers = SelectEventTimeViewEventHandler()
        
        let view = SelectEventTimeView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

