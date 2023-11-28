//
//  
//  HolidayListView.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - HolidayListViewState

final class HolidayListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any HolidayListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - HolidayListViewEventHandler

final class HolidayListViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - HolidayListContainerView

struct HolidayListContainerView: View {
    
    @StateObject private var state: HolidayListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: HolidayListViewEventHandler
    
    var stateBinding: (HolidayListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: HolidayListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return HolidayListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - HolidayListView

struct HolidayListView: View {
    
    @EnvironmentObject private var state: HolidayListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: HolidayListViewEventHandler
    
    var body: some View {
        Text("HolidayListView")
    }
}


// MARK: - preview

struct HolidayListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let state = HolidayListViewState()
        let eventHandlers = HolidayListViewEventHandler()
        
        let view = HolidayListView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

