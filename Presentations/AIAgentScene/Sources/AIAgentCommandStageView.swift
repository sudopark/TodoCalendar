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
    var close: () -> Void = { }

    func bind(_ viewModel: any AIAgentCommandViewModel) {
        self.confirm = viewModel.confirm
        self.decline = viewModel.decline
        self.cancel = viewModel.cancel
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

    var body: some View {
        Group {
            switch self.state.commandState {
            case .processing(let command):
                self.processingView(command: command)
            case .confirm(let command, let message):
                self.confirmView(command: command, message: message)
            case .done(let message):
                self.doneView(message: message)
            case .failed(let reason):
                self.failedView(reason: reason)
            case .none:
                EmptyView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: self.state.commandState)
    }
}


// MARK: - processing

private extension AIAgentCommandStageView {

    func processingView(command: String) -> some View {
        VStack(spacing: 16) {
            Text(command)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            TypingDotsView(color: appearance.colorSet.primaryBtnBackground.asColor)
                .frame(height: 12)

            Text("aiAgent::processing".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
        }
    }
}


// MARK: - confirm

private extension AIAgentCommandStageView {

    func confirmView(command: String, message: String?) -> some View {
        VStack(spacing: 16) {
            Text(message?.isEmpty == false ? message! : command)
                .font(appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "common.cancel".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.decline)

                ConfirmButton(title: "common.confirm".localized())
                    .eventHandler(\.onTap, eventHandlers.confirm)
            }
        }
    }
}


// MARK: - done

private extension AIAgentCommandStageView {

    func doneView(message: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(appearance.colorSet.accent.asColor)

            Text(message?.isEmpty == false ? message! : "aiAgent::done::default".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            ConfirmButton(title: "common.close".localized())
                .eventHandler(\.onTap, eventHandlers.close)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appearance.colorSet.accent.withAlphaComponent(0.12).asColor)
        )
    }
}


// MARK: - failed

private extension AIAgentCommandStageView {

    func failedView(reason: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(appearance.colorSet.accentWarn.asColor)

            Text(reason?.isEmpty == false ? reason! : "aiAgent::failed::default".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "common.close".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.close)

                ConfirmButton(title: "aiAgent::retry".localized())
                    .eventHandler(\.onTap, eventHandlers.cancel)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appearance.colorSet.accentWarn.withAlphaComponent(0.12).asColor)
        )
    }
}


// MARK: - TypingDotsView

struct TypingDotsView: View {

    let color: Color

    @State private var animating = false

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(self.color)
                    .frame(width: 9, height: 9)
                    .opacity(self.animating ? 1.0 : 0.3)
                    .scaleEffect(self.animating ? 1.0 : 0.7)
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
            makeView(.confirm(command: "일정 삭제", message: "정말 삭제할까요?")).previewDisplayName("confirm")
            makeView(.done(message: "일정을 추가했어요")).previewDisplayName("done")
            makeView(.failed(reason: "네트워크 오류가 발생했어요")).previewDisplayName("failed")
            TypingDotsView(color: .blue).padding().previewDisplayName("TypingDots")
        }
    }
}
