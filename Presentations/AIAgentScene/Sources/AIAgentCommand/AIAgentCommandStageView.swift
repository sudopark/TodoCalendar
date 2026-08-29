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
    @ObservationIgnored private let cancellables = CancelBag()

    var commandState: AIAgentCommandState?
    var usage: AIAgentUsage?
    var userPlan: BillingUserPlan?
    var isNotificationPermissionDenied: Bool = false

    func bind(_ viewModel: any AIAgentCommandViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.commandState
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.commandState = $0 })
            .store(in: self.cancellables)

        viewModel.usage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.usage = $0 })
            .store(in: self.cancellables)

        viewModel.currentUserPlan
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.userPlan = $0 })
            .store(in: self.cancellables)

        viewModel.isNotificationPermissionDenied
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.isNotificationPermissionDenied = $0 })
            .store(in: self.cancellables)
    }
}


// MARK: - AIAgentCommandViewEventHandler

final class AIAgentCommandViewEventHandler: Observable {

    var prepare: () -> Void = { }
    var confirm: () -> Void = { }
    var decline: () -> Void = { }
    var cancel: () -> Void = { }
    var acknowledge: () -> Void = { }
    var close: () -> Void = { }
    var showPlans: () -> Void = { }
    var openNotificationSetting: () -> Void = { }

    func bind(_ viewModel: any AIAgentCommandViewModel) {
        self.prepare = viewModel.prepare
        self.confirm = viewModel.confirm
        self.decline = viewModel.decline
        self.cancel = viewModel.cancel
        self.acknowledge = viewModel.acknowledge
        self.close = viewModel.close
        self.showPlans = viewModel.showPlans
        self.openNotificationSetting = viewModel.openNotificationSetting
    }
}


// MARK: - AIAgentCommandStageContainerView

struct AIAgentCommandStageContainerView: View {

    @State private var state: AIAgentCommandViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: AIAgentCommandViewEventHandler
    private let adViewBuilder: (any AdViewBuilder)?

    var stateBinding: (AIAgentCommandViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AIAgentCommandViewEventHandler,
        adViewBuilder: (any AdViewBuilder)?
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
        self.adViewBuilder = adViewBuilder
    }

    var body: some View {
        return AIAgentCommandStageView(adViewBuilder: self.adViewBuilder)
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.prepare()
            }
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

    private let adViewBuilder: (any AdViewBuilder)?

    init(adViewBuilder: (any AdViewBuilder)? = nil) {
        self.adViewBuilder = adViewBuilder
    }

    // confirm의 expireTime — 만료 시각에 헤더·stage가 함께 재렌더되도록 TimelineView 스케줄 근거로 공유.
    // nil(만료 시각 불명) 또는 confirm이 아니면 빈 스케줄 — 최초 1회 렌더만.
    private var confirmExpireSchedule: [Date] {
        if case .confirm(_, _, let expireTime) = self.state.commandState, let expireTime {
            return [expireTime]
        }
        return []
    }

    // 헤더 타이틀은 state별 짧은 라벨 — 처리중 표시 역할도 겸함. 만료 파생은 stage와 동일 기준시각(context.date) 사용.
    private func headerTitle(at now: Date) -> String {
        switch self.state.commandState {
        case .processing: return "aiAgent::state::processing".localized()
        case .confirm(_, _, let expireTime):
            if let expireTime, now >= expireTime {
                return "aiAgent::state::confirmExpired".localized()
            }
            return "aiAgent::state::confirm".localized()
        case .done:   return "aiAgent::state::done".localized()
        case .failed: return "aiAgent::state::failed".localized()
        case .none:   return "aiAgent::title".localized()
        }
    }

