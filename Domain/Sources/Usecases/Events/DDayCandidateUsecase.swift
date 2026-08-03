//
//  DDayCandidateUsecase.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol DDayCandidateUsecase: Sendable {

    func refresh()
    func append(_ candidate: DDayCandidate)
    func remove(_ candidate: DDayCandidate)

    var candidates: AnyPublisher<[DDayCandidate], Never> { get }
}


/// 등록·해제는 command, `candidates`는 query — 한 흐름에 섞지 않는다.
public final class DDayCandidateUsecaseImple: DDayCandidateUsecase, @unchecked Sendable {

    private let repository: any DDayCandidateRepository
    private let sharedDataStore: SharedDataStore

    public init(
        repository: any DDayCandidateRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
    }

    private var shareKey: String { ShareDataKeys.ddayCandidates.rawValue }
}


// MARK: - command

extension DDayCandidateUsecaseImple {

    public func refresh() {
        self.put(self.repository.loadCandidates())
    }

    public func append(_ candidate: DDayCandidate) {
        self.put(self.repository.append(candidate))
    }

    public func remove(_ candidate: DDayCandidate) {
        self.put(self.repository.remove(candidate))
    }

    /// 병합은 저장소가 한다 — 여기선 그 결과를 공유 상태에 반영만 한다.
    private func put(_ candidates: [DDayCandidate]) {
        self.sharedDataStore.put([DDayCandidate].self, key: self.shareKey, candidates)
    }
}


// MARK: - query

extension DDayCandidateUsecaseImple {

    public var candidates: AnyPublisher<[DDayCandidate], Never> {
        return self.sharedDataStore
            .observe([DDayCandidate].self, key: self.shareKey)
            .map { $0 ?? [] }
            .eraseToAnyPublisher()
    }
}
