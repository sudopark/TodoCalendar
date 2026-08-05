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

    // 입력 화면이 화면의 바닥이고, 아래 축들이 그 위에 쌓인다. 한 축의 변화가
    // 다른 축을 지우지 않으므로 상태 조합이 늘어도 분기를 새로 만들 필요가 없다.
    private struct Subject {
        let sharedText = CurrentValueSubject<String?, Never>(nil)
        /// 공유 원문·전송 가능 여부를 아직 확인하는 중
        let isPreparing = CurrentValueSubject<Bool, Never>(true)
        /// 미로그인·앞선 요청이라 제출 자체가 불가능하다 — 되돌아갈 곳이 없다
        let blockedMessage = CurrentValueSubject<String?, Never>(nil)
        let isSending = CurrentValueSubject<Bool, Never>(false)
        /// 제출이 끝나 더 할 일이 없다
        let sentMessage = CurrentValueSubject<String?, Never>(nil)
        /// 직전 시도가 실패했다 — 원문을 그대로 두고 재시도할 수 있다
        let failureMessage = CurrentValueSubject<String?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - interactions

extension ShareCommandViewModel {

    func prepare() {
        Task { [weak self] in
            guard let self else { return }
            self.subject.sharedText.send(await self.loadSharedText())
            self.subject.blockedMessage.send(await self.resolveBlockMessage())
            self.subject.isPreparing.send(false)
        }
    }

    private func resolveBlockMessage() async -> String? {
        switch await self.submitService.checkPrecondition() {
        case .ready:
            return nil
        case .needSignIn:
            return "share.ai::needSignIn".localized()
        case .previousRequestPending:
            return "share.ai::pending".localized()
        }
    }

    func send(sharedText: String, additionalInstruction: String) {
        guard self.canSubmit else { return }
        let command = AIShareCommandText(
            sharedText: sharedText,
            additionalInstruction: additionalInstruction
        )
        guard !command.isEmpty else { return }

        self.subject.failureMessage.send(nil)
        self.subject.isSending.send(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.submitService.submit(command)
                self.subject.sentMessage.send("share.ai::sent".localized())
            } catch ShareSubmitFailure.createdButNotTrackable {
                // job은 서버에 만들어졌지만 앱이 이어받을 기록이 없다 — 보냈다고만 하면 거짓말이 된다
                self.subject.sentMessage.send("share.ai::sentButUntracked".localized())
            } catch {
                self.subject.failureMessage.send("share.ai::failed".localized())
            }
            self.subject.isSending.send(false)
        }
    }

    // 실패 후 재시도는 허용하고, 확인 전·차단·완료·전송 중만 막는다
    private var canSubmit: Bool {
        return self.subject.isPreparing.value == false
            && self.subject.blockedMessage.value == nil
            && self.subject.sentMessage.value == nil
            && self.subject.isSending.value == false
    }

    // 전송 중엔 프로세스가 죽으면 in-flight 요청이 사라지므로 닫기를 막는다
    func close() {
        guard self.subject.isSending.value == false else { return }
        self.onClose()
    }
}


// MARK: - outputs

extension ShareCommandViewModel {

    var sharedText: AnyPublisher<String, Never> {
        return self.subject.sharedText.compactMap { $0 }.eraseToAnyPublisher()
    }

    var isPreparing: AnyPublisher<Bool, Never> {
        return self.subject.isPreparing.eraseToAnyPublisher()
    }

    var blockedMessage: AnyPublisher<String?, Never> {
        return self.subject.blockedMessage.eraseToAnyPublisher()
    }

    var isSending: AnyPublisher<Bool, Never> {
        return self.subject.isSending.eraseToAnyPublisher()
    }

    var sentMessage: AnyPublisher<String?, Never> {
        return self.subject.sentMessage.eraseToAnyPublisher()
    }

    var failureMessage: AnyPublisher<String?, Never> {
        return self.subject.failureMessage.eraseToAnyPublisher()
    }
}
