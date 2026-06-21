//
//  AIAgentInlineInputView.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Scenes
import Extensions
import CommonPresentation


// MARK: - AIAgentInlineInputView

struct AIAgentInlineInputView: View {

    @Environment(DayEventListViewState.self) private var state: DayEventListViewState
    @Environment(DayEventListViewEventHandler.self) private var eventHandler: DayEventListViewEventHandler
    @Environment(ViewAppearance.self) private var appearance: ViewAppearance

    @State private var keyboardText: String = ""

    var body: some View {
        switch self.state.aiAgentEntryMode {
        case .voice:
            voiceModeView()
        case .keyboard:
            keyboardModeView()
        default:
            EmptyView()
        }
    }

    private func voiceModeView() -> some View {
        HStack(spacing: 8) {
            VoiceWaveformView(
                level: self.state.voiceLevel,
                tintColor: self.appearance.colorSet.primaryBtnText.asColor
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4).padding(.horizontal, 8)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.appearance.colorSet.primaryBtnBackground.asColor)
            )
            .overlay(alignment: .bottom) {
                if !self.state.recognizingText.isEmpty {
                    Text(self.state.recognizingText)
                        .font(self.appearance.fontSet.size(11, weight: .regular).asFont)
                        .foregroundColor(self.appearance.colorSet.primaryBtnText.asColor)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 8)
                }
            }

            // 정지 버튼 (빨강)
            Button {
                self.eventHandler.stopAIAgentInput()
            } label: {
                Circle()
                    .fill(self.appearance.colorSet.negativeBtnBackground.asColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "stop.fill")
                            .foregroundColor(self.appearance.colorSet.negativeBtnText.asColor)
                    )
            }

            // 키보드 전환 버튼 (초록 = secondary)
            Button {
                self.eventHandler.enterKeyboardInput()
            } label: {
                Circle()
                    .fill(self.appearance.colorSet.secondaryBtnBackground.asColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "keyboard")
                            .foregroundColor(self.appearance.colorSet.secondaryBtnText.asColor)
                    )
            }
        }
    }

    private func keyboardModeView() -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $keyboardText,
                    axis: .vertical
                )
                .lineLimit(1...3)
                .autocorrectionDisabled()
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.size(15, weight: .regular).asFont)
                .textInputAutocapitalization(.never)
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .frame(minHeight: 50)
            .backgroundAsRoundedRectForEventList(self.appearance)

            // 음성 복귀 버튼 (빨강)
            Button {
                self.eventHandler.enterVoiceInput()
            } label: {
                Circle()
                    .fill(self.appearance.colorSet.negativeBtnBackground.asColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(self.appearance.colorSet.negativeBtnText.asColor)
                    )
            }

            // 전송 버튼 (초록 = primary)
            Button {
                let text = self.keyboardText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                self.eventHandler.submitAIAgent(text)
                self.keyboardText = ""
            } label: {
                Circle()
                    .fill(
                        self.keyboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? self.appearance.colorSet.primaryBtnBackground.asColor.opacity(0.4)
                        : self.appearance.colorSet.primaryBtnBackground.asColor
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .foregroundColor(self.appearance.colorSet.primaryBtnText.asColor)
                    )
            }
            .disabled(self.keyboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}


// MARK: - Preview

private extension DayEventListViewState {
    static func voiceLow() -> DayEventListViewState {
        let s = DayEventListViewState()
        s.aiAgentEntryMode = .voice
        s.voiceLevel = 0.2
        s.recognizingText = ""
        return s
    }

    static func voiceHigh() -> DayEventListViewState {
        let s = DayEventListViewState()
        s.aiAgentEntryMode = .voice
        s.voiceLevel = 0.9
        s.recognizingText = "안녕하세요 오늘 일정"
        return s
    }

    static func keyboard() -> DayEventListViewState {
        let s = DayEventListViewState()
        s.aiAgentEntryMode = .keyboard
        return s
    }
}

struct AIAgentInlineInputView_Previews: PreviewProvider {

    private static func previewAppearance() -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: false)
    }

    static var previews: some View {
        let viewAppearance = previewAppearance()
        let eventHandler = DayEventListViewEventHandler()

        Group {
            AIAgentInlineInputView()
                .environment(DayEventListViewState.voiceLow())
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Voice — low level")
                .padding()
                .background(viewAppearance.colorSet.bg0.asColor)

            AIAgentInlineInputView()
                .environment(DayEventListViewState.voiceHigh())
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Voice — high level + text")
                .padding()
                .background(viewAppearance.colorSet.bg0.asColor)

            AIAgentInlineInputView()
                .environment(DayEventListViewState.keyboard())
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Keyboard mode")
                .padding()
                .background(viewAppearance.colorSet.bg0.asColor)
        }
    }
}
