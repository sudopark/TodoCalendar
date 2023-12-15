//
//  
//  AppearanceSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//


import SwiftUI
import Domain
import Combine
import CommonPresentation


// MARK: - AppearanceSettingViewState

final class AppearanceSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var calendarModel: CalendarAppearanceModel = .init([], [])
    @Published var accentDays: [AccentDays: Bool] = [:]
    @Published var showUnderLine: Bool = false
    @Published var selectedWeekDay: DayOfWeeks = .sunday
    let weekDayPickerSource: [DayOfWeeks] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    
    func bind(
        _ viewModel: any AppearanceSettingViewModel,
        _ calendarSectionViewModel: any CalendarSectionViewModel
    ) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        calendarSectionViewModel.currentWeekStartDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] day in
                self?.selectedWeekDay = day
            })
            .store(in: &self.cancellables)
        
        calendarSectionViewModel.calendarAppearanceModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                withAnimation {
                    self?.calendarModel = model
                }
            })
            .store(in: &self.cancellables)
        
        calendarSectionViewModel.accentDaysActivatedMap
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] map in
                self?.accentDays = map
            })
            .store(in: &self.cancellables)
        
        calendarSectionViewModel.isShowUnderLineOnEventDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.showUnderLine = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - AppearanceSettingViewEventHandler

final class AppearanceSettingViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var weekStartDaySelected: (DayOfWeeks) -> Void = { _ in }
    var changeColorTheme: () -> Void = { }
    var toggleAccentDay: (AccentDays) -> Void = { _ in }
    var toggleShowUnderline: (Bool) -> Void = { _ in }
}


// MARK: - AppearanceSettingContainerView

struct AppearanceSettingContainerView: View {
    
    @StateObject private var state: AppearanceSettingViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: AppearanceSettingViewEventHandler
    
    var stateBinding: (AppearanceSettingViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AppearanceSettingViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return AppearanceSettingView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - AppearanceSettingView

struct AppearanceSettingView: View {
    
    @EnvironmentObject private var state: AppearanceSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: AppearanceSettingViewEventHandler
    
    var body: some View {
        NavigationStack {
            Form {
                CalendarSectionView()
                    .listRowBackground(self.appearance.colorSet.dayBackground.asColor)
                
                Text("AppearanceSettingView")
            }
            .formStyle(PlainFormStyle())
            .scrollContentBackground(.hidden)
            .background(self.appearance.colorSet.dayBackground.asColor)
            .navigationTitle("Appearance".localized())
        }
    }
}

struct PlainFormStyle: FormStyle {
    
    @EnvironmentObject private var appearance: ViewAppearance
    
    func makeBody(configuration: Configuration) -> some View {
        return configuration.content
            .listRowSeparator(.hidden)
    }
}

// MARK: - preview

struct AppearanceSettingViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault,
            accnetDayPolicy: [:],
            showUnderLineOnEventDay: false,
            eventOnCalendar: .init()
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = AppearanceSettingViewState()
        let eventHandlers = AppearanceSettingViewEventHandler()
        eventHandlers.weekStartDaySelected = { day in
            withAnimation {
                state.calendarModel = .init(day)
            }
        }
        
        state.calendarModel = CalendarAppearanceModel(.sunday)
        state.accentDays = [.holiday: true, .sunday: true]
        state.selectedWeekDay = .sunday
        
        let view = AppearanceSettingView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}
