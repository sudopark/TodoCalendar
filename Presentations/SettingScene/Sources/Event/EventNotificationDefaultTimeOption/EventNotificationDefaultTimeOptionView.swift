//
//  
//  EventNotificationDefaultTimeOptionView.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventNotificationDefaultTimeOptionViewState

@Observable final class EventNotificationDefaultTimeOptionViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var isNeedNotificationPermission: Bool = false
    var options: [DefaultTimeOptionModel] = []
    var selectedOption: EventNotificationTimeOption? = nil
    
    func bind(_ viewModel: any EventNotificationDefaultTimeOptionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.isNeedNotificationPermission
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isNeedNotificationPermission = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.options
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] options in
                self?.options = options
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] option in
                self?.selectedOption = option
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - EventNotificationDefaultTimeOptionViewEventHandler

final class EventNotificationDefaultTimeOptionViewEventHandler: Observable {
    
    // TODO: add handlers
    var viewOnAppear: () -> Void = { }
    var requestPermission: () -> Void = { }
    var selectOption: (EventNotificationTimeOption?) -> Void = { _ in }
    var close: () -> Void = { }
}


// MARK: - EventNotificationDefaultTimeOptionContainerView

struct EventNotificationDefaultTimeOptionContainerView: View {
    
    @State private var state: EventNotificationDefaultTimeOptionViewState = .init()
    private let isForAllDay: Bool
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    
    var stateBinding: (EventNotificationDefaultTimeOptionViewState) -> Void = { _ in }
    
    init(
        isForAllDay: Bool,
        viewAppearance: ViewAppearance,
        eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    ) {
        self.isForAllDay = isForAllDay
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventNotificationDefaultTimeOptionView(isForAllDay: isForAllDay)
            .onAppear {
                self.stateBinding(self.state)
                eventHandlers.viewOnAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventNotificationDefaultTimeOptionView

struct EventNotificationDefaultTimeOptionView: View {
    
    private let isForAllDay: Bool
    init(isForAllDay: Bool) {
        self.isForAllDay = isForAllDay
    }
    @Environment(EventNotificationDefaultTimeOptionViewState.self) private var state
    @Environment(EventNotificationDefaultTimeOptionViewEventHandler.self) private var eventHandlers
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                List {
                    
                    ForEach(state.options, id: \.option.id) {
                        optionView($0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                }
                .listStyle(.plain)
                .background(appearance.colorSet.bg0.asColor)
                .safeAreaInset(edge: .bottom) {
                    if state.isNeedNotificationPermission {
                        permissionNeedView
                    }
                }
            }
            .navigationTitle(
                isForAllDay
                ? "event_notification_setting::title::forAllDay".localized()
                : "event_notification_setting::title::NotforAllDay".localized()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.close)
                }
            }
        }
            .id(appearance.navigationBarId)
    }
    
    private var permissionNeedView: some View {
        VStack(spacing: 0) {
            
//            Spacer()
            
            Rectangle()
                .fill(appearance.colorSet.line.asColor)
                .frame(height: 0.5)
            
            VStack(spacing: 16) {
                Text("event_notification_setting::need_permission_message".localized())
                    .multilineTextAlignment(.center)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                ConfirmButton(title: "event_notification_setting::need_permission::go_setting".localized())
                    .eventHandler(\.onTap, eventHandlers.requestPermission)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(appearance.colorSet.bg2.asColor)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
    
    private func optionView(_ model: DefaultTimeOptionModel) -> some View {
        return HStack {
            Text(model.text)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer(minLength: 20)
            
            if model.option == self.state.selectedOption {
                Image(systemName: "checkmark")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.bg1.asColor)
        }
        .onTapGesture {
            eventHandlers.selectOption(model.option)
        }
    }
}

private extension Optional where Wrapped == EventNotificationTimeOption {
    var id: String {
        switch self {
        case .none: return "none"
        case .atTime: return "atTime"
        case .before(let seconds): return "before:\(seconds)"
        case .allDay9AM: return "allDay9AM"
        case .allDay12AM: return "allDay12AM"
        case .allDay9AMBefore(let seconds): return "allDay9AMBefore:\(seconds)"
        case .custom(let components):
            return "custom:\(components)"
        }
    }
}


// MARK: - preview

struct EventNotificationDefaultTimeOptionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = EventNotificationDefaultTimeOptionViewState()
        state.isNeedNotificationPermission = true
        state.options = [
            .init(option: nil),
            .init(option: .atTime),
            .init(option: .before(seconds: 60)),
            .init(option: .before(seconds: 60*3.0)),
            .init(option: .before(seconds: 60*5.0)),
            .init(option: .before(seconds: 60*10.0)),
            .init(option: .before(seconds: 60*60.0)),
            .init(option: .before(seconds: 60*60.0*2)),
            .init(option: .before(seconds: 60*60.0*3)),
            .init(option: .before(seconds: 60*60.0*24)),
            .init(option: .before(seconds: 60*60.48)),
            .init(option: .before(seconds: 60*60.24*7)),
            .init(option: .before(seconds: 60*60.24*14)),
        ]
        let eventHandlers = EventNotificationDefaultTimeOptionViewEventHandler()
        eventHandlers.selectOption = { state.selectedOption = $0 }
        eventHandlers.requestPermission = { state.isNeedNotificationPermission.toggle() }
        
        let view = EventNotificationDefaultTimeOptionView(isForAllDay: false)
            .environment(state)
            .environment(eventHandlers)
            .environmentObject(viewAppearance)
        return view
    }
}