    var body: some View {
        BottomSlideView {
            TimelineView(.explicit(self.confirmExpireSchedule)) { context in
                // 디스플레이 링크 없는 정적 렌더(스냅샷 캡처)에선 TimelineView가 미래 스케줄 시각을
                // context.date로 줄 수 있어 벽시계로 클램프 — 온스크린에선 현재를 앞서지 않아 no-op
                let now = min(context.date, Date())
                VStack(alignment: .leading, spacing: Metric.Spacing.large) {
                    SheetHeaderView(title: self.headerTitle(at: now))
                        .eventHandler(\.onClose) {
                            self.eventHandlers.close()
                        }

                    if self.state.isNotificationPermissionDenied {
                        AIAgentNotificationPermissionNoticeView()
                            .eventHandler(\.onTap) {
                                self.eventHandlers.openNotificationSetting()
                            }
                    }

                    if let usage = state.usage, usage.dailyLimit > 0 {
                        AIAgentUsageGaugeView(usage: usage, userPlan: state.userPlan)
                    }

                    Group {
                        switch self.state.commandState {
                        case .processing(let command):
                            self.processingView(command: command)
                        case .confirm(let command, let message, let expireTime):
                            if let expireTime, now >= expireTime {
                                self.confirmExpiredView(command: command, message: message)
                            } else {
                                self.confirmView(command: command, message: message, expireTime: expireTime)
                            }
                        case .done(let command, let message):
                            self.doneView(command: command, message: message)
                        case .failed(let command, let reason, let errorCode):
                            self.failedView(command: command, reason: reason, errorCode: errorCode)
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
        .eventHandler(\.outsideTap, self.eventHandlers.close)
    }
}


// MARK: - processing

private extension AIAgentCommandStageView {

    func processingView(command: String) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측 말풍선) + AI 처리중(좌측 타이핑 말풍선)
            self.userMessageBubble(command)
            self.assistantTypingBubble

            self.mediumRectangleBanner

            // 숨김(close)은 헤더 X로 일원화 — 여기선 진행 중지만
            ConfirmButton(
                title: "aiAgent::stop".localized(),
                textColor: appearance.colorSet.secondaryBtnText.asColor,
                backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
            )
            .eventHandler(\.onTap, eventHandlers.cancel)
            .padding(.top, spacing: .xsmall)
        }
    }

    // 로드 전·실패·유료 플랜이면 높이 0 이라 시트가 안 늘어난다
    @ViewBuilder
    var mediumRectangleBanner: some View {
        if let adViewBuilder = self.adViewBuilder {
            adViewBuilder.makeBannerView(size: .mediumRectangle)
                .asAnyView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}


private enum Constant {
    static let bubbleMaxHeight: CGFloat = 200
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
            .frame(maxHeight: Constant.bubbleMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, spacing: .large)
            .padding(.vertical, spacing: .regular)
            .background(
                // 내 메시지 — 다크 배경 + 밝은 글씨. 전용 토큰으로 테마별 대비 자동 유지
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .fill(appearance.colorSet.aiUserBubbleBackground.asColor)
            )
        }
    }

    // 상대(AI) 말풍선(좌측, bg1) 공통 컨테이너
    func assistantBubble<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        AssistantBubble(content: content)
    }

    // 처리중 타이핑 말풍선
    var assistantTypingBubble: some View {
        self.assistantBubble {
            TypingIndicator(color: appearance.colorSet.text1.asColor)
        }
    }

    func assistantMessageText(_ text: String) -> some View {
        Text(self.parsedMarkdown(text))
            .font(appearance.fontSet.size(16).asFont)
            .foregroundStyle(appearance.colorSet.text0.asColor)
            .textSelection(.enabled)
    }

    func parsedMarkdown(_ text: String) -> AttributedString {
        let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        return parsed ?? AttributedString(text)
    }

    // AI 응답 메시지 말풍선
    func assistantMessageBubble(_ text: String) -> some View {
        self.assistantBubble {
            self.assistantMessageText(text)
        }
    }

    // 아이콘 + 메시지 AI 말풍선 (완료·실패 공용)
    func assistantIconMessageBubble(
        systemName: String,
        tint: Color,
        text: String
    ) -> some View {
        self.assistantBubble {
            HStack(alignment: .top, spacing: Metric.Spacing.small) {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                    .foregroundStyle(tint)

                self.assistantMessageText(text)
            }
        }
    }

    // confirm/confirmExpired 공통 — 유저 지시(우측) + AI 확인 메시지(좌측, 있을 때만)
    @ViewBuilder
    func requestBubbles(command: String, message: String?) -> some View {
        self.userMessageBubble(command)
        if let message, message.isEmpty == false {
            self.assistantMessageBubble(message)
        }
    }
}


// MARK: - confirm

private extension AIAgentCommandStageView {

