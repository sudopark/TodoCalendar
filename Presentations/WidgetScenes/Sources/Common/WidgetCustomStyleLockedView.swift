//
//  WidgetCustomStyleLockedView.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import WidgetKit
import Domain
import CommonPresentation
import Extensions


public struct WidgetCustomStyleLockedView: View {

    @Environment(\.colorScheme) private var colorScheme
    private var colorSet: any ColorSet {
        return ColorSetKeys.systemTheme.convert(isSystemDarkTheme: colorScheme != .light)
    }

    private let family: WidgetFamily
    public init(family: WidgetFamily) {
        self.family = family
    }

    public var body: some View {
        switch self.family {
        case .systemMedium, .systemLarge, .systemExtraLarge:
            HStack(spacing: 12) {
                self.lockIcon
                self.messages(alignment: .leading)
            }
        default:
            VStack(spacing: 8) {
                self.lockIcon
                self.messages(alignment: .center)
            }
        }
    }

    private var lockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 22))
            .foregroundStyle(self.colorSet.text0.asColor)
    }

    private func messages(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text("widget.style.locked::title".localized())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(self.colorSet.text0.asColor)
            Text("widget.style.locked::action".localized())
                .font(.system(size: 11))
                .foregroundStyle(self.colorSet.text1.asColor)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }
}
