//
//  
//  EventTagDetailView.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - EventTagDetailViewController

final class EventTagDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventTagDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - EventTagDetailContainerView

struct EventTagDetailContainerView: View {
    
    @StateObject private var state: EventTagDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (EventTagDetailViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTagDetailView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTagDetailView

struct EventTagDetailView: View {
    
    @EnvironmentObject private var state: EventTagDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("EventTagDetailView")
    }
}


// MARK: - preview

struct EventTagDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let containerView = EventTagDetailContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

