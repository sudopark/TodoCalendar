//
//  
//  DoneTodoEventListView.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - DoneTodoEventListViewState

final class DoneTodoEventListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any DoneTodoEventListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - DoneTodoEventListViewEventHandler

final class DoneTodoEventListViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any DoneTodoEventListViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - DoneTodoEventListContainerView

struct DoneTodoEventListContainerView: View {
    
    @StateObject private var state: DoneTodoEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: DoneTodoEventListViewEventHandler
    
    var stateBinding: (DoneTodoEventListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: DoneTodoEventListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return DoneTodoEventListView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - DoneTodoEventListView

struct DoneTodoEventListView: View {
    
    @EnvironmentObject private var state: DoneTodoEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: DoneTodoEventListViewEventHandler
    
    var body: some View {
        Text("DoneTodoEventListView")
    }
}


// MARK: - preview

struct DoneTodoEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = DoneTodoEventListViewState()
        let eventHandlers = DoneTodoEventListViewEventHandler()
        
        let view = DoneTodoEventListView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

