//
//  AIAgentKeyboardInputView.swift
//  AIAgentScene
//

import SwiftUI
import Combine
import Domain
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

        BottomSlideView {
            
            VStack(spacing: 16) {
                TextField("", text: $state.text, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                    .font(appearance.fontSet.size(16, weight: .regular).asFont)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(appearance.colorSet.bg1.asColor)
                    )

                HStack(spacing: 12) {
                    
                    ConfirmButton(
                        title: "aiAgent::keyboard::send".localized(),
                        isEnable: !self.trimmedText.isEmpty
                    )
                    .eventHandler(\.onTap) {
                        state.actionTaken = true
                        self.eventHandler.send(self.trimmedText)
                    }
                    
                    // 중지 (빨강) → stopInput + 초기화
                    Button {
                        state.actionTaken = true
                        self.eventHandler.stop()
                    } label: {
                        Text("aiAgent::keyboard::stop".localized())
                            .font(appearance.fontSet.size(15, weight: .medium).asFont)
                            .foregroundColor(appearance.colorSet.secondaryBtnText.asColor)
                            .frame(height: 50)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(appearance.colorSet.secondaryBtnBackground.asColor)
                            )
                    }
                }
            }
        }
        .onAppear { self.isFocused = true }
        .onDisappear {
            // 전송/중지 버튼이 아니라 시트를 그냥 닫은(드래그) 경우 → 음성 입력으로 복귀
            if !state.actionTaken { self.eventHandler.dismissByGesture() }
        }
    }
}


// MARK: - Preview

struct AIAgentKeyboardInputViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let eventHandler = AIAgentKeyboardInputEventHandler()

        let emptyState = AIAgentKeyboardInputViewState()

        let typedState = AIAgentKeyboardInputViewState()
        typedState.text = "내일 오전 9시 회의 추가"

        return Group {
            AIAgentKeyboardInputView()
                .environment(emptyState)
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Keyboard input - empty")

            AIAgentKeyboardInputView()
                .environment(typedState)
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Keyboard input - typed")
        }
    }
}
