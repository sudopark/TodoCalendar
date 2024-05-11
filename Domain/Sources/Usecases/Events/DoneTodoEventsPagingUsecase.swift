//
//  DoneTodoEventsPagingUsecase.swift
//  Domain
//
//  Created by sudo.park on 5/9/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - DoneTodoEventsPagingUsecase

public protocol DoneTodoEventsPagingUsecase: Sendable {
    
    func reload()
    func loadMore()
    
    var events: AnyPublisher<[DoneTodoEvent]?, Never> { get }
    var loadFailed: AnyPublisher<any Error, Never> { get }
}


// MARK: - request parameter and page

extension DoneTodoLoadPagingParams: PagingQueryType {
    
    public var isFirst: Bool { self.cursorAfter == nil }
    public func shouldResetResult(compareWith other: DoneTodoLoadPagingParams) -> Bool {
        return other.isFirst
    }
}

private struct DoneTodoEventsPage: PagingResultType {
    typealias Query = DoneTodoLoadPagingParams
    
    let query: DoneTodoLoadPagingParams
    let events: [DoneTodoEvent]
    let isLastPage: Bool
    
    func nextQuery() -> DoneTodoLoadPagingParams? {
        guard !isLastPage,
              let last = self.events.last?.doneTime.timeIntervalSince1970
        else { return nil }
        return .init(
            cursorAfter: last,
            size: self.query.size
        )
    }
    
    func append(_ next: DoneTodoEventsPage) -> DoneTodoEventsPage {
        let newTotal = (self.events + next.events)
            .asDictionary { $0.uuid }
            .values
            .sorted(by: { $0.doneTime > $1.doneTime })
        return .init(query: self.query, events: newTotal, isLastPage: next.isLastPage)
    }
}


public final class DoneTodoEventsPagingUsecaseImple: DoneTodoEventsPagingUsecase, @unchecked Sendable {
    
    private let pageSize: Int
    private let internalUsecase: PagingUsecase<DoneTodoLoadPagingParams, DoneTodoEventsPage>
    
    public init(
        pageSize: Int,
        todoRepository: any TodoEventRepository
    ) {
        
        self.pageSize = pageSize
        self.internalUsecase = .init { query in
            return Publishers.create {
                let events = try await todoRepository.loadDoneTodoEvents(query)
                return DoneTodoEventsPage(query: query, events: events, isLastPage: events.count < pageSize)
            }
            .eraseToAnyPublisher()
        }
    }
}

extension DoneTodoEventsPagingUsecaseImple {
    
    public func reload() {
        self.internalUsecase.refresh(.init(cursorAfter: nil, size: self.pageSize))
    }
    
    public func loadMore() {
        self.internalUsecase.loadMore()
    }
}

extension DoneTodoEventsPagingUsecaseImple {
    
    public var events: AnyPublisher<[DoneTodoEvent]?, Never> {
        return self.internalUsecase.totalResult
            .map { $0?.events }
            .eraseToAnyPublisher()
    }
    
    public var loadFailed: AnyPublisher<any Error, Never> {
        return self.internalUsecase.occurredError
    }
}
