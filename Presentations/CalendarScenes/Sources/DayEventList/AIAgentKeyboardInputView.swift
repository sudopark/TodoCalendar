//
//  AIAgentKeyboardInputView.swift
//  CalendarScenes
//

import SwiftUI
import Combine
import CommonPresentation


// MARK: - ViewState

@Observable final class AIAgentKeyboardInputViewState {
    fileprivate var text: String = ""
    fileprivate var actionTaken: Bool = false
    @ObservationIgnored private var didBind = false

    func bind(_ viewModel: any AIAgentKeyboardInputViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
    }
}


// MARK: - EventHandler

final class AIAgentKeyboardInputEventHandler: Observable {

    var send: (String) -> Void = { _ in }
    var stop: () -> Void = { }
    var dismissByGesture: () -> Void = { }

    func bind(_ viewModel: any AIAgentKeyboardInputViewModel) {
        self.send = viewModel.send(_:)
        self.stop = viewModel.stop
        self.dismissByGesture = viewModel.dismissByGesture
    }
}


// MARK: - ContainerView

struct AIAgentKeyboardInputContainerView: View {

    @State private var state: AIAgentKeyboardInputViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: AIAgentKeyboardInputEventHandler

    var stateBinding: (AIAgentKeyboardInputViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandler: AIAgentKeyboardInputEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }

    var body: some View {
        AIAgentKeyboardInputView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - View

private struct AIAgentKeyboardInputView: View {

    @Environment(AIAgentKeyboardInputViewState.self) private var state
    @Environment(AIAgentKeyboardInputEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance

    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        self.state.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        @Bindable var state = self.state

        VStack(spacing: 16) {
            TextField("", text: $state.text, axis: .vertical)
                .lineLimit(3...8)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .font(appearance.fontSet.size(16, weight: .regular).asFont)
                .padding(12)
                .backgroundAsRoundedRectForEventList(appearance)

            HStack(spacing: 12) {
                // 중지 (빨강) → stopInput + 초기화
                Button {
                    state.actionTaken = true
                    self.eventHandler.stop()
                } label: {
                    Text("aiAgent::keyboard::stop".localized())
                        .font(appearance.fontSet.size(15, weight: .medium).asFont)
                        .foregroundColor(appearance.colorSet.negativeBtnText.asColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appearance.colorSet.negativeBtnBackground.asColor)
                        )
                }

                // 전송 (파랑) → submit
                Button {
                    state.actionTaken = true
                    self.eventHandler.send(self.trimmedText)
                } label: {
                    Text("aiAgent::keyboard::send".localized())
                        .font(appearance.fontSet.size(15, weight: .medium).asFont)
                        .foregroundColor(appearance.colorSet.primaryBtnText.asColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    self.trimmedText.isEmpty
                                    ? appearance.colorSet.primaryBtnBackground.asColor.opacity(0.4)
                                    : appearance.colorSet.primaryBtnBackground.asColor
                                )
                        )
                }
                .disabled(self.trimmedText.isEmpty)
            }
        }
        .padding(20)
        .background(appearance.colorSet.bg0.asColor)
        .onAppear { self.isFocused = true }
        .onDisappear {
            // 전송/중지 버튼이 아니라 시트를 그냥 닫은(드래그) 경우 → 음성 입력으로 복귀
            if !state.actionTaken { self.eventHandler.dismissByGesture() }
        }
    }
}
