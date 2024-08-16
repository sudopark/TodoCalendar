//
//  
//  FeedbackPostView.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - FeedbackPostViewState

final class FeedbackPostViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any FeedbackPostViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - FeedbackPostViewEventHandler

final class FeedbackPostViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any FeedbackPostViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - FeedbackPostContainerView

struct FeedbackPostContainerView: View {
    
    @StateObject private var state: FeedbackPostViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: FeedbackPostViewEventHandler
    
    var stateBinding: (FeedbackPostViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: FeedbackPostViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return FeedbackPostView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - FeedbackPostView

struct FeedbackPostView: View {
    
    @EnvironmentObject private var state: FeedbackPostViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: FeedbackPostViewEventHandler
    
    var body: some View {
        Text("FeedbackPostView")
    }
}


// MARK: - preview

struct FeedbackPostViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = FeedbackPostViewState()
        let eventHandlers = FeedbackPostViewEventHandler()
        
        let view = FeedbackPostView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

