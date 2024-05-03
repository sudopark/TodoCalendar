//
//  
//  SelectEventTimeView.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SelectEventTimeViewState

final class SelectEventTimeViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SelectEventTimeViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - SelectEventTimeViewEventHandler

final class SelectEventTimeViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any SelectEventTimeViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - SelectEventTimeContainerView

struct SelectEventTimeContainerView: View {
    
    @StateObject private var state: SelectEventTimeViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectEventTimeViewEventHandler
    
    var stateBinding: (SelectEventTimeViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectEventTimeViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectEventTimeView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SelectEventTimeView

struct SelectEventTimeView: View {
    
    @EnvironmentObject private var state: SelectEventTimeViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SelectEventTimeViewEventHandler
    
    var body: some View {
        Text("SelectEventTimeView")
    }
}


// MARK: - preview

struct SelectEventTimeViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let tagSetting = DefaultEventTagColorSetting(
            holiday: "#ff0000", default: "#ff00ff"
        )
        let setting = AppearanceSettings(
            calendar: calendar, defaultTagColor: tagSetting
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = SelectEventTimeViewState()
        let eventHandlers = SelectEventTimeViewEventHandler()
        
        let view = SelectEventTimeView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

