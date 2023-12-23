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


// MARK: - AppearanceSettingContainerView

struct AppearanceSettingContainerView: View {
    
    private let viewAppearance: ViewAppearance
    
    private let calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler
    private let eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler
    private let eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    
    var calendarSectionStateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    var eventOnCalendarSectionStateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    var eventListSettingStateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler,
        eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler,
        eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.calendarSectionEventHandler = calendarSectionEventHandler
        self.eventOnCalendarSectionEventHandler = eventOnCalendarSectionEventHandler
        self.eventListSettingEventHandler = eventListSettingEventHandler
    }
    
    var body: some View {
        return AppearanceSettingView()
            .eventHandler(\.calendarSectionStateBinding, calendarSectionStateBinding)
            .eventHandler(\.eventOnCalendarSectionStateBinding, eventOnCalendarSectionStateBinding)
            .eventHandler(\.eventListSettingStateBinding, eventListSettingStateBinding)
            .environmentObject(viewAppearance)
            .environmentObject(calendarSectionEventHandler)
            .environmentObject(eventOnCalendarSectionEventHandler)
            .environmentObject(eventListSettingEventHandler)
    }
}

// MARK: - AppearanceSettingView

struct AppearanceSettingView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var calendarSectionEventHandler: CalendarSectionAppearanceSettingViewEventHandler
    @EnvironmentObject private var eventOnCalendarSectionEventHandler: EventOnCalendarViewEventHandler
    @EnvironmentObject private var eventListSettingEventHandler: EventListAppearanceSettingViewEventHandler
    
    fileprivate var calendarSectionStateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    fileprivate var eventOnCalendarSectionStateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    fileprivate var eventListSettingStateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    
    var body: some View {
        NavigationStack {
            List {
                
                CalendarSectionAppearanceSettingView()
                    .eventHandler(\.stateBinding, calendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.dayBackground.asColor)
                
                EventOnCalendarView()
                    .eventHandler(\.stateBinding, eventOnCalendarSectionStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(self.appearance.colorSet.dayBackground.asColor)
                
                EventListAppearanceSettingView()
                    .eventHandler(\.stateBinding, eventListSettingStateBinding)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.dayBackground.asColor)
                
                Text("AppearanceSettingView")
                
                Text("AppearanceSettingView")
            }
            .listStyle(.plain)
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
            eventOnCalendar: .init(),
            eventList: .init()
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let calendar = CalendarSectionAppearanceSettingViewEventHandler()
        let eventOnCalendar = EventOnCalendarViewEventHandler()
        let eventListHandler = EventListAppearanceSettingViewEventHandler()
        
        return AppearanceSettingContainerView(
            viewAppearance: viewAppearance,
            calendarSectionEventHandler: calendar,
            eventOnCalendarSectionEventHandler: eventOnCalendar,
            eventListSettingEventHandler: eventListHandler
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
