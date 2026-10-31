//
//  ShareCommandCatalogSnapshots.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 10/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import UIKit
import SwiftUI
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import TodoCalendarAppShare
import EventDomainInterface
import EventDomainTesting
import SettingDomainInterface
import SettingDomainTesting


final class ShareCommandCatalogSnapshots: XCTestCase {

    private var posterPath: String {
        let filePath = "\(#filePath)"
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        guard let range = filePath.range(of: "/TodoCalendarApp/") else { return filePath }
        return "\(filePath[..<range.lowerBound])/snapshot-fixtures/marketing/poster-\(language).png"
    }

    @MainActor
    private func makeAppearance() -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(colorSetKey: .defaultLight, fontSetKey: .systemDefault)
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: false)
    }

    @MainActor
    func test_marketingSharePoster() throws {
        let path = self.posterPath
        guard let poster = FileManager.default.contents(atPath: path),
              let preview = SharedImagePreview.make(from: poster)
        else {
            throw XCTSkip("마케팅 포스터 원본이 없다 — gitignore 자리라 클론마다 넣어야 한다 (\(path))")
        }
        captureSnapshot(
            named: "marketingSharePoster", theme: .light, layout: .fullScreen,
            snapshotDirectory: catalogSnapshotDirectory()
        ) {
            ShareCommandContainerView(
                viewAppearance: self.makeAppearance(),
                eventHandlers: ShareCommandViewEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.source = .image(preview: preview)
                state.isPreparing = false
                state.sharedText = "catalog.share::flea_market_text".catalogLocalized()
            }
        }
    }
}
