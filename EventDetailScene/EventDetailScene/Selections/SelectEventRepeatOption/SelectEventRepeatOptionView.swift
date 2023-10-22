//
//  
//  SelectEventRepeatOptionView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - SelectEventRepeatOptionViewController

final class SelectEventRepeatOptionViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SelectEventRepeatOptionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - SelectEventRepeatOptionContainerView

struct SelectEventRepeatOptionContainerView: View {
    
    @StateObject private var state: SelectEventRepeatOptionViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (SelectEventRepeatOptionViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return SelectEventRepeatOptionView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - SelectEventRepeatOptionView

struct SelectEventRepeatOptionView: View {
    
    @EnvironmentObject private var state: SelectEventRepeatOptionViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("SelectEventRepeatOptionView")
    }
}


// MARK: - preview

struct SelectEventRepeatOptionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let containerView = SelectEventRepeatOptionContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

