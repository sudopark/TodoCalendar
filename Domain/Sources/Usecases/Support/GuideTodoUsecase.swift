//
//  GuideTodoUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol GuideTodoUsecase: Sendable {

    func prepare()
    func completeGuideTodo()

    var isGuideTodoVisible: AnyPublisher<Bool, Never> { get }
}


public final class GuideTodoUsecaseImple: GuideTodoUsecase, @unchecked Sendable {

    private let repository: any GuideTodoRepository
    private let sharedDataStore: SharedDataStore

    public init(
        repository: any GuideTodoRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
    }

    private var shareKey: String { ShareDataKeys.isGuideTodoCompleted.rawValue }
}


// MARK: - command

extension GuideTodoUsecaseImple {

    public func prepare() {
        self.sharedDataStore.put(
            Bool.self, key: self.shareKey, self.repository.loadIsCompleted()
        )
    }

    public func completeGuideTodo() {
        self.repository.markCompleted()
        self.sharedDataStore.put(Bool.self, key: self.shareKey, true)
    }
}


// MARK: - query

extension GuideTodoUsecaseImple {

    /// `prepare()` 전에는 완료 여부를 모르므로 노출하지 않는다 — 완료한 유저에게 셀이 깜빡이지 않는다.
    public var isGuideTodoVisible: AnyPublisher<Bool, Never> {
        return self.sharedDataStore
            .observe(Bool.self, key: self.shareKey)
            .map { isCompleted in
                return !(isCompleted ?? true)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
