//
//  
//  CountrySelectView.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - CountrySelectViewState

final class CountrySelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any CountrySelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - CountrySelectViewEventHandler

final class CountrySelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - CountrySelectContainerView

struct CountrySelectContainerView: View {
    
    @StateObject private var state: CountrySelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: CountrySelectViewEventHandler
    
    var stateBinding: (CountrySelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: CountrySelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return CountrySelectView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - CountrySelectView

struct CountrySelectView: View {
    
    @EnvironmentObject private var state: CountrySelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: CountrySelectViewEventHandler
    
    var body: some View {
        Text("CountrySelectView")
    }
}


// MARK: - preview

struct CountrySelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff0000"),
            color: .defaultLight,
            font: .systemDefault
        )
        let state = CountrySelectViewState()
        let eventHandlers = CountrySelectViewEventHandler()
        
        let view = CountrySelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

