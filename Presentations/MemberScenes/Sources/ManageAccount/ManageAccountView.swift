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

@Observable final class ManageAccountViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var isMigrating = false
    var accountInfo: AccountInfoModel?
    var isSignOuts = false
    var isDeletingAccount = false
    var migrationNeedEventCount = 0
    
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
        
        viewModel.isDeletingAccount
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isDeletingAccount = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - ManageAccountViewEventHandler

final class ManageAccountViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var handleMigration: () -> Void = { }
    var signOut: () -> Void = { }
    var deleteAccount: () -> Void = { }

    func bind(_ viewModel: any ManageAccountViewModel) {
        
        onAppear = viewModel.prepare
        close = viewModel.close
        handleMigration = viewModel.handleMigration
        signOut = viewModel.signOut
        deleteAccount = viewModel.deleteAccount
    }
}


// MARK: - ManageAccountContainerView

struct ManageAccountContainerView: View {
    
    @State private var state: ManageAccountViewState = .init()
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
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - ManageAccountView

struct ManageAccountView: View {
    
    @Environment(ManageAccountViewState.self) private var state
    @Environment(ManageAccountViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            ScrollView {
                VStack(spacing: 8) {
                    loginInfoView("manage_account::login_method".localized(), self.state.accountInfo?.signInMethod)
                    loginInfoView("manage_account::email".localized(), self.state.accountInfo?.emailAddress)
                    loginInfoView("manage_account::last_signedIn_at".localized(), self.state.accountInfo?.lastSignedIn)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    if self.state.migrationNeedEventCount > 0 {
                        migrationView(state.migrationNeedEventCount)
                    }
                    
                    Spacer()
                        .frame(height: 20)
                    
                    VStack(spacing: 20) {
                        signOutButton()
                        VStack(spacing: 8) {
                            deleteAccountButton()
                            deleteAccountDescription()
                        }
                    }
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
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
        }
            .id(appearance.navigationBarId)
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
                Text("manage_account::migration::title".localized())
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
        return self.state.isSignOuts || self.state.isDeletingAccount || self.state.isMigrating
    }
    
    private func signOutButton() -> some View {
        Button {
            self.eventHandlers.signOut()
        } label: {
            Text("manage_account::signout_button::title".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.secondaryBtnText.asColor)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            appearance.colorSet.secondaryBtnBackground.asColor
                                .opacity(
                                    self.isSignOutButtonDisabled ? 0.6 : 1.0
                                )
                        )
                )
        }
        .disabled(self.isSignOutButtonDisabled)
    }
    
    private var isDeleteAccountDisabled: Bool {
        return self.state.isDeletingAccount || self.state.isSignOuts || self.state.isMigrating
    }
    
    private func deleteAccountButton() -> some View {
        Button {
            self.eventHandlers.deleteAccount()
        } label: {
            Text("manage_account::delete_account_button::title".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.negativeBtnText.asColor)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            appearance.colorSet.negativeBtnBackground.asColor
                                .opacity(
                                    self.isDeleteAccountDisabled ? 0.6 : 1.0
                                )
                        )
                )
        }
        .disabled(self.isDeleteAccountDisabled)
    }
    
    private func deleteAccountDescription() -> some View {
        DescriptionView(
            descriptions: "manage_account::delete_account_button::description".localized()
                .components(separatedBy: "\n")
        )
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
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

