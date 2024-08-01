//
//  
//  ManageAccountView.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - ManageAccountViewState

final class ManageAccountViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var isMigrating = false
    @Published var accountInfo: AccountInfoModel?
    @Published var isSignOuts = false
    @Published var migrationNeedEventCount = 0
    
    func bind(_ viewModel: any ManageAccountViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.isMigrating
            .delay(for: .milliseconds(800), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isMigrating = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.currentAccountInfo
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] info in
                self?.accountInfo = info
            })
            .store(in: &self.cancellables)
        
        viewModel.isNeedMigrationEventCount
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] count in
                self?.migrationNeedEventCount = count
            })
            .store(in: &self.cancellables)
        
        viewModel.isSigningOut
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSignOuts = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - ManageAccountViewEventHandler

final class ManageAccountViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var handleMigration: () -> Void = { }
    var signOut: () -> Void = { }

    func bind(_ viewModel: any ManageAccountViewModel) {
        
        onAppear = viewModel.prepare
        close = viewModel.close
        handleMigration = viewModel.handleMigration
        signOut = viewModel.signOut
    }
}


// MARK: - ManageAccountContainerView

struct ManageAccountContainerView: View {
    
    @StateObject private var state: ManageAccountViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ManageAccountViewEventHandler
    
    var stateBinding: (ManageAccountViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ManageAccountViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return ManageAccountView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - ManageAccountView

struct ManageAccountView: View {
    
    @EnvironmentObject private var state: ManageAccountViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: ManageAccountViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            ScrollView {
                VStack(spacing: 8) {
                    loginInfoView("manage_account::login_method", self.state.accountInfo?.signInMethod)
                    loginInfoView("manage_account::email", self.state.accountInfo?.emailAddress)
                    loginInfoView("manage_account::last_signedIn_at", self.state.accountInfo?.lastSignedIn)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    if self.state.migrationNeedEventCount > 0 {
                        migrationView(state.migrationNeedEventCount)
                    }
                    
                    Spacer()
                        .frame(height: 20)
                    
                    signOutButton()
                }
                .padding()
            }
            .background(appearance.colorSet.bg0.asColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: self.eventHandlers.close)
                }
            }
            .navigationTitle("manage_account::title".localized())
        }
    }
    
    private func loginInfoView(_ key: String, _ value: String?) -> some View {
        HStack {
            Text(key)
                .layoutPriority(1)
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            Spacer(minLength: 20)
            Text(value ?? "-")
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }
    
    private func migrationView(_ count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("manage_account::migration::title")
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                
                Text("manage_account::migration::description".localized(with: count))
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
            
            Spacer(minLength: 50)
            
            if self.state.isMigrating {
                LoadingCircleView(appearance.colorSet.accent.asColor, lineWidth: 1)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "chevron.right")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture(perform: self.eventHandlers.handleMigration)
    }
    
    private var isSignOutButtonDisabled: Bool {
        return self.state.isSignOuts || self.state.isMigrating
    }
    
    private func signOutButton() -> some View {
        Button {
            self.eventHandlers.signOut()
        } label: {
            Text("manage_account::signout_button::title")
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.negativeBtnText.asColor)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            appearance.colorSet.negativeBtnBackground.asColor
                                .opacity(
                                    self.isSignOutButtonDisabled ? 0.6 : 1.0
                                )
                        )
                )
        }
        .disabled(self.isSignOutButtonDisabled)
    }
}


// MARK: - preview

struct ManageAccountViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = ManageAccountViewState()
        state.migrationNeedEventCount = 100
        state.accountInfo = .init(emailAddress: "sudo.park@kakao.com", signInMethod: "google", lastSignedIn: "2023-03-03 12:00:00 ")
        let eventHandlers = ManageAccountViewEventHandler()
        eventHandlers.handleMigration = {
            state.isMigrating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                state.isMigrating = false
                state.migrationNeedEventCount = 0
            }
        }
        
        let view = ManageAccountView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

