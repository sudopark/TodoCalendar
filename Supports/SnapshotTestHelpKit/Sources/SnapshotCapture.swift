//
//  SnapshotCapture.swift
//  SnapshotTestHelpKit
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import UIKit
import XCTest
import SnapshotTesting


public enum SnapshotTheme: String, CaseIterable, Sendable {
    case light
    case dark

    public var isSystemDarkTheme: Bool { self == .dark }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}


public enum SnapshotLayout {
    case component
    case fullScreen
    case fixed(width: CGFloat, height: CGFloat)

    @MainActor
    var swiftUILayout: SwiftUISnapshotLayout {
        switch self {
        case .component:
            return .sizeThatFits
        case .fullScreen:
            let size = UIScreen.main.bounds.size
            return .fixed(width: size.width, height: size.height)
        case .fixed(let width, let height):
            return .fixed(width: width, height: height)
        }
    }
}


@MainActor
public func captureSnapshotPair<V: View>(
    named name: String,
    layout: SnapshotLayout = .component,
    snapshotDirectory: String? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    @ViewBuilder makeView: (_ theme: SnapshotTheme) -> V
) {
    for theme in SnapshotTheme.allCases {
        let view = makeView(theme)
            .environment(\.colorScheme, theme.colorScheme)
        let startTime = Date()
        var libraryMessage: String?
        withSnapshotTesting(record: .all) {
            libraryMessage = verifySnapshot(
                of: view,
                as: .image(
                    layout: layout.swiftUILayout,
                    traits: snapshotTraits(theme)
                ),
                named: "\(name)-\(theme.rawValue)",
                snapshotDirectory: snapshotDirectory,
                file: file,
                testName: testName
            )
        }
        assertRecorded(
            fileNameKey: "\(name)-\(theme.rawValue)",
            since: startTime,
            snapshotDirectory: snapshotDirectory,
            libraryMessage: libraryMessage,
            file: file, line: line
        )
    }
}


/// 카탈로그(기록 용도) 이미지 저장 전용 경로 — 레포 루트의 snapshot-catalog/<Framework>/<스위트>/ (gitignored).
/// 검증 용도(snapshot-check)는 이 함수를 쓰지 않는다 — 기본 __Snapshots__/에 기록.
/// Presentations 밖 경로에서 호출되면 XCTFail — nil 폴백으로 커밋 대상 경로(__Snapshots__/)에 흘러드는 것을 막는다.
public func catalogSnapshotDirectory(
    file: StaticString = #filePath,
    line: UInt = #line
) -> String? {
    let filePath = "\(file)"
    guard let range = filePath.range(of: "/Presentations/"),
          let frameworkName = filePath[range.upperBound...].split(separator: "/").first
    else {
        XCTFail(
            "catalogSnapshotDirectory: /Presentations/ 밖 경로라 카탈로그 경로를 도출할 수 없다 — \(filePath)",
            file: file, line: line
        )
        return nil
    }
    let repoRoot = String(filePath[..<range.lowerBound])
    let suiteName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
    return "\(repoRoot)/snapshot-catalog/\(frameworkName)/\(suiteName)"
}


// MARK: - private

/// 캡처 png는 항상 iPhone 기본 @3x로 래스터라이즈 — 실행 시뮬레이터 scale 의존 제거
private func snapshotTraits(_ theme: SnapshotTheme) -> UITraitCollection {
    return UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceStyle: theme.interfaceStyle),
        UITraitCollection(displayScale: 3)
    ])
}

/// record 전용이라 비교 실패는 없지만, 캡처 자체 실패(렌더 timeout·디스크 write 실패)는 무음이면 안 된다 —
/// 기록 파일의 존재·수정시각으로 실제 write를 확인하고 실패 시 XCTFail.
private func assertRecorded(
    fileNameKey: String,
    since startTime: Date,
    snapshotDirectory: String?,
    libraryMessage: String?,
    file: StaticString,
    line: UInt
) {
    let testFileURL = URL(fileURLWithPath: "\(file)", isDirectory: false)
    let directoryURL = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? testFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent(testFileURL.deletingPathExtension().lastPathComponent)
    let contents = (try? FileManager.default.contentsOfDirectory(
        at: directoryURL, includingPropertiesForKeys: [.contentModificationDateKey]
    )) ?? []
    let isRecorded = contents.contains { url in
        guard url.lastPathComponent.contains(fileNameKey) else { return false }
        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        return modifiedAt >= startTime.addingTimeInterval(-1)
    }
    guard isRecorded else {
        XCTFail(
            "snapshot record 실패: \(fileNameKey) — \(libraryMessage ?? "라이브러리 메시지 없음")",
            file: file, line: line
        )
        return
    }
}
