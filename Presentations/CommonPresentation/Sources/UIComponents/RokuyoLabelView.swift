//
//  RokuyoLabelView.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CalendarDomainInterface
import Extensions


// MARK: - Rokuyo + 표시 색·이름

extension Rokuyo {

    public var dotColor: UIColor {
        let hex: String
        switch self {
        case .taian: hex = Constant.taianHex
        case .shakku: hex = Constant.shakkuHex
        case .sensho: hex = Constant.senshoHex
        case .tomobiki: hex = Constant.tomobikiHex
        case .senbu: hex = Constant.senbuHex
        case .butsumetsu: hex = Constant.butsumetsuHex
        }
        return UIColor.from(hex: hex) ?? .clear
    }

    public var localizedName: String {
        switch self {
        case .taian: return "rokuyo::taian".localized()
        case .shakku: return "rokuyo::shakku".localized()
        case .sensho: return "rokuyo::sensho".localized()
        case .tomobiki: return "rokuyo::tomobiki".localized()
        case .senbu: return "rokuyo::senbu".localized()
        case .butsumetsu: return "rokuyo::butsumetsu".localized()
        }
    }
}


// MARK: - RokuyoLabelView

public struct RokuyoLabelView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let rokuyo: Rokuyo
    private let font: Font

    public init(_ rokuyo: Rokuyo, font: Font) {
        self.rokuyo = rokuyo
        self.font = font
    }

    public var body: some View {
        HStack(spacing: Metric.Spacing.xsmall) {
            Circle()
                .fill(self.rokuyo.dotColor.asColor)
                .frame(width: 6, height: 6)
            Text(self.rokuyo.localizedName)
                .font(self.font)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
                .lineLimit(1)
        }
    }
}


private enum Constant {
    static let taianHex: String = "#E5484D"
    static let shakkuHex: String = "#8E4EC6"
    static let senshoHex: String = "#30A46C"
    static let tomobikiHex: String = "#F08C2E"
    static let senbuHex: String = "#3E8EDB"
    static let butsumetsuHex: String = "#8B8D98"
}
