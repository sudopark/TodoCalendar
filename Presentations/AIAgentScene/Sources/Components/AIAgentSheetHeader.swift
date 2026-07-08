//
//  AIAgentSheetHeader.swift
//  AIAgentScene
//

import SwiftUI
import Extensions
import CommonPresentation


// MARK: - AIAgentSheetHeader

// AI 입력·명령 시트 공통 상단 헤더: 타이틀(좌) + 리퀴드 글래스 닫기(우).
// 두 시트(KeyboardInput·CommandStage)의 룩앤핏을 한 곳에서 통일.
struct AIAgentSheetHeader: View {

    @Environment(ViewAppearance.self) private var appearance
    private let title: String
    private let onClose: () -> Void

    init(title: String, onClose: @escaping () -> Void) {
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(self.title)
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()

            self.closeButton
        }
        .padding(.top, 12)
    }

    // 리퀴드 글래스는 iOS 26 전용이라 #available로 분기, 하위 버전은 공용 CloseButton.
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
