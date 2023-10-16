//
//  
//  AddEventView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - AddEventViewController

final class AddEventViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any AddEventViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - AddEventContainerView

struct AddEventContainerView: View {
    
    @StateObject private var state: AddEventViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (AddEventViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return AddEventView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - AddEventView

struct AddEventView: View {
    
    @EnvironmentObject private var state: AddEventViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("AddEventView")
    }
}


// MARK: - preview

struct AddEventViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#0000ff"),
            color: .defaultLight,
            font: .systemDefault
        )
        let containerView = AddEventContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

