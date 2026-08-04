//
//  ShareCommandViewModel.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


// MARK: - ShareCommandStage

enum ShareCommandStage: Equatable {
    case loading
    case editing
    /// 미로그인·미확인 요청이라 전송 자체를 막은 상태
    case blocked(message: String)
    case sending
    case sent
    case failed(message: String)
}


// MARK: - ShareCommandViewModel

final class ShareCommandViewModel: @unchecked Sendable {

    private let submitService: ShareCommandSubmitService
    private let loadSharedText: @Sendable () async -> String
    private let onClose: @Sendable () -> Void

    init(
        submitService: ShareCommandSubmitService,
        loadSharedText: @escaping @Sendable () async -> String,
        onClose: @escaping @Sendable () -> Void
    ) {
        self.submitService = submitService
        self.loadSharedText = loadSharedText
        self.onClose = onClose
    }

    private struct Subject {
        let stage = CurrentValueSubject<ShareCommandStage, Never>(.loading)
        let sharedText = CurrentValueSubject<String?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - interactions

extension ShareCommandViewModel {

    func prepare() {
        Task { [weak self] in
            guard let self else { return }
            self.subject.sharedText.send(await self.loadSharedText())
            self.subject.stage.send(await self.resolveInitialStage())
        }
    }

    private func resolveInitialStage() async -> ShareCommandStage {
        switch await self.submitService.checkPrecondition() {
        case .ready:
            return .editing
        case .needSignIn:
            return .blocked(message: "share.ai::needSignIn".localized())
        case .previousRequestPending:
            return .blocked(message: "share.ai::pending".localized())
        }
    }

    func send(sharedText: String, additionalInstruction: String) {
        guard self.subject.stage.value == .editing else { return }
        let command = AIShareCommandText(
            sharedText: sharedText,
            additionalInstruction: additionalInstruction
        )
        guard !command.isEmpty else { return }

        self.subject.stage.send(.sending)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.submitService.submit(command)
                self.subject.stage.send(.sent)
            } catch {
                self.subject.stage.send(.failed(message: "share.ai::failed".localized()))
            }
        }
    }

    func close() {
        self.onClose()
    }
}


// MARK: - outputs

extension ShareCommandViewModel {

    var stage: AnyPublisher<ShareCommandStage, Never> {
        return self.subject.stage.eraseToAnyPublisher()
    }

    var sharedText: AnyPublisher<String, Never> {
        return self.subject.sharedText.compactMap { $0 }.eraseToAnyPublisher()
    }
}
