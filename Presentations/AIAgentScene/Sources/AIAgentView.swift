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

struct AIAgentViewPreviewProvider: PreviewProvider {

    private static func makeAppearance() -> ViewAppearance {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        return ViewAppearance(setting: setting, isSystemDarkTheme: false)
    }

    private static func sheet<Content: View>(
        _ viewAppearance: ViewAppearance,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        BottomSlideView(
            backgroundColor: viewAppearance.colorSet.bg0.withAlphaComponent(0.95).asColor
        ) {
            VStack(spacing: 16) {
                content()
            }
            .padding(.vertical, 8)
        }
        .environment(viewAppearance)
    }

    private static func inputStage(
        _ viewAppearance: ViewAppearance,
        _ inputState: AIAgentInputState,
        recognizing: String = ""
    ) -> some View {
        let state = AIAgentInputViewState()
        state.inputState = inputState
        state.recognizingText = recognizing
        state.inputLevel = 0.4
        return AIAgentInputStageView()
            .environment(viewAppearance)
            .environment(state)
            .environment(AIAgentInputViewEventHandler())
    }

    private static func commandStage(
        _ viewAppearance: ViewAppearance,
        _ commandState: AIAgentCommandState
    ) -> some View {
        let state = AIAgentCommandViewState()
        state.commandState = commandState
        return AIAgentCommandStageView()
            .environment(viewAppearance)
            .environment(state)
            .environment(AIAgentCommandViewEventHandler())
    }

    static var previews: some View {
        let appearance = self.makeAppearance()
        return Group {
            self.sheet(appearance) {
                TypingDotsView(color: appearance.colorSet.primaryBtnBackground.asColor)
                    .frame(height: 12)
                    .frame(minHeight: 80)
            }
            .previewDisplayName("waiting")

            self.sheet(appearance) {
                self.inputStage(appearance, .voice, recognizing: "내일 오후 3시 회의")
            }
            .previewDisplayName("input-voice")

            self.sheet(appearance) {
                self.commandStage(appearance, .processing(command: "내일 오후 3시 회의"))
            }
            .previewDisplayName("command-processing")

            self.sheet(appearance) {
                self.commandStage(appearance, .done(message: "일정을 추가했어요"))
            }
            .previewDisplayName("command-done")

            self.sheet(appearance) {
                self.commandStage(appearance, .failed(reason: "네트워크 오류가 발생했어요"))
            }
            .previewDisplayName("command-failed")
        }
    }
}
