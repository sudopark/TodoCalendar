//
//  AIAgentImageCommandView.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - ViewState

@Observable final class AIAgentImageCommandViewState {

    fileprivate var stage: AIAgentImageCommandStage = .recognizing
    fileprivate var text: String = ""
    fileprivate var instruction: String = ""
    fileprivate var actionTaken: Bool = false
    var usage: AIAgentUsage?
    var userPlan: BillingUserPlan?
    var isNotificationPermissionDenied: Bool = false
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var didSeedText = false
    @ObservationIgnored private let cancellables = CancelBag()

    func bind(_ viewModel: any AIAgentImageCommandViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.stage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] stage in
                self?.stage = stage
                self?.seedTextIfNeeded(stage)
            })
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

    private func seedTextIfNeeded(_ stage: AIAgentImageCommandStage) {
        guard case .editing(let recognized) = stage, self.didSeedText == false
        else { return }
        self.didSeedText = true
        self.text = recognized
    }
}


// MARK: - EventHandler

final class AIAgentImageCommandEventHandler: Observable {

    var prepare: () -> Void = { }
    var send: (String, String) -> Void = { _, _ in }
    var close: () -> Void = { }
    var dismissByGesture: () -> Void = { }
    var openNotificationSetting: () -> Void = { }

    func bind(_ viewModel: any AIAgentImageCommandViewModel) {
        self.prepare = viewModel.prepare
        self.send = viewModel.send(text:additionalInstruction:)
        self.close = viewModel.close
        self.dismissByGesture = viewModel.dismissByGesture
        self.openNotificationSetting = viewModel.openNotificationSetting
    }
}


// MARK: - ContainerView

struct AIAgentImageCommandContainerView: View {

    @State private var state: AIAgentImageCommandViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: AIAgentImageCommandEventHandler

    var stateBinding: (AIAgentImageCommandViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandler: AIAgentImageCommandEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }

    var body: some View {
        AIAgentImageCommandView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.prepare()
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - View

private struct AIAgentImageCommandView: View {

    @Environment(AIAgentImageCommandViewState.self) private var state
    @Environment(AIAgentImageCommandEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance

    private var trimmedText: String {
        self.state.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        BottomSlideView {

            VStack(alignment: .leading, spacing: Metric.Spacing.large) {
                SheetHeaderView(title: "aiAgent::image::title".localized())
                    .eventHandler(\.onClose) {
                        self.eventHandler.close()
                    }

                if self.state.isNotificationPermissionDenied {
                    AIAgentNotificationPermissionNoticeView()
                        .eventHandler(\.onTap) {
                            self.eventHandler.openNotificationSetting()
                        }
                }

                if let usage = self.state.usage, usage.dailyLimit > 0 {
                    AIAgentUsageGaugeView(usage: usage, userPlan: self.state.userPlan)
                }

                switch self.state.stage {
                case .recognizing: self.recognizingContent()
                case .noTextFound: self.messageContent("aiAgent::image::noText".localized())
                case .editing: self.editingContent()
                }

                self.bottomButtons()
            }
        }
        .eventHandler(\.outsideTap, self.eventHandler.close)
        .onDisappear {
            if !self.state.actionTaken { self.eventHandler.dismissByGesture() }
        }
    }

    private func recognizingContent() -> some View {
        VStack(spacing: Metric.Spacing.regular) {
            LoadingCircleView(self.appearance.colorSet.accentAI.asColor)
                .frame(width: 40, height: 40)
            Text("aiAgent::image::recognizing".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, spacing: .xlarge)
    }

    private func messageContent(_ message: String) -> some View {
        Text(message)
            .font(self.appearance.fontSet.normal.asFont)
            .foregroundStyle(self.appearance.colorSet.text1.asColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing: .xlarge)
    }

    private func editingContent() -> some View {
        @Bindable var state = self.state

        return VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

            self.fieldLabel("aiAgent::image::readText".localized())
            self.inputField($state.text, placeholder: "", lineLimit: 4...10)

            self.fieldLabel("aiAgent::image::instruction".localized())
            self.inputField(
                $state.instruction,
                placeholder: "aiAgent::image::instruction::placeholder".localized(),
                lineLimit: 1...3
            )
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(self.appearance.fontSet.size(13, weight: .regular).asFont)
            .foregroundStyle(self.appearance.colorSet.text2.asColor)
    }

    private func inputField(
        _ text: Binding<String>,
        placeholder: String,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        TextField(
            "", text: text,
            prompt: Text(placeholder)
                .font(self.appearance.fontSet.size(16, weight: .regular).asFont)
                .foregroundStyle(self.appearance.colorSet.placeHolder.asColor),
            axis: .vertical
        )
        .lineLimit(lineLimit)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .foregroundStyle(self.appearance.colorSet.text0.asColor)
        .font(self.appearance.fontSet.size(16, weight: .regular).asFont)
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.chip)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }

    private func bottomButtons() -> some View {
        @Bindable var state = self.state

        return HStack(spacing: Metric.Spacing.regular) {
            if case .editing = self.state.stage {
                ConfirmButton(
                    title: "aiAgent::keyboard::send".localized(),
                    isEnable: !self.trimmedText.isEmpty,
                    backgroundColor: self.appearance.colorSet.accentAI.asColor
                )
                .eventHandler(\.onTap) {
                    state.actionTaken = true
                    self.eventHandler.send(self.trimmedText, self.state.instruction)
                }
            } else {
                ConfirmButton(
                    title: "common.cancel".localized(),
                    textColor: self.appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: self.appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap) {
                    self.eventHandler.close()
                }
            }
        }
    }
}


// MARK: - Preview

struct AIAgentImageCommandViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let eventHandler = AIAgentImageCommandEventHandler()

        let recognizingState = AIAgentImageCommandViewState()

        let editingState = AIAgentImageCommandViewState()
        editingState.stage = .editing(text: "상품명 아메리카노\n8월 12일 14:00\n강남점 3층")
        editingState.text = "상품명 아메리카노\n8월 12일 14:00\n강남점 3층"
        editingState.usage = .init(input: 1234, output: 0, limit: 5000)

        let noTextState = AIAgentImageCommandViewState()
        noTextState.stage = .noTextFound

        return Group {
            AIAgentImageCommandView()
                .environment(recognizingState)
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Image command - recognizing")

            AIAgentImageCommandView()
                .environment(editingState)
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Image command - editing")

            AIAgentImageCommandView()
                .environment(noTextState)
                .environment(eventHandler)
                .environment(viewAppearance)
                .previewDisplayName("Image command - no text")
        }
    }
}
