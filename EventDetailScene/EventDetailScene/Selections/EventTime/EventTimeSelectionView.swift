//
//  
//  EventTimeSelectionView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - EventTimeSelectionViewController

final class EventTimeSelectionViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventTimeSelectionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - EventTimeSelectionContainerView

struct EventTimeSelectionContainerView: View {
    
    @StateObject private var state: EventTimeSelectionViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (EventTimeSelectionViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTimeSelectionView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTimeSelectionView

struct EventTimeSelectionView: View {
    
    @EnvironmentObject private var state: EventTimeSelectionViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("EventTimeSelectionView")
    }
}


// MARK: - preview

struct EventTimeSelectionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#00ff00"),
            color: .defaultLight,
            font: .systemDefault
        )
        let containerView = EventTimeSelectionContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

