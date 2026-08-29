//
//  ShareCommandView.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Extensions
import CommonPresentation


// MARK: - ShareCommandViewState

@Observable final class ShareCommandViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    // 공유 원문은 viewModel이 1회 실어주고, 이후엔 유저가 직접 편집한다
    var sharedText: String = ""
    var additionalInstruction: String = ""

    var source: ShareCommandSource?
    var isPreparing: Bool = true
    var blockedMessage: String?
    var isSending: Bool = false
    var sentMessage: String?
    var failureMessage: String?

    var isImageShared: Bool {
        guard case .image = self.source else { return false }
        return true
    }

    var imagePreview: Data? {
        guard case .image(let preview) = self.source else { return nil }
        return preview
    }

    var imageTextNotFound: Bool {
        guard self.isImageShared, !self.isPreparing else { return false }
        return self.sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var terminalMessage: String? {
        return self.blockedMessage ?? self.sentMessage
    }

    var isInputLocked: Bool {
        return self.isPreparing || self.isSending
    }

    var isSendable: Bool {
        guard !self.isInputLocked, self.terminalMessage == nil else { return false }
        return !self.sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func bind(_ viewModel: ShareCommandViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.sharedText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.sharedText = $0 })
            .store(in: self.cancellables)

        viewModel.source
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.source = $0 })
            .store(in: self.cancellables)

        viewModel.isPreparing
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.isPreparing = $0 })
            .store(in: self.cancellables)

        viewModel.blockedMessage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.blockedMessage = $0 })
            .store(in: self.cancellables)

        viewModel.isSending
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.isSending = $0 })
            .store(in: self.cancellables)

        viewModel.sentMessage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.sentMessage = $0 })
            .store(in: self.cancellables)

        viewModel.failureMessage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] in self?.failureMessage = $0 })
            .store(in: self.cancellables)
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
            SheetHeaderView(
                title: (self.state.isImageShared ? "share.ai::image::title" : "share.ai::title").localized()
            )
            .eventHandler(\.onClose, self.eventHandlers.close)

            self.contentBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, spacing: .large)
        .padding(.bottom, spacing: .large)
        .background(self.appearance.colorSet.bg0.asColor)
    }

    @ViewBuilder
    private var contentBody: some View {
        if let message = self.state.terminalMessage {
            self.messageBody(message)
        } else {
            self.editingBody
        }
    }

    private var editingBody: some View {
        @Bindable var state = self.state
        return VStack(spacing: Metric.Spacing.regular) {
            VStack(alignment: .leading, spacing: Metric.Spacing.regular) {

                self.imagePreviewIfNeed

                self.imageCaptionIfNeed

                self.inputField(
                    text: $state.sharedText,
                    placeholder: (
                        self.state.isImageShared
                            ? "share.ai::image::text::placeholder"
                            : "share.ai::text::placeholder"
                    ).localized(),
                    font: self.appearance.fontSet.size(16, weight: .regular).asFont,
                    lineLimit: 3...8
                )

                self.inputField(
                    text: $state.additionalInstruction,
                    placeholder: "share.ai::instruction::placeholder".localized(),
                    font: self.appearance.fontSet.normal.asFont,
                    lineLimit: 1...4
                )
            }
            .disabled(self.state.isInputLocked)
            .opacity(self.state.isInputLocked ? 0.5 : 1.0)
            .overlay {
                if self.state.isPreparing {
                    VStack(spacing: Metric.Spacing.small) {
                        LoadingCircleView(self.appearance.colorSet.accentAI.asColor)
                            .frame(width: 32, height: 32)

                        if self.state.isImageShared {
                            Text("share.ai::image::recognizing".localized())
                                .font(self.appearance.fontSet.subNormal.asFont)
                                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                        }
                    }
                }
            }

            self.imageTextNotFoundIfNeed

            self.failureMessageIfNeed

            Spacer()

            ConfirmButton(
                title: "aiAgent::keyboard::send".localized(),
                isEnable: self.state.isSendable,
                isProcessing: self.state.isSending,
                backgroundColor: self.appearance.colorSet.accentAI.asColor
            )
            .eventHandler(\.onTap) {
                self.eventHandlers.send(self.state.sharedText, self.state.additionalInstruction)
            }
        }
    }

    private func inputField(
        text: Binding<String>,
        placeholder: String,
        font: Font,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        return TextField(
            "", text: text,
            prompt: Text(placeholder)
                .font(font)
                .foregroundStyle(self.appearance.colorSet.placeHolder.asColor),
            axis: .vertical
        )
        .lineLimit(lineLimit)
        .font(font)
        .foregroundStyle(self.appearance.colorSet.text0.asColor)
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.chip)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }

    @ViewBuilder
    private var imagePreviewIfNeed: some View {
        if let previewData = self.state.imagePreview,
           let image = UIImage(data: previewData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.regular))
        }
    }

    @ViewBuilder
    private var imageCaptionIfNeed: some View {
        if self.state.isImageShared {
            Text("share.ai::image::text::caption".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var imageTextNotFoundIfNeed: some View {
        if self.state.imageTextNotFound {
            Text("share.ai::image::noTextFound".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var failureMessageIfNeed: some View {
        if let message = self.state.failureMessage {
            Text(message)
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
