//
//  AIAgentInputStageView.swift
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


// MARK: - AIAgentInputViewState

@Observable final class AIAgentInputViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var inputState: AIAgentInputState = .voice
    var recognizingText: String = ""
    var inputLevel: Float?

    func bind(_ viewModel: any AIAgentInputViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.inputState
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.inputState = $0 })
            .store(in: &self.cancellables)

        viewModel.recognizingText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.recognizingText = $0 })
            .store(in: &self.cancellables)

        viewModel.inputLevel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.inputLevel = $0 })
            .store(in: &self.cancellables)
    }
}


// MARK: - AIAgentInputViewEventHandler

final class AIAgentInputViewEventHandler: Observable {

    var finishVoiceInput: () -> Void = { }
    var switchToKeyboard: () -> Void = { }
    var switchToVoice: () -> Void = { }
    var submit: (String) -> Void = { _ in }
    var openSystemSetting: () -> Void = { }

    func bind(_ viewModel: any AIAgentInputViewModel) {
        self.finishVoiceInput = viewModel.finishVoiceInput
        self.switchToKeyboard = viewModel.switchToKeyboard
        self.switchToVoice = viewModel.switchToVoice
        self.submit = viewModel.submit(_:)
        self.openSystemSetting = viewModel.openSystemSetting
    }
}


// MARK: - AIAgentInputStageContainerView

struct AIAgentInputStageContainerView: View {

    @State private var state: AIAgentInputViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: AIAgentInputViewEventHandler

    var stateBinding: (AIAgentInputViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AIAgentInputViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return AIAgentInputStageView()
            .onAppear { self.stateBinding(self.state) }
            .environment(self.viewAppearance)
            .environment(self.state)
            .environment(self.eventHandlers)
    }
}


// MARK: - AIAgentInputStageView

struct AIAgentInputStageView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(AIAgentInputViewState.self) private var state
    @Environment(AIAgentInputViewEventHandler.self) private var eventHandlers

    @State private var keyboardText: String = ""

    var body: some View {
        switch self.state.inputState {
        case .voice:
            self.voiceView
        case .textInput:
            self.textInputView
        case .permissionDenied:
            self.permissionDeniedView
        }
    }
}


// MARK: - 음성

private extension AIAgentInputStageView {

    var voiceView: some View {
        VStack(spacing: 20) {
            self.micCircle

            Text(self.recognizingTextOrPlaceholder)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "aiAgent::keyboard".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.switchToKeyboard)

                ConfirmButton(title: "common.done".localized())
                    .eventHandler(\.onTap, eventHandlers.finishVoiceInput)
            }
        }
    }

    var recognizingTextOrPlaceholder: String {
        return self.state.recognizingText.isEmpty
            ? "aiAgent::voice::listening".localized()
            : self.state.recognizingText
    }

    var micCircle: some View {
        let level = CGFloat(self.state.inputLevel ?? 0)
        return Circle()
            .fill(appearance.colorSet.primaryBtnBackground.asColor)
            .frame(width: 72, height: 72)
            .overlay {
                Image(systemName: "mic.fill")
                    .foregroundStyle(appearance.colorSet.primaryBtnText.asColor)
                    .font(.system(size: 28))
            }
            .scaleEffect(1.0 + level * 0.4)
            .animation(.easeOut(duration: 0.15), value: level)
    }
}


// MARK: - 키보드

private extension AIAgentInputStageView {

    var textInputView: some View {
        VStack(spacing: 16) {
            TextField("aiAgent::input::placeholder".localized(), text: self.$keyboardText, axis: .vertical)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(appearance.colorSet.bg1.asColor)
                )

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "aiAgent::voice".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.switchToVoice)

                ConfirmButton(
                    title: "aiAgent::send".localized(),
                    isEnable: self.keyboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                )
                .eventHandler(\.onTap) {
                    self.eventHandlers.submit(self.keyboardText)
                }
            }
        }
    }
}


// MARK: - 권한 거부

private extension AIAgentInputStageView {

    var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Text("aiAgent::permission::title".localized())
                .font(appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Text("aiAgent::permission::message".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ConfirmButton(
                    title: "aiAgent::permission::keyboard".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.switchToKeyboard)

                ConfirmButton(title: "aiAgent::permission::setting".localized())
                    .eventHandler(\.onTap, eventHandlers.openSystemSetting)
            }
        }
    }
}


// MARK: - preview

struct AIAgentInputStageViewPreviewProvider: PreviewProvider {

    static func makeView(
        _ inputState: AIAgentInputState,
        recognizing: String = ""
    ) -> some View {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultDark, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = AIAgentInputViewState()
        state.inputState = inputState
        state.recognizingText = recognizing
        state.inputLevel = 0.3
        let eventHandlers = AIAgentInputViewEventHandler()

        return AIAgentInputStageView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
            .padding()
    }

    static var previews: some View {
        Group {
            makeView(.voice, recognizing: "내일 오후 3시 회의").previewDisplayName("voice")
            makeView(.textInput).previewDisplayName("textInput")
            makeView(.permissionDenied).previewDisplayName("permissionDenied")
        }
    }
}
