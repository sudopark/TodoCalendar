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
    /// 미로그인·앞선 요청이라 전송 자체를 막은 상태 — 되돌아갈 곳이 없다
    case blocked(message: String)
    case sending
    case sent(message: String)
    /// 전송 실패 — 원문을 그대로 두고 재시도할 수 있다
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
    private var didPrepare = false
}


// MARK: - interactions

extension ShareCommandViewModel {

    // onAppear가 다시 불려도 유저가 편집 중인 원문을 덮지 않는다
    func prepare() {
        guard self.didPrepare == false else { return }
        self.didPrepare = true

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
        guard self.canSend else { return }
        let command = AIShareCommandText(
            sharedText: sharedText,
            additionalInstruction: additionalInstruction
        )
        guard !command.isEmpty else { return }

        self.subject.stage.send(.sending)
        Task { [weak self] in
            guard let self else { return }
            self.subject.stage.send(await self.submitResult(command))
        }
    }

    private func submitResult(_ command: AIShareCommandText) async -> ShareCommandStage {
        do {
            try await self.submitService.submit(command)
            return .sent(message: "share.ai::sent".localized())
        } catch ShareSubmitFailure.createdButNotTrackable {
            return .sent(message: "share.ai::sentButUntracked".localized())
        } catch {
            return .failed(message: "share.ai::failed".localized())
        }
    }

    // 실패 후 재시도를 허용한다 — 전송 중(.sending)만 막으면 된다
    private var canSend: Bool {
        switch self.subject.stage.value {
        case .editing, .failed: return true
        default: return false
        }
    }

    var isCloseable: Bool {
        return self.subject.stage.value != .sending
    }

    func close() {
        guard self.isCloseable else { return }
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
