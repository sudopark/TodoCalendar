//
//  MemberScenesSnapshots.swift
//  MemberScenes
//
//  Created by sudo.park on 7/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import MemberScenes


final class MemberScenesSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_signIn() {
        captureSnapshotPair(named: "signIn", layout: .fullScreen) { theme in
            let state = SignInViewState()
            state.supportOAuthServices = [
                GoogleOAuth2ServiceProvider()
            ]
            let eventHandlers = SignInViewEventHandler()
            return SignInView(signInButtonProvider: FakeSignInButtonProvider())
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_manageAccount() {
        captureSnapshotPair(named: "manageAccount", layout: .fullScreen) { theme in
            let state = ManageAccountViewState()
            state.migrationNeedEventCount = 100
            state.accountInfo = .init(
                emailAddress: "sudo.park@kakao.com",
                signInMethod: "google",
                lastSignedIn: "2023-03-03 12:00:00"
            )
            let eventHandlers = ManageAccountViewEventHandler()
            return ManageAccountView()
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
    }
}


// MARK: - Test Doubles

private struct FakeSignInButtonProvider: SignInButtonProvider {

    func button(_ provider: OAuth2ServiceProvider, _ action: @escaping () -> Void) -> any View {
        Text("fake button")
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.red)
            )
            .onTapGesture(perform: action)
    }
}
