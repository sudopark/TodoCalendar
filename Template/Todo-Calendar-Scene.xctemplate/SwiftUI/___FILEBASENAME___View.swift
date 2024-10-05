//
//  ___FILEHEADER___
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - ___VARIABLE_sceneName___ViewState

final class ___VARIABLE_sceneName___ViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any ___VARIABLE_sceneName___ViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - ___VARIABLE_sceneName___ViewEventHandler

final class ___VARIABLE_sceneName___ViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any ___VARIABLE_sceneName___ViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - ___VARIABLE_sceneName___ContainerView

struct ___VARIABLE_sceneName___ContainerView: View {
    
    @StateObject private var state: ___VARIABLE_sceneName___ViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ___VARIABLE_sceneName___ViewEventHandler
    
    var stateBinding: (___VARIABLE_sceneName___ViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ___VARIABLE_sceneName___ViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return ___VARIABLE_sceneName___View()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - ___VARIABLE_sceneName___View

struct ___VARIABLE_sceneName___View: View {
    
    @EnvironmentObject private var state: ___VARIABLE_sceneName___ViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: ___VARIABLE_sceneName___ViewEventHandler
    
    var body: some View {
        Text("___VARIABLE_sceneName___View")
    }
}


// MARK: - preview

struct ___VARIABLE_sceneName___ViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = ___VARIABLE_sceneName___ViewState()
        let eventHandlers = ___VARIABLE_sceneName___ViewEventHandler()
        
        let view = ___VARIABLE_sceneName___View()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

