//
//  AIAgentCommandStageView.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - AIAgentCommandViewState

@Observable final class AIAgentCommandViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var commandState: AIAgentCommandState?

    func bind(_ viewModel: any AIAgentCommandViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.commandState
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.commandState = $0 })
            .store(in: &self.cancellables)
    }
}


// MARK: - AIAgentCommandViewEventHandler

final class AIAgentCommandViewEventHandler: Observable {

    var confirm: () -> Void = { }
    var decline: () -> Void = { }
    var cancel: () -> Void = { }
    var acknowledge: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any AIAgentCommandViewModel) {
        self.confirm = viewModel.confirm
        self.decline = viewModel.decline
        self.cancel = viewModel.cancel
        self.acknowledge = viewModel.acknowledge
        self.close = viewModel.close
    }
}


// MARK: - AIAgentCommandStageContainerView

struct AIAgentCommandStageContainerView: View {

    @State private var state: AIAgentCommandViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: AIAgentCommandViewEventHandler

    var stateBinding: (AIAgentCommandViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AIAgentCommandViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return AIAgentCommandStageView()
            .onAppear { self.stateBinding(self.state) }
            .environment(self.viewAppearance)
            .environment(self.state)
            .environment(self.eventHandlers)
    }
}


// MARK: - AIAgentCommandStageView

struct AIAgentCommandStageView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(AIAgentCommandViewState.self) private var state
    @Environment(AIAgentCommandViewEventHandler.self) private var eventHandlers

    // 헤더 타이틀은 state별 짧은 라벨 — 처리중 표시 역할도 겸함
    private var headerTitle: String {
        switch self.state.commandState {
        case .processing: return "aiAgent::state::processing".localized()
        case .confirm:    return "aiAgent::state::confirm".localized()
        case .done:       return "aiAgent::state::done".localized()
        case .failed:     return "aiAgent::state::failed".localized()
        case .none:       return "aiAgent::title".localized()
        }
    }

    var body: some View {
        BottomSlideView {
            VStack(alignment: .leading, spacing: Metric.Spacing.large) {
                SheetHeaderView(title: self.headerTitle)
                    .eventHandler(\.onClose) {
                        self.eventHandlers.close()
                    }

                Group {
                    switch self.state.commandState {
                    case .processing(let command):
                        self.processingView(command: command)
                    case .confirm(let command, let message):
                        self.confirmView(command: command, message: message)
                    case .done(let command, let message):
                        self.doneView(command: command, message: message)
                    case .failed(let command, let reason):
                        self.failedView(command: command, reason: reason)
                    case .none:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: self.state.commandState)
            }
        }
    }
}


// MARK: - processing

private extension AIAgentCommandStageView {

    func processingView(command: String) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측 말풍선) + AI 처리중(좌측 타이핑 말풍선)
            self.userMessageBubble(command)
            self.assistantTypingBubble

            // 숨김(close)은 헤더 X로 일원화 — 여기선 진행 중지만
            ConfirmButton(
                title: "aiAgent::stop".localized(),
                textColor: appearance.colorSet.secondaryBtnText.asColor,
                backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
            )
            .eventHandler(\.onTap, eventHandlers.cancel)
            .padding(.top, Metric.Spacing.xsmall)
        }
    }

}


// MARK: - chat bubbles

private extension AIAgentCommandStageView {

    // 내가 보낸 말풍선(우측, accentAI). 긴 커맨드는 maxHeight 내부 스크롤로 시트 높이 제한
    func userMessageBubble(_ text: String) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)

            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(appearance.fontSet.size(16).asFont)
                    .foregroundStyle(appearance.colorSet.aiUserBubbleText.asColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metric.Spacing.large)
            .padding(.vertical, Metric.Spacing.regular)
            .background(
                // 내 메시지 — 다크 배경 + 밝은 글씨. 전용 토큰으로 테마별 대비 자동 유지
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .fill(appearance.colorSet.aiUserBubbleBackground.asColor)
            )
        }
    }

    // 상대(AI) 말풍선(좌측, bg1) 공통 컨테이너
    func assistantBubble<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
                .padding(.horizontal, Metric.Spacing.large)
                .padding(.vertical, Metric.Spacing.large)
                .background(
                    RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                        .fill(appearance.colorSet.bg1.asColor)
                )

            Spacer(minLength: 40)
        }
    }

    // 처리중 타이핑 말풍선
    var assistantTypingBubble: some View {
        self.assistantBubble {
            TypingIndicator(color: appearance.colorSet.text1.asColor)
        }
    }

    // AI 응답 메시지 말풍선
    func assistantMessageBubble(_ text: String) -> some View {
        self.assistantBubble {
            Text(text)
                .font(appearance.fontSet.size(16).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
        }
    }
}