    func confirmView(command: String, message: String?, expireTime: Date?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            // 채팅 형식 — 유저 지시(우측) + AI 확인 메시지(좌측)
            self.requestBubbles(command: command, message: message)

            // 만료 시각 불명(exp 파싱 실패)이면 카운트다운 생략
            if let expireTime {
                self.countdownLine(expireTime)
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
            .padding(.top, spacing: .xsmall)
        }
    }

    // 남은 시간 카운트다운 — Text(timerInterval:)이 시스템 갱신, 별도 타이머 없음
    private func countdownLine(_ expireTime: Date) -> some View {
        HStack(spacing: Metric.Spacing.xsmall) {
            Image(systemName: "timer")
                .font(.system(size: 12))
                .foregroundStyle(appearance.colorSet.accentAI.asColor)
            Text(timerInterval: Date()...max(Date(), expireTime), countsDown: true)
                .font(appearance.fontSet.size(13, weight: .bold).asFont)
                .monospacedDigit()
                .foregroundStyle(appearance.colorSet.accentAI.asColor)
            Text("aiAgent::confirm::countdown".localized())
                .font(appearance.fontSet.size(13).asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
        }
    }
}


// MARK: - confirm expired

private extension AIAgentCommandStageView {

    // 만료 — 확인 버튼 제거, 닫기 단독. 닫기 = decline(reject + idle) 후 시트 닫힘
    func confirmExpiredView(command: String, message: String?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            self.requestBubbles(command: command, message: message)

            Text("aiAgent::confirm::expired::message".localized())
                .font(appearance.fontSet.size(13, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.accentWarn.asColor)

            ConfirmButton(
                title: "common.close".localized(),
                textColor: appearance.colorSet.secondaryBtnText.asColor,
                backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
            )
            .eventHandler(\.onTap, eventHandlers.decline)
            .padding(.top, spacing: .xsmall)
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

            self.assistantIconMessageBubble(
                systemName: "checkmark.circle.fill",
                tint: appearance.colorSet.accent.asColor,
                text: message.flatMap { $0.isEmpty ? nil : $0 } ?? "aiAgent::done::default".localized()
            )

            // 완료를 명시적으로 확인 → reset(idle) 후 닫힘
            ConfirmButton(
                title: "common.confirm".localized(),
                backgroundColor: appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap, eventHandlers.acknowledge)
            .padding(.top, spacing: .xsmall)
        }
    }
}


// MARK: - failed

private extension AIAgentCommandStageView {

    func failedView(command: String, reason: String?, errorCode: ServerErrorModel.ErrorCode?) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            if command.isEmpty == false {
                self.userMessageBubble(command)
            }

            self.assistantIconMessageBubble(
                systemName: errorCode == .dailyLimitExceeded ? "hourglass.circle.fill" : "exclamationmark.triangle.fill",
                tint: appearance.colorSet.accentWarn.asColor,
                text: self.failedMessage(reason: reason, errorCode: errorCode)
            )

            let showsPlansCTA = errorCode == .dailyLimitExceeded
            if showsPlansCTA {
                ConfirmButton(
                    title: "aiAgent::failed::showPlans".localized(),
                    backgroundColor: appearance.colorSet.accentAI.asColor
                )
                .eventHandler(\.onTap, eventHandlers.showPlans)
                .padding(.top, spacing: .xsmall)
            }

