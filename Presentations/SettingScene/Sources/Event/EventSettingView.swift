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
    @Published var periodModel: SelectedPeriodModel = .init(.hour1)
    
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
            
            ScrollView {
                
                VStack {
                    rowView(eventTypeView)
                        .onTapGesture(perform: eventHandlers.selectTag)
                    
                    rowView(eventNotificationTimeView)
                        .onTapGesture(perform: eventHandlers.selectEventNotificationTime)
                    
                    rowView(allDayEventNotificationTimeView)
                        .onTapGesture(perform: eventHandlers.selectAllDayEventNotificationTime)
                    
                    rowView(periodView)
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
            }
            .listStyle(.plain)
            .navigationTitle("Event Settings".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.close)
                }
            }
        }
    }
    
    private func rowView(_ content: some View) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(UIColor.systemGroupedBackground.asColor)
            )
            .listRowSeparator(.hidden)
    }
    
    private var eventTypeView: some View {
        HStack {
            Text("Event Type".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            Spacer()
            Circle()
                .fill(
                    self.state.tagModel?.color.color(with: appearance).asColor ?? .clear
                )
                .frame(width: 6, height: 6)
            Text(state.tagModel?.name ?? "")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subNormalText.asColor)
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
        }
    }
    
    private var eventNotificationTimeView: some View {
        HStack {
            Text("NotificationTime".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .layoutPriority(1)
            
            Spacer()
            
            Text(state.selectedEventNotificationTimeText ?? "")
                .lineLimit(1)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.subNormalText.asColor)
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
        }
    }
    
    private var allDayEventNotificationTimeView: some View {
        HStack {
            HStack {
                
                VStack(alignment: .leading) {
                    Text("NotificationTime".localized())
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                    
                    Text("Allday".localized())
                        .font(appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                }
                .layoutPriority(1)
                
                Spacer()
                
                Text(state.selectedAllDayEventNotificationTimeText ?? "")
                    .lineLimit(1)
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                
                Image(systemName: "chevron.right")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
            }
        }
    }
    
    private var periodView: some View {
        HStack {
            Text("Event Period".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            
            Spacer()
            
            Menu {
                
                Picker(selection: $state.periodModel) {
                    
                    ForEach(allPeriods, id: \.self) { model in
                        HStack {
                            if model.period == state.periodModel.period {
                                Image(systemName: "checkmark")
                                    .font(appearance.fontSet.normal.asFont)
                                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                            }
                            Text(model.text)
                                .font(appearance.fontSet.normal.asFont)
                                .foregroundStyle(appearance.colorSet.normalText.asColor)
                        }
                    }
                } label: { EmptyView() }
                
            } label: {
                HStack(spacing: 4) {
                    Text(state.periodModel.text)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                }
            }
        }
        .onReceive(state.$periodModel.map { $0.period}, perform: eventHandlers.selectPeriod)
    }
}


// MARK: - preview

struct EventSettingViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = EventSettingViewState()
        state.tagModel = .init(id: .default, name: "default", color: .default)
        state.periodModel = .init(EventSettings.DefaultNewEventPeriod.minute15)
        state.selectedEventNotificationTimeText = "so long text hahahahhahahha hahah"
        state.selectedAllDayEventNotificationTimeText = "so long text hahahahhahahha hahah"
        let eventHandlers = EventSettingViewEventHandler()
        let view = EventSettingView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

