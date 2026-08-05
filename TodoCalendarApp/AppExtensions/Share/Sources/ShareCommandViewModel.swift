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
}


extension ShareCommandStage {

    // 전송 가능한 단계 — 실패 후 재시도는 허용하고 전송 중만 막는다
    var canSend: Bool {
        switch self {
        case .editing, .failed: return true
        default: return false
        }
    }
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
        guard self.subject.stage.value.canSend else { return }
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
                self.subject.stage.send(.sent(message: "share.ai::sent".localized()))
            } catch ShareSubmitFailure.createdButNotTrackable {
                // job은 서버에 만들어졌지만 앱이 이어받을 기록이 없다 — 보냈다고만 하면 거짓말이 된다
                self.subject.stage.send(.sent(message: "share.ai::sentButUntracked".localized()))
            } catch {
                self.subject.stage.send(.failed(message: "share.ai::failed".localized()))
            }
        }
    }

    // 전송 중엔 프로세스가 죽으면 in-flight 요청이 사라지므로 닫기를 막는다
    func close() {
        guard self.subject.stage.value != .sending else { return }
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
