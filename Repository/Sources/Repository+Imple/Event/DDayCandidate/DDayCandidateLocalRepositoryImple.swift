//
//  DDayCandidateLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class DDayCandidateLocalRepositoryImple: DDayCandidateRepository {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private enum Constant {
        static let key: String = "dday_candidates"
    }
}

extension DDayCandidateLocalRepositoryImple {

    public func loadCandidates() -> [DDayCandidate] {
        let mappers: [DDayCandidateMapper]? = self.environmentStorage.load(Constant.key)
        return mappers?.map { $0.candidate } ?? []
    }

    public func append(_ candidate: DDayCandidate) -> [DDayCandidate] {
        let current = self.loadCandidates()
        guard !current.contains(candidate) else { return current }
        return self.save(current + [candidate])
    }

    public func remove(_ candidate: DDayCandidate) -> [DDayCandidate] {
        return self.save(self.loadCandidates().filter { $0 != candidate })
    }

    /// 빈 목록이면 키를 지운다 — 빈 배열을 남겨두면 "없음"을 두 형태로 표현하게 된다.
    private func save(_ candidates: [DDayCandidate]) -> [DDayCandidate] {
        guard !candidates.isEmpty
        else {
            self.environmentStorage.remove(Constant.key)
            return []
        }
        self.environmentStorage.update(
            Constant.key, candidates.map { DDayCandidateMapper(candidate: $0) }
        )
        return candidates
    }
}
