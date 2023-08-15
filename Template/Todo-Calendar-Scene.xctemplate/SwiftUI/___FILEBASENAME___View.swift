//
//  ___FILEHEADER___
//


import SwiftUI
import Combine
import CommonPresentation


// MARK: - ___VARIABLE_sceneName___ViewController

final class ___VARIABLE_sceneName___ViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: ___VARIABLE_sceneName___ViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}


// MARK: - ___VARIABLE_sceneName___ContainerView

struct ___VARIABLE_sceneName___ContainerView: View {
    
    @StateObject private var state: ___VARIABLE_sceneName___ViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var stateBinding: (___VARIABLE_sceneName___ViewState) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return ___VARIABLE_sceneName___View()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - ___VARIABLE_sceneName___View

struct ___VARIABLE_sceneName___View: View {
    
    @EnvironmentObject private var state: ___VARIABLE_sceneName___ViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        Text("___VARIABLE_sceneName___View")
    }
}


// MARK: - preview

struct ___VARIABLE_sceneName___ViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewAppearance = ViewAppearance(color: .defaultLight, font: .systemDefault)
        let containerView = ___VARIABLE_sceneName___ContainerView(viewAppearance: viewAppearance)
        return containerView
    }
}

