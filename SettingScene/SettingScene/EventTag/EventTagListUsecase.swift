//
//  EventTagListUsecase.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


protocol EventTagListUsecase: Sendable, AnyObject {
    
    func reload()
    func loadMore()
    
    var eventTags: AnyPublisher<[EventTag], Never> { get }
}


final class EventTagListUsecaseImple: EventTagListUsecase, Sendable {
    
    struct EventTagQuery: PagingQueryType {
        let lastItemCreateTime: TimeInterval?
        var isFirst: Bool = true
        
        func shouldResetResult(compareWith other: EventTagQuery) -> Bool {
            return other.isFirst
        }
    }
    
    struct EventTagPagingResult: PagingResultType {
        
        let query: EventTagQuery
        let tags: [EventTag]
        
        init(_ query: EventTagQuery, _ tags: [EventTag]) {
            self.query = query
            self.tags = tags
        }
        
        var isAllLoaded: Bool = false
        
        func nextQuery() -> EventTagListUsecaseImple.EventTagQuery? {
            guard self.isAllLoaded == false else { return nil }
            return .init(
                lastItemCreateTime: self.tags.last?.createAt,
                isFirst: false
            )
        }
        
        func append(_ next: EventTagPagingResult) -> EventTagPagingResult {
            return .init(
                self.query,
                self.tags + next.tags
            )
            |> \.isAllLoaded .~ next.isAllLoaded
        }
    }
    
    private let pagingUsecase: PagingUsecase<EventTagQuery, EventTagPagingResult>
    
    init(
        option: PagingOption = .init(),
        _ repository: EventTagRepository
    ) {
        
        self.pagingUsecase = .init(option: option) { query in
            
            let size = 30
            let tags = try await repository.loadTags(
                olderThan: query.lastItemCreateTime,
                size: size
            )
            return EventTagPagingResult(query, tags) |> \.isAllLoaded .~ (tags.count < size)
        }
    }
}


extension EventTagListUsecaseImple {
        
    func reload() {
        let query = EventTagQuery(lastItemCreateTime: nil) |> \.isFirst .~ true
        self.pagingUsecase.refresh(query)
    }
    
    func loadMore() {
        self.pagingUsecase.loadMore()
    }
    
    var eventTags: AnyPublisher<[EventTag], Never> {
        return self.pagingUsecase.totalResult
            .map { $0?.tags ?? [] }
            .eraseToAnyPublisher()
    }
}
