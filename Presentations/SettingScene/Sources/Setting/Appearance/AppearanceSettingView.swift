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
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                
                if let subTitle {
                    Text(subTitle)
                        .font(self.appearance.fontSet.size(10).asFont)
                        .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                }
            }
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(UIColor.systemGroupedBackground.asColor)
        )
    }
}


final class AppearanceSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var timeZoneName: String?
    @Published var hapticOn: Bool = false
    @Published var animationOn: Bool = false
    
    init(_ setting: AppearanceSettings) {
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
    
    private let initailSetting: AppearanceSettings
    private let calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler
    private let eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler
    private let eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    private let appearanceSettingEventHandler: AppearanceSettingViewEventHandler
    
    var calendarSectionStateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    var eventOnCalendarSectionStateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    var eventListSettingStateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    var appearanceSettingStateBinding: (AppearanceSettingViewState) -> Void = { _ in }
    
    init(
        _ setting: AppearanceSettings,
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
    
    private let initialSetting: AppearanceSettings
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
    
    init(_ setting: AppearanceSettings) {
        self.initialSetting = setting
        self._appearanceState = .init(wrappedValue: .init(setting))
    }
    
    var body: some View {
        NavigationStack {
            List {
                
                CalendarSectionAppearanceSettingView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, calendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.dayBackground.asColor)
                
                EventOnCalendarView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, eventOnCalendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.dayBackground.asColor)
                
                EventListAppearanceSettingView(.init(self.initialSetting))
                    .eventHandler(\.stateBinding, eventListSettingStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.dayBackground.asColor)
                
                generalSettingView
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.dayBackground.asColor)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(self.appearance.colorSet.dayBackground.asColor)
            .navigationTitle("Appearance".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        appearanceSettingEventHandler.close()
                    }
                }
            }
        }
    }
    
    private var generalSettingView: some View {
        
        func timeZoneView() -> some View {
            return HStack {
                
                Text(appearanceState.timeZoneName ?? "")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
                
                Image(systemName: "chevron.right")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
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
            
            AppearanceRow("Timezone".localized(), timeZoneView())
                .onTapGesture(perform: appearanceSettingEventHandler.changeTimeZone)
            
            AppearanceRow("Haptic feedback", hapticView())
                .onReceive(appearanceState.$hapticOn, perform: appearanceSettingEventHandler.toggleHapticFeedback)
            
            AppearanceRow("Minimize animation effect", animationView())
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
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        viewAppearance.accnetDayPolicy = [
            .sunday : true, .saturday: true, .holiday: true
        ]
        let calendar = CalendarSectionAppearanceSettingViewEventHandler()
        let eventOnCalendar = EventOnCalendarViewEventHandler()
        let eventListHandler = EventListAppearanceSettingViewEventHandler()
        let appearanaceEventHandler = AppearanceSettingViewEventHandler()
        
        return AppearanceSettingContainerView(
            setting,
            viewAppearance: viewAppearance,
            calendarSectionEventHandler: calendar,
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
