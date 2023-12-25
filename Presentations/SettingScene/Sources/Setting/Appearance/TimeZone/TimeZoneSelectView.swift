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
import Domain
import CommonPresentation


// MARK: - TimeZoneSelectViewState

final class TimeZoneSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any TimeZoneSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - TimeZoneSelectViewEventHandler

final class TimeZoneSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
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
    
    var body: some View {
        Text("TimeZoneSelectView")
    }
}


// MARK: - preview

struct TimeZoneSelectViewPreviewProvider: PreviewProvider {

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
        let state = TimeZoneSelectViewState()
        let eventHandlers = TimeZoneSelectViewEventHandler()
        
        let view = TimeZoneSelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