            ConfirmButton(
                title: "common.confirm".localized(),
                textColor: showsPlansCTA ? appearance.colorSet.secondaryBtnText.asColor : nil,
                backgroundColor: showsPlansCTA
                    ? appearance.colorSet.secondaryBtnBackground.asColor
                    : appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap, eventHandlers.acknowledge)
            .padding(.top, spacing: .xsmall)
        }
    }

    func failedMessage(reason: String?, errorCode: ServerErrorModel.ErrorCode?) -> String {
        if let reason, !reason.isEmpty { return reason }
        return errorCode == .dailyLimitExceeded
            ? "aiAgent::failed::dailyLimitExceeded".localized()
            : "aiAgent::failed::default".localized()
    }
}


// MARK: - AssistantBubble

private struct AssistantBubble<Content: View>: View {

    @Environment(ViewAppearance.self) private var appearance
    @State private var contentHeight: CGFloat = 0

    @ViewBuilder let content: () -> Content

    private var isOverflowing: Bool {
        self.contentHeight > Constant.bubbleMaxHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            content()
                .hidden()
                .accessibilityHidden(true)
                .frame(maxHeight: Constant.bubbleMaxHeight)
                .fixedSize(horizontal: false, vertical: true)
                .overlay {
                    ScrollView(.vertical, showsIndicators: false) {
                        content()
                            .background {
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear { self.contentHeight = proxy.size.height }
                                        .onChange(of: proxy.size.height) { _, height in
                                            self.contentHeight = height
                                        }
                                }
                            }
                    }
                    .overlay(alignment: .bottom) {
                        if self.isOverflowing {
                            self.bottomFade
                        }
                    }
                }
                .padding(.horizontal, spacing: .large)
                .padding(.vertical, spacing: .large)
                .background(
                    RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                        .fill(appearance.colorSet.bg1.asColor)
                )

            Spacer(minLength: 40)
        }
    }

    private var bottomFade: some View {
        LinearGradient(
            colors: [
                appearance.colorSet.bg1.asColor.opacity(0),
                appearance.colorSet.bg1.asColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Metric.Spacing.xlarge)
        .allowsHitTesting(false)
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

    static let sampleMultilineMessage: String = """
    이번 주 일정을 **3개** 추가하고 겹치는 건 정리했어요.

    - 월요일 10:00 디자인 리뷰 (강남 스타벅스)
    - 화요일 14:00 팀 스탠드업
    - 수요일 16:00 스프린트 회고

    기존에 있던 화요일 15:00 1:1 미팅은 팀 스탠드업과 시간이 겹쳐서 **16:30**으로 옮겼어요.
    알림은 각각 10분 전으로 맞춰뒀고, 참석자는 아직 아무도 초대하지 않았어요.
    시간대나 장소를 바꾸고 싶으면 다시 말해줘.
    """

    static func makeView(_ commandState: AIAgentCommandState?) -> some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = AIAgentCommandViewState()
        state.commandState = commandState
        state.usage = .init(input: 1234, output: 0, limit: 5000)
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
            makeView(.confirm(command: "일정 삭제", message: "정말 삭제할까요?", expireTime: Date().addingTimeInterval(4 * 60 + 30))).previewDisplayName("confirm")
            makeView(.confirm(command: "일정 삭제", message: "정말 삭제할까요?", expireTime: Date().addingTimeInterval(-10))).previewDisplayName("confirmExpired")
            makeView(.done(command: "내일 회의 추가", message: "일정을 추가했어요")).previewDisplayName("done")
            makeView(.done(command: "이번 주 일정 정리해줘", message: sampleMultilineMessage)).previewDisplayName("done-multiline")
            makeView(.failed(command: "내일 회의 추가", reason: "네트워크 오류가 발생했어요", errorCode: nil)).previewDisplayName("failed")
            makeView(.failed(command: "내일 회의 추가", reason: "오늘 사용량을 모두 썼어요. 내일 다시 시도해 주세요.", errorCode: .dailyLimitExceeded)).previewDisplayName("failed-dailyLimit")
        }
    }
}