// MARK: - confirm

private extension AIAgentCommandStageView {

    func confirmView(command: String, message: String?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측) + AI 확인 메시지(좌측)
            self.userMessageBubble(command)
            if let message, message.isEmpty == false {
                self.assistantMessageBubble(message)
            }

            HStack(spacing: Metric.Spacing.regular) {
                ConfirmButton(
                    title: "common.cancel".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.decline)
                .fixedSize(horizontal: true, vertical: false)

                ConfirmButton(
                    title: "common.confirm".localized(),
                    backgroundColor: appearance.colorSet.accentAI.asColor
                )
                .eventHandler(\.onTap, eventHandlers.confirm)
            }
            .padding(.top, Metric.Spacing.xsmall)
        }
    }
}


// MARK: - done

private extension AIAgentCommandStageView {

    func doneView(command: String, message: String?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측) + AI 완료 메시지(좌측, 체크 아이콘 말풍선 안)
            if command.isEmpty == false {
                self.userMessageBubble(command)
            }

            self.assistantBubble {
                HStack(alignment: .center, spacing: Metric.Spacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(appearance.colorSet.accent.asColor)

                    Text(message?.isEmpty == false ? message! : "aiAgent::done::default".localized())
                        .font(appearance.fontSet.size(16).asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                }
            }

            // 완료를 명시적으로 확인 → reset(idle) 후 닫힘
            ConfirmButton(
                title: "common.confirm".localized(),
                backgroundColor: appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap, eventHandlers.acknowledge)
            .padding(.top, Metric.Spacing.xsmall)
        }
    }
}


// MARK: - failed

private extension AIAgentCommandStageView {

    func failedView(command: String, reason: String?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측, 있을 때만) + AI 실패 메시지(좌측, 경고 아이콘 말풍선 안)
            if command.isEmpty == false {
                self.userMessageBubble(command)
            }

            self.assistantBubble {
                HStack(alignment: .center, spacing: Metric.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(appearance.colorSet.accentWarn.asColor)

                    Text(reason?.isEmpty == false ? reason! : "aiAgent::failed::default".localized())
                        .font(appearance.fontSet.size(16).asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                }
            }

            // 실패를 확인 → reset(idle) 후 닫힘
            ConfirmButton(
                title: "common.confirm".localized(),
                backgroundColor: appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap, eventHandlers.acknowledge)
            .padding(.top, Metric.Spacing.xsmall)
        }
    }
}


// MARK: - TypingIndicator

// 채팅 처리중 말풍선 안의 타이핑 인디케이터 — 점 3개가 opacity wave로 순차 점멸.
private struct TypingIndicator: View {

    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: Metric.Spacing.xsmall) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(self.color)
                    .frame(width: 7, height: 7)
                    .opacity(self.animating ? 1.0 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: self.animating
                    )
            }
        }
        .onAppear { self.animating = true }
    }
}


// MARK: - preview

struct AIAgentCommandStageViewPreviewProvider: PreviewProvider {

    static func makeView(_ commandState: AIAgentCommandState?) -> some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = AIAgentCommandViewState()
        state.commandState = commandState
        let eventHandlers = AIAgentCommandViewEventHandler()

        return AIAgentCommandStageView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
            .padding()
    }

    static var previews: some View {
        Group {
            makeView(.processing(command: "내일 회의 추가")).previewDisplayName("processing")
            makeView(.processing(command: String(repeating: "다음 주 월요일 오전 10시에 강남역 스타벅스에서 디자인 리뷰 미팅 잡아주고, 참석자로 지훈이랑 수민이 추가해줘. ", count: 4))).previewDisplayName("processing-long")
            makeView(.confirm(command: "일정 삭제", message: "정말 삭제할까요?")).previewDisplayName("confirm")
            makeView(.done(command: "내일 회의 추가", message: "일정을 추가했어요")).previewDisplayName("done")
            makeView(.failed(command: "내일 회의 추가", reason: "네트워크 오류가 발생했어요")).previewDisplayName("failed")
        }
    }
}
