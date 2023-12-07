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
    @Published var calendarModel: CalendarAppearanceModel?
    @Published var accentDays: [AccentDays: Bool] = [:]
    @Published var showUnderLine: Bool = false
    
    func bind(
        _ viewModel: any AppearanceSettingViewModel,
        _ calendarSectionViewModel: any CalendarSectionViewModel
    ) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        calendarSectionViewModel.calendarAppearanceModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.calendarModel = model
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
                Text("AppearanceSettingView")
            }
            .navigationTitle("Appearance".localized())
        }
    }
    
    private var calendarView: some View {
        VStack(spacing: 0) {
            
        }
    }
}

// MARK: - preview

struct AppearanceSettingViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let state = AppearanceSettingViewState()
        let eventHandlers = AppearanceSettingViewEventHandler()
        
        state.calendarModel = CalendarAppearanceModel(.sunday)
        state.accentDays = [.holiday: true, .sunday: true]
        
        let view = AppearanceSettingView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

