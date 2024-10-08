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


struct AppearanceRow< Content: View>: View {
    
    private let title: String
    private let subTitle: String?
    private let content: Content
    @EnvironmentObject private var appearance: ViewAppearance
    
    init(_ title: String, subTitle: String? = nil, _ content: Content) {
        self.title = title
        self.subTitle = subTitle
        self.content = content
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                if let subTitle {
                    Text(subTitle)
                        .font(self.appearance.fontSet.size(10).asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }
            }
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.bg1.asColor)
        )
    }
}


final class AppearanceSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var timeZoneName: String?
    @Published var hapticOn: Bool = false
    @Published var animationOn: Bool = false
    
    init(_ setting: CalendarAppearanceSettings) {
        self.hapticOn = setting.hapticEffectIsOn
        self.animationOn = setting.animationEffectIsOn
    }
    
    func bind(_ viewModel: any AppearanceSettingViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.currentTimeZoneName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.timeZoneName = name
            })
            .store(in: &self.cancellables)
        
        viewModel.hapticIsOn
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.hapticOn = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.animationIsOn
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.animationOn = flag
            })
            .store(in: &self.cancellables)
    }
}

final class AppearanceSettingViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var changeTimeZone: () -> Void = { }
    var toggleHapticFeedback: (Bool) -> Void = { _ in }
    var toggleAnimationEffect: (Bool) -> Void = { _ in }
    var close: () -> Void = { }
}

// MARK: - AppearanceSettingContainerView

struct AppearanceSettingContainerView: View {
    
    private let viewAppearance: ViewAppearance
    
    private let initailSetting: CalendarAppearanceSettings
    private let calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler
    private let eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler
    private let eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    private let appearanceSettingEventHandler: AppearanceSettingViewEventHandler
    
    var calendarSectionStateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    var eventOnCalendarSectionStateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    var eventListSettingStateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    var appearanceSettingStateBinding: (AppearanceSettingViewState) -> Void = { _ in }
    
    init(
        _ setting: CalendarAppearanceSettings,
        viewAppearance: ViewAppearance,
        calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler,
        eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler,
        eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler,
        appearanceSettingEventHandler: AppearanceSettingViewEventHandler
    ) {
        self.initailSetting = setting
        self.viewAppearance = viewAppearance
        self.calendarSectionEventHandler = calendarSectionEventHandler
        self.eventOnCalendarSectionEventHandler = eventOnCalendarSectionEventHandler
        self.eventListSettingEventHandler = eventListSettingEventHandler
        self.appearanceSettingEventHandler = appearanceSettingEventHandler
    }
    
    var body: some View {
        return AppearanceSettingView(initailSetting)
            .eventHandler(\.calendarSectionStateBinding, calendarSectionStateBinding)
            .eventHandler(\.eventOnCalendarSectionStateBinding, eventOnCalendarSectionStateBinding)
            .eventHandler(\.eventListSettingStateBinding, eventListSettingStateBinding)
            .eventHandler(\.appearanceSettingStateBinding, appearanceSettingStateBinding)
            .environmentObject(viewAppearance)
            .environmentObject(calendarSectionEventHandler)
            .environmentObject(eventOnCalendarSectionEventHandler)
            .environmentObject(appearanceSettingEventHandler)
            .environmentObject(eventListSettingEventHandler)
    }
}

// MARK: - AppearanceSettingView

struct AppearanceSettingView: View {
    
    private let initialSetting: CalendarAppearanceSettings
    @StateObject private var appearanceState: AppearanceSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler
    @EnvironmentObject private var eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler
    @EnvironmentObject private var eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    @EnvironmentObject private var appearanceSettingEventHandler: AppearanceSettingViewEventHandler
    
    fileprivate var calendarSectionStateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    fileprivate var eventOnCalendarSectionStateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    fileprivate var eventListSettingStateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    fileprivate var appearanceSettingStateBinding: (AppearanceSettingViewState) -> Void = { _ in }
    
    init(_ setting: CalendarAppearanceSettings) {
        self.initialSetting = setting
        self._appearanceState = .init(wrappedValue: .init(setting))
    }
    
    var body: some View {
        NavigationStack {
            List {
                
                CalendarSectionAppearanceSettingView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, calendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.bg0.asColor)
                
                EventOnCalendarView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, eventOnCalendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.bg0.asColor)
                
                EventListAppearanceSettingView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, eventListSettingStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                
                generalSettingView
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(self.appearance.colorSet.bg0.asColor)
            .navigationTitle("setting.appearance.title".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        appearanceSettingEventHandler.close()
                    }
                }
            }
        }
            .id(appearance.navigationBarId)
    }
    
    private var generalSettingView: some View {
        
        func timeZoneView() -> some View {
            return HStack {
                
                Text(appearanceState.timeZoneName ?? "")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
                
                Image(systemName: "chevron.right")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
        }
        
        func hapticView() -> some View {
            Toggle("", isOn: $appearanceState.hapticOn)
                .controlSize(.small)
                .labelsHidden()
        }
        
        func animationView() -> some View {
            Toggle("", isOn: $appearanceState.animationOn)
                .controlSize(.small)
                .labelsHidden()
        }
        
        return VStack {
            
            AppearanceRow("setting.timezone::title".localized(), timeZoneView())
                .onTapGesture(perform: appearanceSettingEventHandler.changeTimeZone)
            
            AppearanceRow("setting.haptic::name".localized(), hapticView())
                .onReceive(appearanceState.$hapticOn, perform: appearanceSettingEventHandler.toggleHapticFeedback)
            
            AppearanceRow("setting.minimize_animation::name".localized(), animationView())
                .onReceive(appearanceState.$animationOn, perform: appearanceSettingEventHandler.toggleAnimationEffect)
        }
        .padding(.top, 20)
        .onAppear {
            self.appearanceSettingStateBinding(self.appearanceState)
            appearanceSettingEventHandler.onAppear()
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
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        viewAppearance.accnetDayPolicy = [
            .sunday : true, .saturday: true, .holiday: true
        ]
        viewAppearance.showUnderLineOnEventDay = true
        let calendarHandler = CalendarSectionAppearanceSettingViewEventHandler()
        let eventOnCalendar = EventOnCalendarViewEventHandler()
        let eventListHandler = EventListAppearanceSettingViewEventHandler()
        let appearanaceEventHandler = AppearanceSettingViewEventHandler()
        
        return AppearanceSettingContainerView(
            calendar,
            viewAppearance: viewAppearance,
            calendarSectionEventHandler: calendarHandler,
            eventOnCalendarSectionEventHandler: eventOnCalendar,
            eventListSettingEventHandler: eventListHandler,
            appearanceSettingEventHandler: appearanaceEventHandler
        )
        .eventHandler(\.calendarSectionStateBinding) {
            $0.calendarModel = .init(.monday)
            $0.accentDays = [.holiday: true, .sunday: true]
            $0.selectedWeekDay = .monday
            $0.showUnderLine = true
        }
        .eventHandler(\.eventOnCalendarSectionStateBinding) {
            $0.additionalFontSizeModel = .init(3)
            $0.isShowEventTagColor = true
        }
    }
}
