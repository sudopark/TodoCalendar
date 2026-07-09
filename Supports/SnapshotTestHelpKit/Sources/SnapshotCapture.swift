//
//  SnapshotCapture.swift
//  SnapshotTestHelpKit
//
//  Created by sudo.park on 7/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import UIKit
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
    @ViewBuilder makeView: (_ theme: SnapshotTheme) -> V
) {
    for theme in SnapshotTheme.allCases {
        let view = makeView(theme)
            .environment(\.colorScheme, theme.colorScheme)
        withSnapshotTesting(record: .all) {
            _ = verifySnapshot(
                of: view,
                as: .image(
                    layout: layout.swiftUILayout,
                    traits: .init(userInterfaceStyle: theme.interfaceStyle)
                ),
                named: "\(name)-\(theme.rawValue)",
                snapshotDirectory: snapshotDirectory,
                file: file,
                testName: testName
            )
        }
    }
}


/// 카탈로그(기록 용도) 이미지 저장 전용 경로 — 레포 루트의 snapshot-catalog/<Framework>/ (gitignored).
/// 검증 용도(snapshot-check)는 이 함수를 쓰지 않는다 — 기본 __Snapshots__/에 기록.
public func catalogSnapshotDirectory(file: StaticString = #filePath) -> String? {
    let filePath = "\(file)"
    guard let range = filePath.range(of: "/Presentations/") else { return nil }
    let repoRoot = String(filePath[..<range.lowerBound])
    let afterPresentations = filePath[range.upperBound...]
    guard let frameworkName = afterPresentations.split(separator: "/").first else { return nil }
    return "\(repoRoot)/snapshot-catalog/\(frameworkName)"
}
