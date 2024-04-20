//
//  
//  TimeZoneSelectView.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation


// MARK: - TimeZoneSelectViewState

final class TimeZoneSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var searchKeyword: String = ""
    @Published var systemTimeZone: TimeZoneModel?
    @Published var timeZones: [TimeZoneModel] = []
    @Published var selectedIdentifier: String?
    
    func bind(_ viewModel: any TimeZoneSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.timeZoneModels
            .subscribe(on: DispatchQueue(label: "search-queue"))
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] list in
                self?.systemTimeZone = list.systemTimeZone
                self?.timeZones = list.timeZones
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedTimeZoneIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.selectedIdentifier = identifier
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - TimeZoneSelectViewEventHandler

final class TimeZoneSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var timeZoneSelected: (String) -> Void = { _ in }
    var search: (String) -> Void = { _ in }
}


// MARK: - TimeZoneSelectContainerView

struct TimeZoneSelectContainerView: View {
    
    @StateObject private var state: TimeZoneSelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: TimeZoneSelectViewEventHandler
    
    var stateBinding: (TimeZoneSelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: TimeZoneSelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return TimeZoneSelectView()
            .onAppear {
                self.stateBinding(self.state)
                eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - TimeZoneSelectView

struct TimeZoneSelectView: View {
    
    @EnvironmentObject private var state: TimeZoneSelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: TimeZoneSelectViewEventHandler
    @FocusState var searchDidFocused: Bool
    
    var body: some View {
        NavigationStack{
         
            VStack {
                
                searchBarView
                    .padding(.horizontal)
                
                List {
                    if let system = state.systemTimeZone {
                        Section {
                            timezoneView(system)
                                .listRowSeparator(.hidden)
                                .listRowBackground(appearance.colorSet.eventList.asColor)
                        }
                    }
                    
                    Section {
                        ForEach(state.timeZones, id: \.identifier) { model in
                            timezoneView(model)
                        }
                        .listRowBackground(appearance.colorSet.eventList.asColor)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("TimeZone")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.close)
                }
            }
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.subNormalText.asColor)
            
            TextField(text: $state.searchKeyword) {
                Text("Search".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.subNormalText.asColor)
            }
            .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            .font(self.appearance.fontSet.subNormal.asFont)
            .focused($searchDidFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onReceive(state.$searchKeyword) { text in
                eventHandlers.search(text)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appearance.colorSet.eventList.asColor)
        )
    }
    
    private func timezoneView(_ model: TimeZoneModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                Text(model.identifier)
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                if let description = model.description {
                    Text(description)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.subNormalText.asColor)
                }
            }
            
            Spacer()
            
            if model.identifier == state.selectedIdentifier {
                Image(systemName: "checkmark")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
            }
        }
        // TODO: 터치영역 증가 필요
        .onTapGesture {
            eventHandlers.timeZoneSelected(model.identifier)
            searchDidFocused = false
        }
    }
}


// MARK: - preview

struct TimeZoneSelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting)
        let state = TimeZoneSelectViewState()
        let eventHandlers = TimeZoneSelectViewEventHandler()
        eventHandlers.timeZoneSelected = { state.selectedIdentifier = $0 }
        
        state.systemTimeZone = .init("Asia/Seoul", title: "시스템 설정")
        |> \.description .~ "대한민국 표준시 (GMT+9)"
        
        state.timeZones = [
            .init("Pacific/Midway", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway2", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway3", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midwa4", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway5", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway6", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway7", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway8", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)",
            .init("Pacific/Midway9", title: "미드웨이 시간") |> \.description .~ "사모아 표준시 (GMT-11)"
        ]
        state.selectedIdentifier = "Asia/Seoul"
        
        let view = TimeZoneSelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

