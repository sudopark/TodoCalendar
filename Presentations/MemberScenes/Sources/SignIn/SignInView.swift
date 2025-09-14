//
//  
//  SignInView.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SignInViewState

final class SignInViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var isSigning = false
    @Published var supportOAuthServices: [any OAuth2ServiceProvider] = []
    
    func bind(_ viewModel: any SignInViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.isSigningIn
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSigning = flag
            })
            .store(in: &self.cancellables)
        
        self.supportOAuthServices = viewModel.supportSignInOAuthService
    }
}

// MARK: - SignInViewEventHandler

final class SignInViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var requestSignIn: (any OAuth2ServiceProvider) -> Void = { _ in }

    func bind(_ viewModel: any SignInViewModel) {
        // TODO: bind handlers
        self.close = viewModel.close
        self.requestSignIn = viewModel.signIn(_:)
    }
}


// MARK: - SignInContainerView

struct SignInContainerView: View {
    
    @StateObject private var state: SignInViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SignInViewEventHandler
    private let signInButtonProvider: any SignInButtonProvider
    
    var stateBinding: (SignInViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SignInViewEventHandler,
        signInButtonProvider: any SignInButtonProvider
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
        self.signInButtonProvider = signInButtonProvider
    }
    
    var body: some View {
        return SignInView(signInButtonProvider: signInButtonProvider)
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SignInView

struct SignInView: View {
    
    @EnvironmentObject private var state: SignInViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SignInViewEventHandler
    private let signInButtonProvider: any SignInButtonProvider
    @State private var rotateDegree : CGFloat = 0
    
    init(signInButtonProvider: any SignInButtonProvider) {
        self.signInButtonProvider = signInButtonProvider
    }
    
    var body: some View {
        
        ZStack {
         
            BottomSlideView {
                VStack(spacing: 18) {
                    
                    Text("🧐")
                        .font(appearance.fontSet.size(30).asFont)
                        .rotationEffect(Angle.degrees(rotateDegree))
                        .onAppear {
                            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: true)) {
                                self.rotateDegree = -20
                            }
                        }
                    
                    Text("signIn::title".localized())
                        .font(appearance.fontSet.big.asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                        .multilineTextAlignment(.center)
                    
                    Text("signIn:description".localized())
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 10) {
                        ForEach(state.supportOAuthServices, id: \.identifier) { provider in
                            self.makeButtonView(provider)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .eventHandler(\.outsideTap, eventHandlers.close)
            
            
            FullScreenLoadingView(isLoading: state.isSigning)
        }
    }
    
    private func makeButtonView(_ provider: any OAuth2ServiceProvider) -> some View {
        return self.signInButtonProvider.button(provider) {
            self.eventHandlers.requestSignIn(provider)
        }
        .asAnyView()
    }
}


// MARK: - preview

struct SignInViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = SignInViewState()
        state.supportOAuthServices = [
            GoogleOAuth2ServiceProvider()
        ]
        let eventHandlers = SignInViewEventHandler()
        eventHandlers.requestSignIn = { _ in state.isSigning.toggle() }
        
        let view = SignInView(signInButtonProvider: FakeSignInButtonProvider())
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

private struct FakeSignInButtonProvider: SignInButtonProvider {
    
    func button(_ provider: OAuth2ServiceProvider, _ action: @escaping () -> Void) -> any View {
        return Text("fake button")
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.red)
            )
            .onTapGesture(perform: action)
    }
}
