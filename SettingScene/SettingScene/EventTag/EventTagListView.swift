//
//  
//  EventTagListView.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - EventTagListViewController

final class EventTagListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventTagListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - EventTagListContainerView

struct EventTagListContainerView: View {
    
    @StateObject private var state: EventTagListViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (EventTagListViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTagListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTagListView

struct EventTagListView: View {
    
    @EnvironmentObject private var state: EventTagListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("EventTagListView")
    }
}


// MARK: - preview

struct EventTagListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let containerView = EventTagListContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

