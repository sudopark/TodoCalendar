//
//  ShareCommandView.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Extensions
import CommonPresentation


// MARK: - ShareCommandViewState

@Observable final class ShareCommandViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var stage: ShareCommandStage = .loading
    // 공유 원문은 viewModel이 1회 실어주고, 이후엔 유저가 직접 편집한다
    var sharedText: String = ""
    var additionalInstruction: String = ""

    func bind(_ viewModel: ShareCommandViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.stage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.stage = $0 })
            .store(in: &self.cancellables)

        viewModel.sharedText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.sharedText = $0 })
            .store(in: &self.cancellables)
    }
}


// MARK: - ShareCommandViewEventHandler

final class ShareCommandViewEventHandler: Observable {

    var prepare: () -> Void = { }
    var send: (String, String) -> Void = { _, _ in }
    var close: () -> Void = { }

    func bind(_ viewModel: ShareCommandViewModel) {
        self.prepare = viewModel.prepare
        self.send = viewModel.send(sharedText:additionalInstruction:)
        self.close = viewModel.close
    }
}


// MARK: - ShareCommandContainerView

struct ShareCommandContainerView: View {

    @State private var state: ShareCommandViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ShareCommandViewEventHandler

    var stateBinding: (ShareCommandViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ShareCommandViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return ShareCommandView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.prepare()
            }
            .environment(self.viewAppearance)
            .environment(self.state)
            .environment(self.eventHandlers)
    }
}


// MARK: - ShareCommandView

struct ShareCommandView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(ShareCommandViewState.self) private var state
    @Environment(ShareCommandViewEventHandler.self) private var eventHandlers

    var body: some View {
        NavigationStack {
            self.stageBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(self.appearance.colorSet.bg0.asColor)
                .navigationTitle("share.ai::title".localized())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel".localized()) {
                            self.eventHandlers.close()
                        }
                        .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    }
                }
        }
    }

    @ViewBuilder
    private var stageBody: some View {
        switch self.state.stage {
        case .loading, .sending:
            LoadingCircleView(self.appearance.colorSet.accentAI.asColor)

        case .editing:
            self.editingBody

        case .blocked(let message), .failed(let message):
            self.messageBody(message)

        case .sent:
            self.messageBody("share.ai::sent".localized())
        }
    }

    private var editingBody: some View {
        @Bindable var state = self.state
        return VStack(spacing: Metric.Spacing.regular) {
            TextEditor(text: $state.sharedText)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(spacing: .small)
                .background(self.appearance.colorSet.bg1.asColor)
                .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.regular))

            TextField(
                "share.ai::instruction::placeholder".localized(),
                text: $state.additionalInstruction,
                axis: .vertical
            )
            .font(self.appearance.fontSet.subNormal.asFont)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
            .padding(spacing: .small)
            .background(self.appearance.colorSet.bg1.asColor)
            .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.regular))

            Spacer()

            ConfirmButton(
                title: "aiAgent::keyboard::send".localized(),
                isEnable: self.isSendable,
                backgroundColor: self.appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap) {
                self.eventHandlers.send(self.state.sharedText, self.state.additionalInstruction)
            }
        }
        .padding(spacing: .large)
    }

    private var isSendable: Bool {
        return !self.state.sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func messageBody(_ message: String) -> some View {
        Text(message)
            .font(self.appearance.fontSet.normal.asFont)
            .foregroundStyle(self.appearance.colorSet.text1.asColor)
            .multilineTextAlignment(.center)
            .padding(spacing: .xlarge)
    }
}
