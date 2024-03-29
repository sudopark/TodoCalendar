//
//  
//  SelectEventNotificationTimeView.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation

// MARK: - SelectEventNotificationTimeViewState

final class SelectEventNotificationTimeViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var defaultTimeOptions: [NotificationTimeOptionModel] = []
    @Published var customTimeOptions: [CustomTimeOptionModel] = []
    @Published var selectedDefaultTimeOptions: [EventNotificationTimeOption] = []
    @Published var suggestCustomOptionTime: Date = Date()
    @Published var notificaitonPermissionDenied: Bool = false
    
    func isSelectedDefaultModel(_ option: EventNotificationTimeOption?) -> Bool {
        guard let option = option
        else {
            return self.selectedDefaultTimeOptions.isEmpty
        }
        return self.selectedDefaultTimeOptions.contains(where: { $0 == option} )
    }
    
    func bind(_ viewModel: any SelectEventNotificationTimeViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        let calendar = Calendar(identifier: .gregorian)
        self.suggestCustomOptionTime = calendar.date(from: viewModel.suggestCustomTimeComponents) ?? Date()
        
        viewModel.defaultTimeOptions
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.defaultTimeOptions = models
            })
            .store(in: &self.cancellables)
        
        viewModel.customTimeOptions
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.customTimeOptions = models
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedDefaultTimeOptions
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] options in
                self?.selectedDefaultTimeOptions = options
            })
            .store(in: &self.cancellables)
        
        viewModel.isNeedNotificaitonPermission
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in
                self?.notificaitonPermissionDenied = true
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - SelectEventNotificationTimeViewEventHandler

final class SelectEventNotificationTimeViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var toggleSelectDefaultOption: (EventNotificationTimeOption?) -> Void = { _ in }
    var addCustomTimeOption: (DateComponents) -> Void = { _ in }
    var removeCustomTimeOption: (DateComponents) -> Void = { _ in }
    var moveEventSetting: () -> Void = { }
    var moveSystemNotificationSetting: () -> Void = { }
    var close: () -> Void = { }
}


// MARK: - SelectEventNotificationTimeContainerView

struct SelectEventNotificationTimeContainerView: View {
    
    @StateObject private var state: SelectEventNotificationTimeViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectEventNotificationTimeViewEventHandler
    
    var stateBinding: (SelectEventNotificationTimeViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectEventNotificationTimeViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectEventNotificationTimeView()
            .onAppear {
                self.stateBinding(self.state)
                eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SelectEventNotificationTimeView

struct SelectEventNotificationTimeView: View {
    
    @EnvironmentObject private var state: SelectEventNotificationTimeViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SelectEventNotificationTimeViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                List {
                    
                    // default + no notification
                    Section {
                        self.defaultOptionView(nil)
                    }
                    .listRowInsets(.init(top: 20, leading: 20, bottom: 30, trailing: 20))
                    .listRowSeparator(.hidden)
                    
                    // default options
                    Section {
                        ForEach(state.defaultTimeOptions, id: \.compareKey) {
                            self.defaultOptionView($0)
                        }
                    }
                    .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowSeparator(.hidden)
                    
                    Spacer()
                        .frame(height: 0)
                        .listRowSeparator(.hidden)
                    
                    // custom options
                    Section {
                        ForEach(state.customTimeOptions, id: \.components) {
                            self.customOptionView($0)
                        }
                    } header: {
                        Text("Custom".localized())
                            .font(appearance.fontSet.bigBold.asFont)
                            .foregroundStyle(appearance.colorSet.normalText.asColor)
                        
                    }
                    .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowSeparator(.hidden)
                    
                    // add custom optoin
                    self.addCustimOptionView
                        .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowSeparator(.hidden)
                    
                    // move to setting view
                    self.moveToSettingView
                        .listRowInsets(.init(top: 30, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 10)
                .safeAreaInset(edge: .bottom) {
                    // TODO: permission 필요 뷰
                    if state.notificaitonPermissionDenied {
                        self.permissionNeedView
                    }
                }
            }
            .navigationTitle("event_notification_select::title".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                        .eventHandler(\.onTap, eventHandlers.close)
                }
            }
        }
    }
    
    private func defaultOptionView(_ model: NotificationTimeOptionModel?) -> some View {
        return HStack {
            Text(
                model?.text ?? "event_notification_setting::option_title::no_notification".localized()
            )
            .font(appearance.fontSet.normal.asFont)
            .foregroundStyle(appearance.colorSet.normalText.asColor)
            
            Spacer(minLength: 20)
            
            if state.isSelectedDefaultModel(model?.option) {
                Image(systemName: "checkmark")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.eventList.asColor)
        }
        .onTapGesture { eventHandlers.toggleSelectDefaultOption(model?.option) }
    }
    
    private func customOptionView(_ model: CustomTimeOptionModel) -> some View {
        return HStack {
            VStack {
                Text(model.dateText)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                Text(model.diffTimeText)
                    .font(appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
            }
            
            Spacer(minLength: 20)
            
            Image(systemName: "checkmark")
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.normalText.asColor)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.eventList.asColor)
        }
        .onTapGesture { eventHandlers.removeCustomTimeOption(model.components) }
    }
    
    private var addCustimOptionView: some View {
        
        return HStack {
            DatePicker(
                "",
                selection: $state.suggestCustomOptionTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            
            Spacer()
            
            Button {
                let calendar = Calendar(identifier: .gregorian)
                let components = calendar.dateComponents([
                    .year, .month, .day, .hour, .minute, .second
                ], from: state.suggestCustomOptionTime)
                eventHandlers.addCustomTimeOption(components)
                
            } label: {
                Image(systemName: "plus")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.accent.asColor)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.colorSet.eventList.asColor)
        }
    }
    
    private var moveToSettingView: some View {
        Button {
            eventHandlers.moveEventSetting()
        } label: {
            HStack(spacing: 4) {
                Spacer()
                Text("event_notification_select::move_to_setting".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.accent.asColor)
                
                Image(systemName: "chevron.right")
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.accent.asColor)
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
                    .eventHandler(\.onTap, eventHandlers.moveSystemNotificationSetting)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(appearance.colorSet.eventList.asColor)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}


private extension NotificationTimeOptionModel {
    
    var compareKey: String {
        return self.option.map { "\($0)" } ?? "nil"
    }
}

// MARK: - preview

struct SelectEventNotificationTimeViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = SelectEventNotificationTimeViewState()
        state.defaultTimeOptions = [
            .init(option: .atTime),
            .init(option: .before(seconds: 60)),
            .init(option: .before(seconds: 120)),
            .init(option: .before(seconds: 60*5.0))
        ]
        state.customTimeOptions = [
            .init(option: .custom(
                .init(year: 2024, month: 2, day: 3, hour: 12, minute: 30, second: 1))
            )!,
            .init(option: .custom(
                .init(year: 2024, month: 2, day: 8, hour: 13, minute: 30, second: 1))
            )!
        ]
        state.notificaitonPermissionDenied = true
        let eventHandlers = SelectEventNotificationTimeViewEventHandler()
        eventHandlers.addCustomTimeOption = { component in
            state.customTimeOptions.append(
                .init(option: .custom(component))!
            )
        }
        eventHandlers.removeCustomTimeOption = { component in
            state.customTimeOptions = state.customTimeOptions.filter { $0.components != component }
        }
        
        let view = SelectEventNotificationTimeView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

