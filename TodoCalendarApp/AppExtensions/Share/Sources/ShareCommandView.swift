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

    // 확장은 별도 프로세스라 앱의 UINavigationBarAppearance 설정이 안 걸린다.
    // NavigationStack 대신 공용 시트 헤더를 써서 전부 토큰 색·폰트로 그린다.
    var body: some View {
        VStack(spacing: Metric.Spacing.regular) {
            SheetHeaderView(title: "share.ai::title".localized())
                .eventHandler(\.onClose, self.eventHandlers.close)

            self.stageBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, spacing: .large)
        .padding(.bottom, spacing: .large)
        .background(self.appearance.colorSet.bg0.asColor)
    }

    @ViewBuilder
    private var stageBody: some View {
        switch self.state.stage {
        case .loading, .sending:
            self.loadingBody

        case .editing, .failed:
            self.editingBody

        case .blocked(let message), .sent(let message):
            self.messageBody(message)
        }
    }

    private var loadingBody: some View {
        VStack {
            Spacer()
            LoadingCircleView(self.appearance.colorSet.accentAI.asColor)
                .frame(width: 32, height: 32)
            Spacer()
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

            self.failureMessageIfNeed

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
    }

    @ViewBuilder
    private var failureMessageIfNeed: some View {
        if case .failed(let message) = self.state.stage {
            Text(message)
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isSendable: Bool {
        return !self.state.sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func messageBody(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(spacing: .xlarge)
    }
}
