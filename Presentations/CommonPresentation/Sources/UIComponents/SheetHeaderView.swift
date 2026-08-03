//
//  SheetHeaderView.swift
//  CommonPresentation
//
//  Created by sudo.park on 7/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


// MARK: - SheetHeaderView

// 시트 공통 상단 헤더: 타이틀(좌) + 닫기(우). 시트들의 룩앤핏을 한 곳에서 통일.
public struct SheetHeaderView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let title: String

    public var onClose: () -> Void = { }

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(self.title)
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()

            self.closeButton
        }
        .padding(.top, spacing: .regular)
    }

    // 리퀴드 글래스는 iOS 26 전용이라 #available로 분기, 하위 버전은 CloseButton.
    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: self.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                    .frame(width: 32, height: 32)
            }
            .glassEffect(.regular.interactive(), in: .circle)
        } else {
            CloseButton()
                .eventHandler(\.onTap, self.onClose)
        }
    }
}
