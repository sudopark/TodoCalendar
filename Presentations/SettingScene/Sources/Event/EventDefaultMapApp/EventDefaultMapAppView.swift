//
//  
//  EventDefaultMapAppView.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventDefaultMapAppViewState

@Observable final class EventDefaultMapAppViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var models: [SupportMapAppModel] = []
    
    func bind(_ viewModel: any EventDefaultMapAppViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.mapModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.models = models
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - EventDefaultMapAppViewEventHandler

final class EventDefaultMapAppViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var selectMap: (SupportMapApps) -> Void = { _ in}

    func bind(_ viewModel: any EventDefaultMapAppViewModel) {
        close = viewModel.close
        selectMap = viewModel.selectMap(_:)
    }
}


// MARK: - EventDefaultMapAppContainerView

struct EventDefaultMapAppContainerView: View {
    
    @State private var state: EventDefaultMapAppViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventDefaultMapAppViewEventHandler
    
    var stateBinding: (EventDefaultMapAppViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventDefaultMapAppViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventDefaultMapAppView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}

// MARK: - EventDefaultMapAppView

struct EventDefaultMapAppView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @Environment(EventDefaultMapAppViewState.self) private var state
    @Environment(EventDefaultMapAppViewEventHandler.self) private var eventHandlers
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(state.models, id: \.map) {
                    mapView($0)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowBackground(appearance.colorSet.bg0.asColor)
                }
            }
            .padding(.top, 20)
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.close)
                }
            }
            .navigationTitle("event_setting::defaultMapApp".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private func mapView(_ model: SupportMapAppModel) -> some View {
        HStack(spacing: 12) {
            Image(model.map.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            Text(model.map.name)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
            
            if model.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            eventHandlers.selectMap(model.map)
        }
    }
}


// MARK: - preview

struct EventDefaultMapAppViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = EventDefaultMapAppViewState()
        state.models = [
            .init(map: .apple),
            .init(map: .google, isSelected: true)
        ]
        let eventHandlers = EventDefaultMapAppViewEventHandler()
        
        let view = EventDefaultMapAppView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}

