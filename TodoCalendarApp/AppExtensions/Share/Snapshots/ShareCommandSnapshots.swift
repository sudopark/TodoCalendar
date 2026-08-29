//
//  ShareCommandSnapshots.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import UIKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import TodoCalendarAppShare


final class ShareCommandSnapshots: XCTestCase {

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
    private func makePreviewData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: .init(width: 1200, height: 800))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        return SharedImagePreview.make(from: image.pngData()!)!
    }

    @MainActor
    func test_editing() {
        captureSnapshotPair(named: "editing", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sharedText = "9월 10일 오후 3시 강남역에서 미팅"
            }
        }
    }

    @MainActor
    func test_editingWithInstruction() {
        captureSnapshotPair(named: "editingWithInstruction", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sharedText = "9월 10일 오후 3시 강남역에서 미팅"
                state.additionalInstruction = "30분 전에 알림도 걸어줘"
            }
        }
    }

    @MainActor
    func test_preparing() {
        captureSnapshotPair(named: "preparing", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = true
            }
        }
    }

    @MainActor
    func test_sending() {
        captureSnapshotPair(named: "sending", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sharedText = "9월 10일 오후 3시 강남역에서 미팅"
                state.isSending = true
            }
        }
    }

    @MainActor
    func test_textTooLong() {
        captureSnapshotPair(named: "textTooLong", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sharedText = "9월 10일 오후 3시 강남역에서 미팅"
                state.failureMessage = "share.ai::textTooLong".localized()
            }
        }
    }

    @MainActor
    func test_blockedByPendingRequest() {
        captureSnapshotPair(named: "blockedByPendingRequest", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.blockedMessage = "share.ai::pending".localized()
            }
        }
    }

    @MainActor
    func test_sent() {
        captureSnapshotPair(named: "sent", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.isPreparing = false
                state.sentMessage = "share.ai::sent".localized()
            }
        }
    }

    @MainActor
    func test_imageRecognizing() {
        captureSnapshotPair(named: "imageRecognizing", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.source = .image(preview: self.makePreviewData())
                state.isPreparing = true
            }
        }
    }

    @MainActor
    func test_imageEditing() {
        captureSnapshotPair(named: "imageEditing", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.source = .image(preview: self.makePreviewData())
                state.isPreparing = false
                state.sharedText = "9월 10일\n치과 예약 오후 3시"
            }
        }
    }

    @MainActor
    func test_imageNoTextFound() {
        captureSnapshotPair(named: "imageNoTextFound", layout: .fullScreen) { theme in
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.source = .image(preview: self.makePreviewData())
                state.isPreparing = false
                state.sharedText = ""
            }
        }
    }
}
