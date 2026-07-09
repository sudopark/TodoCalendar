//
//  MemberScenesCatalogSnapshots.swift
//  MemberScenes
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import MemberScenes


final class MemberScenesCatalogSnapshots: XCTestCase {

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
        captureSnapshotPair(
            named: "signIn", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = SignInViewState()
            state.supportOAuthServices = [
                GoogleOAuth2ServiceProvider()
            ]
            let eventHandlers = SignInViewEventHandler()
            eventHandlers.requestSignIn = { _ in state.isSigning.toggle() }

            return SignInView(signInButtonProvider: FakeSignInButtonProvider())
                .environment(state)
                .environment(eventHandlers)
                .environment(self.makeAppearance(theme))
        }
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
