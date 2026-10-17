//
//  StubDDayCandidateUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 9/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubDDayCandidateUsecase: DDayCandidateUsecase, @unchecked Sendable {

    private let subject: CurrentValueSubject<[DDayCandidate], Never>

    public init(_ candidates: [DDayCandidate] = []) {
        self.subject = .init(candidates)
    }

    public private(set) var didRefresh: Bool = false
    open func refresh() {
        self.didRefresh = true
    }

    public private(set) var didAppendCandidate: DDayCandidate?
    open func append(_ candidate: DDayCandidate) {
        self.didAppendCandidate = candidate
        self.subject.send(self.subject.value + [candidate])
    }

    public private(set) var didRemoveCandidate: DDayCandidate?
    open func remove(_ candidate: DDayCandidate) {
        self.didRemoveCandidate = candidate
        self.subject.send(self.subject.value.filter { $0 != candidate })
    }

    open var candidates: AnyPublisher<[DDayCandidate], Never> {
        return self.subject.eraseToAnyPublisher()
    }

    /// 테스트 케이스가 직접 검사하는 raw 기록 — 검증은 케이스 책임(stub은 기록만).
    public var currentCandidates: [DDayCandidate] { self.subject.value }
}
