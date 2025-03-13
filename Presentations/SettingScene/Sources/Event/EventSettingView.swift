//
//  
//  EventSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventSettingViewState

final class EventSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var tagModel: EventTagCellViewModel?
    @Published var selectedEventNotificationTimeText: String?
    @Published var selectedAllDayEventNotificationTimeText: String?
    @Published var periodModel: SelectedPeriodModel = .init(.minute0)
    @Published var externalCalendarServiceModels: [ExternalCalanserServiceModel] = []
    @Published var isConnectOrDisconnectingExternalService: Bool = false
    
    func bind(_ viewModel: any EventSettingViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.selectedTagModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.tagModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedEventNotificationTimeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.selectedEventNotificationTimeText = text
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedAllDayEventNotificationTimeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.selectedAllDayEventNotificationTimeText = text
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedPeriod
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.periodModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.integratedExternalCalendars
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.externalCalendarServiceModels = models
            })
            .store(in: &self.cancellables)
        
        viewModel.isConnectOrDisconnectExternalCalednar
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isConnectOrDisconnectingExternalService = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - EventSettingViewEventHandler

final class EventSettingViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var onWillAppear: () -> Void = { }
    var selectTag: () -> Void = { }
    var selectEventNotificationTime: () -> Void = { }
    var selectAllDayEventNotificationTime: () -> Void = { }
    var selectPeriod: (EventSettings.DefaultNewEventPeriod) -> Void = { _ in }
    var connectExternalCalendar: (String) -> Void = { _ in }
    var disconnectExternalCalendar: (String) -> Void = { _ in }
    var close: () -> Void = { }
}


// MARK: - EventSettingContainerView

struct EventSettingContainerView: View {
    
    @StateObject private var state: EventSettingViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventSettingViewEventHandler
    
