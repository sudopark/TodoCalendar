//
//  
//  SelectEventTagView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - SelectEventTagViewController

final class SelectEventTagViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SelectEventTagViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - SelectEventTagContainerView

struct SelectEventTagContainerView: View {
    
    @StateObject private var state: SelectEventTagViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (SelectEventTagViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return SelectEventTagView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - SelectEventTagView

struct SelectEventTagView: View {
    
    @EnvironmentObject private var state: SelectEventTagViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("SelectEventTagView")
    }
}


// MARK: - preview

struct SelectEventTagViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let containerView = SelectEventTagContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

