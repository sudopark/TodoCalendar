//
//  
//  GoogleCalendarEventDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - GoogleCalendarEventDetailViewState

final class GoogleCalendarEventDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - GoogleCalendarEventDetailViewEventHandler

final class GoogleCalendarEventDetailViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - GoogleCalendarEventDetailContainerView

struct GoogleCalendarEventDetailContainerView: View {
    
    @StateObject private var state: GoogleCalendarEventDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: GoogleCalendarEventDetailViewEventHandler
    
    var stateBinding: (GoogleCalendarEventDetailViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: GoogleCalendarEventDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return GoogleCalendarEventDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - GoogleCalendarEventDetailView

struct GoogleCalendarEventDetailView: View {
    
    @EnvironmentObject private var state: GoogleCalendarEventDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: GoogleCalendarEventDetailViewEventHandler
    
    var body: some View {
        Text("GoogleCalendarEventDetailView")
    }
}


// MARK: - preview

struct GoogleCalendarEventDetailViewPreviewProvider: PreviewProvider {

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
        let state = GoogleCalendarEventDetailViewState()
        let eventHandlers = GoogleCalendarEventDetailViewEventHandler()
        
        let view = GoogleCalendarEventDetailView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

