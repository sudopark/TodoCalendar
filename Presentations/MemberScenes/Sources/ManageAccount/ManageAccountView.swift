//
//  
//  ManageAccountView.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - ManageAccountViewState

final class ManageAccountViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any ManageAccountViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - ManageAccountViewEventHandler

final class ManageAccountViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any ManageAccountViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - ManageAccountContainerView

struct ManageAccountContainerView: View {
    
    @StateObject private var state: ManageAccountViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ManageAccountViewEventHandler
    
    var stateBinding: (ManageAccountViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ManageAccountViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return ManageAccountView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - ManageAccountView

struct ManageAccountView: View {
    
    @EnvironmentObject private var state: ManageAccountViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: ManageAccountViewEventHandler
    
    var body: some View {
        Text("ManageAccountView")
    }
}


// MARK: - preview

struct ManageAccountViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = ManageAccountViewState()
        let eventHandlers = ManageAccountViewEventHandler()
        
        let view = ManageAccountView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

