//
//  
//  SignInView.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SignInViewState

final class SignInViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SignInViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - SignInViewEventHandler

final class SignInViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any SignInViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - SignInContainerView

struct SignInContainerView: View {
    
    @StateObject private var state: SignInViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SignInViewEventHandler
    
    var stateBinding: (SignInViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SignInViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SignInView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SignInView

struct SignInView: View {
    
    @EnvironmentObject private var state: SignInViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SignInViewEventHandler
    
    var body: some View {
        Text("SignInView")
    }
}


// MARK: - preview

struct SignInViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = SignInViewState()
        let eventHandlers = SignInViewEventHandler()
        
        let view = SignInView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

