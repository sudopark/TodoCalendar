//
//  AIAgentView.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - AIAgentStageViewState (parent)

@Observable final class AIAgentViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var stage: AIAgentStageKind?

    func bind(_ viewModel: any AIAgentViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.stage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.stage = $0 })
            .store(in: &self.cancellables)
    }
}


// MARK: - AIAgentViewEventHandler (parent)

final class AIAgentViewEventHandler: Observable {

    var onAppear: () -> Void = { }

    func bind(_ viewModel: any AIAgentViewModel) {
        self.onAppear = viewModel.prepare
    }
}


// MARK: - AIAgentStageViewBuilder

struct AIAgentStageViewBuilder {

    let viewAppearance: ViewAppearance
    let inputViewModel: any AIAgentInputViewModel
    let commandViewModel: any AIAgentCommandViewModel
    let inputEventHandlers: AIAgentInputViewEventHandler
    let commandEventHandlers: AIAgentCommandViewEventHandler

    @MainActor
    func makeInputStageView() -> some View {
        return AIAgentInputStageContainerView(
            viewAppearance: self.viewAppearance,
            eventHandlers: self.inputEventHandlers
        )
        .eventHandler(\.stateBinding, { [inputViewModel] in $0.bind(inputViewModel) })
    }

    @MainActor
    func makeCommandStageView() -> some View {
        return AIAgentCommandStageContainerView(
            viewAppearance: self.viewAppearance,
            eventHandlers: self.commandEventHandlers
        )
        .eventHandler(\.stateBinding, { [commandViewModel] in $0.bind(commandViewModel) })
    }
}


// MARK: - AIAgentContainerView

struct AIAgentContainerView: View {

    @State private var state: AIAgentViewState = .init()

    private let viewAppearance: ViewAppearance
    private let eventHandlers: AIAgentViewEventHandler
    private let stageViewBuilder: AIAgentStageViewBuilder

    var stateBinding: (AIAgentViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AIAgentViewEventHandler,
        stageViewBuilder: AIAgentStageViewBuilder
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
        self.stageViewBuilder = stageViewBuilder
    }

    var body: some View {
        return AIAgentView(stageViewBuilder: self.stageViewBuilder)
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(self.viewAppearance)
            .environment(self.state)
    }
}


// MARK: - AIAgentView

struct AIAgentView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(AIAgentViewState.self) private var state

    let stageViewBuilder: AIAgentStageViewBuilder

    var body: some View {
        BottomSlideView(
            backgroundColor: appearance.colorSet.bg0.withAlphaComponent(0.95).asColor
        ) {
            VStack(spacing: 16) {
                self.usageHeaderArea
                self.stageView
            }
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.35), value: self.state.stage)
        }
    }

    // 상단 usage 헤더 자리. 실제 표시(progress/텍스트)는 후속 작업에서 주입.
    @ViewBuilder
    private var usageHeaderArea: some View {
        EmptyView()
    }

    private var stageView: some View {
        Group {
            switch self.state.stage {
            case .none:
                TypingDotsView(color: appearance.colorSet.primaryBtnBackground.asColor)
                    .frame(height: 12)
                    .frame(minHeight: 80)
            case .input:
                self.stageViewBuilder.makeInputStageView()
            case .command:
                self.stageViewBuilder.makeCommandStageView()
            }
        }
        .transition(.opacity)
    }
}


// MARK: - preview

private final class PreviewInputViewModel: AIAgentInputViewModel, @unchecked Sendable {

    private let state: AIAgentInputState
    private let recognizing: String

    init(_ state: AIAgentInputState, recognizing: String = "") {
        self.state = state
        self.recognizing = recognizing
    }

    func startInput() { }
    func stopInput() { }
    func finishVoiceInput() { }
    func switchToKeyboard() { }
    func switchToVoice() { }
    func submit(_ text: String) { }
    func openSystemSetting() { }

    var inputState: AnyPublisher<AIAgentInputState, Never> { Just(self.state).eraseToAnyPublisher() }
    var recognizingText: AnyPublisher<String, Never> { Just(self.recognizing).eraseToAnyPublisher() }
    var inputLevel: AnyPublisher<Float?, Never> { Just(0.4).eraseToAnyPublisher() }
}

private final class PreviewCommandViewModel: AIAgentCommandViewModel, @unchecked Sendable {

    private let state: AIAgentCommandState?

    init(_ state: AIAgentCommandState?) {
        self.state = state
    }

    func sendCommand(_ text: String) { }
    func confirm() { }
    func decline() { }
    func restart() { }
    func close() { }

    var commandState: AnyPublisher<AIAgentCommandState?, Never> { Just(self.state).eraseToAnyPublisher() }
}

struct AIAgentViewPreviewProvider: PreviewProvider {

    static func makeView(
        stage: AIAgentStageKind?,
        input: AIAgentInputState = .voice,
        recognizing: String = "",
        command: AIAgentCommandState? = nil
    ) -> some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultDark, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let builder = AIAgentStageViewBuilder(
            viewAppearance: viewAppearance,
            inputViewModel: PreviewInputViewModel(input, recognizing: recognizing),
            commandViewModel: PreviewCommandViewModel(command),
            inputEventHandlers: AIAgentInputViewEventHandler(),
            commandEventHandlers: AIAgentCommandViewEventHandler()
        )
        let state = AIAgentViewState()
        state.stage = stage

        return AIAgentView(stageViewBuilder: builder)
            .environment(viewAppearance)
            .environment(state)
    }

    static var previews: some View {
        Group {
            makeView(stage: nil)
                .previewDisplayName("waiting")
            makeView(stage: .input, input: .voice, recognizing: "내일 오후 3시 회의")
                .previewDisplayName("input-voice")
            makeView(stage: .command, command: .processing(command: "내일 오후 3시 회의"))
                .previewDisplayName("command-processing")
            makeView(stage: .command, command: .done(message: "일정을 추가했어요"))
                .previewDisplayName("command-done")
            makeView(stage: .command, command: .failed(reason: "네트워크 오류가 발생했어요"))
                .previewDisplayName("command-failed")
        }
    }
}
