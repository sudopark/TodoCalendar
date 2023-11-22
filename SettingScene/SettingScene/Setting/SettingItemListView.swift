//
//  
//  SettingItemListView.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - SettingItemListViewState

final class SettingItemListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SettingItemListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - SettingItemListViewEventHandler

final class SettingItemListViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - SettingItemListContainerView

struct SettingItemListContainerView: View {
    
    @StateObject private var state: SettingItemListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SettingItemListViewEventHandler
    
    var stateBinding: (SettingItemListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SettingItemListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SettingItemListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SettingItemListView

struct SettingItemListView: View {
    
    @EnvironmentObject private var state: SettingItemListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SettingItemListViewEventHandler
    
    var body: some View {
        Text("SettingItemListView")
    }
}


// MARK: - preview

struct SettingItemListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let state = SettingItemListViewState()
        let eventHandlers = SettingItemListViewEventHandler()
        
        let view = SettingItemListView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

