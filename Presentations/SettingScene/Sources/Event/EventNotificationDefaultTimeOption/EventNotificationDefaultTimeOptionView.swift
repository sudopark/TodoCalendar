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

final class EventNotificationDefaultTimeOptionViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var isNeedNotificationPermission: Bool = false
    @Published var options: [DefaultTimeOptionModel] = []
    @Published var selectedOption: EventNotificationTimeOption? = nil
    
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

final class EventNotificationDefaultTimeOptionViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var viewOnAppear: () -> Void = { }
    var requestPermission: () -> Void = { }
    var selectOption: (EventNotificationTimeOption?) -> Void = { _ in }
    var close: () -> Void = { }
}


// MARK: - EventNotificationDefaultTimeOptionContainerView

struct EventNotificationDefaultTimeOptionContainerView: View {
    
    @StateObject private var state: EventNotificationDefaultTimeOptionViewState = .init()
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventNotificationDefaultTimeOptionView

struct EventNotificationDefaultTimeOptionView: View {
    
    private let isForAllDay: Bool
    init(isForAllDay: Bool) {
        self.isForAllDay = isForAllDay
    }
    @EnvironmentObject private var state: EventNotificationDefaultTimeOptionViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                List {
                    
                    ForEach(state.options, id: \.option.id) {
                        optionView($0)
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
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
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                
                ConfirmButton(title: "event_notification_setting::need_permission::go_setting".localized())
                    .eventHandler(\.onTap, eventHandlers.requestPermission)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(appearance.colorSet.eventList.asColor)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
    
    private func optionView(_ model: DefaultTimeOptionModel) -> some View {
        return HStack {
            Text(model.text)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.normalText.asColor)
            
            Spacer(minLength: 20)
            
            if model.option == self.state.selectedOption {
                Image(systemName: "checkmark")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.eventList.asColor)
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
        }
    }
}


// MARK: - preview

struct EventNotificationDefaultTimeOptionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}