    var stateBinding: (EventSettingViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventSettingViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventSettingView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .onWillAppear(eventHandlers.onWillAppear)
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventSettingView

struct EventSettingView: View {
    
    @EnvironmentObject private var state: EventSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventSettingViewEventHandler
    
    let allPeriods: [SelectedPeriodModel] = [
        .init(.minute0), .init(.minute5), .init(.minute10), .init(.minute15),
        .init(.minute30), .init(.minute45), .init(.hour1), .init(.hour2), .init(.allDay)
    ]
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        rowView(eventTypeView)
                            .onTapGesture(perform: eventHandlers.selectTag)
                        
                        rowView(eventNotificationTimeView)
                            .onTapGesture(perform: eventHandlers.selectEventNotificationTime)
                        
                        rowView(allDayEventNotificationTimeView)
                            .onTapGesture(perform: eventHandlers.selectAllDayEventNotificationTime)
                        
                        rowView(periodView)
                        
                        if FeatureFlag.isEnable(.googleCalendar) && !self.state.externalCalendarServiceModels.isEmpty {
                            self.externalCalendarSectionView(state.externalCalendarServiceModels)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                }
                .listStyle(.plain)
                .background(appearance.colorSet.bg0.asColor)
                
                if FeatureFlag.isEnable(.googleCalendar) {
                    FullScreenLoadingView(isLoading: $state.isConnectOrDisconnectingExternalService)
                }
            }
            .navigationTitle("event_setting::title".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.close)
                }
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private func rowView(_ content: some View) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(appearance.colorSet.bg1.asColor)
            )
            .listRowSeparator(.hidden)
    }
    
    private var eventTypeView: some View {
        HStack {
            Text("event_setting::eventType".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            Spacer()
            Circle()
                .fill(
                    appearance.color(self.state.tagModel?.id).asColor
                )
                .frame(width: 6, height: 6)
            Text(state.tagModel?.name ?? "")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }
    
    private var eventNotificationTimeView: some View {
        HStack {
            Text("event_notification_setting::title::NotforAllDay".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .layoutPriority(1)
            
            Spacer()
            
            Text(state.selectedEventNotificationTimeText ?? "")
                .lineLimit(1)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }
    
    private var allDayEventNotificationTimeView: some View {
        HStack {
            HStack {
                
                VStack(alignment: .leading) {
                    Text("event_notification_setting::title::NotforAllDay".localized())
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    
                    Text("event_notification_setting::title::forAllDay".localized())
                        .font(appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                }
                .layoutPriority(1)
                
                Spacer()
                
                Text(state.selectedAllDayEventNotificationTimeText ?? "")
                    .lineLimit(1)
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text1.asColor)
                
                Image(systemName: "chevron.right")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
        }
    }
    
    private var periodView: some View {
        HStack {
            Text("event_setting::eventPeriod".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Spacer()
            
            Menu {
                
                Picker(selection: $state.periodModel) {
                    
                    ForEach(allPeriods, id: \.self) { model in
                        HStack {
                            if model.period == state.periodModel.period {
                                Image(systemName: "checkmark")
                                    .font(appearance.fontSet.normal.asFont)
                                    .foregroundStyle(appearance.colorSet.text0.asColor)
                            }
                            Text(model.text)
                                .font(appearance.fontSet.normal.asFont)
                                .foregroundStyle(appearance.colorSet.text0.asColor)
                        }
                    }
                } label: { EmptyView() }
                
            } label: {
                HStack(spacing: 4) {
                    Text(state.periodModel.text)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                }
            }
        }
        .onReceive(state.$periodModel.map { $0.period}, perform: eventHandlers.selectPeriod)
    }
    
    private func externalCalendarSectionView(_ models: [ExternalCalanserServiceModel]) -> some View {
        
        VStack(alignment: .leading) {
            Text("event_setting::external_calendar::title".localized())
                .font(appearance.fontSet.size(16, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            ForEach(models, id: \.compareKey) { model in
                rowView(externalCalendarRowView(model))
            }
        }
        .padding(.top, 20)
    }
    
    private func externalCalendarRowView(_ model: ExternalCalanserServiceModel) -> some View {
        return HStack {
            Image(model.serviceIconName)
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
            
            VStack(alignment: .leading) {
                Text(model.serviceName)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                if let account = model.accountName {
                    Text("event_setting::external_calendar::connected::account".localized(with: account))
                        .font(appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                }
            }
            
            Spacer()
            
            switch model.status {
            case .integrated:
               Button {
                   eventHandlers.disconnectExternalCalendar(model.serviceId)
                } label: {
                    Text("event_setting::external_calendar::stop".localized())
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.negativeBtnBackground.asColor)
                }
                
                
            case .notIntegrated:
                Button {
                    eventHandlers.connectExternalCalendar(model.serviceId)
                 } label: {
                     Text("event_setting::external_calendar::start".localized())
                         .font(appearance.fontSet.subNormal.asFont)
                         .foregroundStyle(appearance.colorSet.primaryBtnBackground.asColor)
                 }
            }
        }
    }
}

private extension ExternalCalanserServiceModel {
    
    var accountName: String? {
        guard case .integrated(let accountName) = self.status else { return nil }
        return accountName
    }
    
    var compareKey: String {
        let statusKey = switch self.status {
        case .notIntegrated: "notIntegrated"
        case .integrated(let accountName): "integrated:\(accountName ?? "none")"
        }
        return "\(self.serviceId)_\(statusKey)"
    }
}


// MARK: - preview

struct EventSettingViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = EventSettingViewState()
        state.tagModel = .init(
            DefaultEventTag.default("#ff00ff")
        )
        state.periodModel = .init(EventSettings.DefaultNewEventPeriod.minute15)
        state.selectedEventNotificationTimeText = "so long text hahahahhahahha hahah"
        state.selectedAllDayEventNotificationTimeText = "so long text hahahahhahahha hahah"
        state.externalCalendarServiceModels = [
            ExternalCalanserServiceModel(
                GoogleCalendarService(scopes: [.readOnly]),
                with: nil
//                        .init("google", email: "some@email.com")
            )!
        ]
        let eventHandlers = EventSettingViewEventHandler()
        eventHandlers.connectExternalCalendar = { _ in
            state.isConnectOrDisconnectingExternalService = true
        }
        let view = EventSettingView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

