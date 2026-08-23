//
//  LegalNoticeUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import AsyncFlatMap
import Extensions


// MARK: - LegalNoticeUsecase

public protocol LegalNoticeUsecase: Sendable {
    func checkNoticeIsNeed()
    var pendingNoticeUpdates: AnyPublisher<[LegalNoticeUpdateInfo], Never> { get }
    func confirmNotice(_ documentType: LegalDocumentType)
}


// MARK: - LegalNoticeUsecaseImple

public final class LegalNoticeUsecaseImple: LegalNoticeUsecase, @unchecked Sendable {

    private let legalNoticeRepository: any LegalNoticeRepository

    public init(legalNoticeRepository: any LegalNoticeRepository) {
        self.legalNoticeRepository = legalNoticeRepository
        self.bindCheckTrigger()
    }

    private struct Subject {
        let checkTrigger = PassthroughSubject<Void, Never>()
        let pendingUpdates = CurrentValueSubject<[LegalNoticeUpdateInfo], Never>([])
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


extension LegalNoticeUsecaseImple {

    public func checkNoticeIsNeed() {
        self.subject.checkTrigger.send(())
    }

    private func bindCheckTrigger() {

        self.subject.checkTrigger
            .mapAsAnyError()
            .flatMapLatest { [weak self] in
                return self?.loadUpdatesWithoutError() ?? Empty().eraseToAnyPublisher()
            }
            .map { [weak self] updates -> [LegalNoticeUpdateInfo] in
                guard let self else { return [] }
                return self.unconfirmedUpdates(from: updates)
            }
            .sink(receiveValue: { [weak self] updates in
                self?.subject.pendingUpdates.send(updates)
            })
            .store(in: &self.cancellables)
    }

    private func loadUpdatesWithoutError() -> AnyPublisher<LegalNoticeUpdates, any Error> {
        let repository = self.legalNoticeRepository
        return Publishers.create(do: {
            do {
                return try await repository.loadNoticeUpdates()
            } catch {
                return [:] as LegalNoticeUpdates
            }
        })
        .eraseToAnyPublisher()
    }

    private func unconfirmedUpdates(from updates: LegalNoticeUpdates) -> [LegalNoticeUpdateInfo] {
        return LegalDocumentType.allCases.compactMap { documentType -> LegalNoticeUpdateInfo? in
            guard let info = updates[documentType],
                  info.id != self.legalNoticeRepository.fetchConfirmedNoticeId(documentType)
            else { return nil }
            return info
        }
    }
}

extension LegalNoticeUsecaseImple {

    public var pendingNoticeUpdates: AnyPublisher<[LegalNoticeUpdateInfo], Never> {
        return self.subject.pendingUpdates
            .eraseToAnyPublisher()
    }

    public func confirmNotice(_ documentType: LegalDocumentType) {
        guard let info = self.subject.pendingUpdates.value.first(where: { $0.documentType == documentType })
        else { return }
        self.legalNoticeRepository.updateConfirmedNoticeId(info.id, for: documentType)
        self.subject.pendingUpdates.send(
            self.subject.pendingUpdates.value.filter { $0.documentType != documentType }
        )
    }
}
