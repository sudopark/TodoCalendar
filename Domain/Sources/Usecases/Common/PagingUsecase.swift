//
//  PagingUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/01.
//

import Foundation
import Combine
import AsyncFlatMap


public protocol PagingQueryType {
    
    var isFirst: Bool { get }
    
    func shouldResetResult(compareWith other: Self) -> Bool
}

public protocol PagingResultType {
    
    associatedtype Query = PagingQueryType
    
    var query: Query { get }
    
    func nextQuery() -> Query?
    func append(_ next: Self) -> Self
}

public protocol PagingRepository: AnyObject, Sendable {
    associatedtype QueryType: PagingQueryType
    associatedtype ResultType: PagingResultType where ResultType.Query == QueryType
    
    func loading(_ query: QueryType) -> AnyPublisher<ResultType, any Error>
}

public final class PagingUsecase<Repository: PagingRepository> {
    
    private let repository: Repository
    private typealias QueryType = Repository.QueryType
    private typealias ResultType = Repository.ResultType
    
    public init(_ repository: Repository) {
        self.repository = repository
        self.internalBinding()
    }
    
    private enum LoadingStatus {
        case refreshing
        case loadingMore
    }
    
    private struct Subject {
        let query = CurrentValueSubject<QueryType?, Never>(nil)
        let pagingResult = CurrentValueSubject<ResultType?, Never>(nil)
        let loadingStatus = CurrentValueSubject<LoadingStatus?, Never>(nil)
        let occurredError = PassthroughSubject<any Error, Never>()
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    
    private func internalBinding() {
        
        let updateIsLoading: (QueryType) -> Void = { [weak self] query in
            self?.subject.loadingStatus.send(query.isFirst ? .refreshing : .loadingMore)
        }
        
        let loadWithoutError: (QueryType) -> AnyPublisher<ResultType, Never> = { [weak self] query in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.repository.loading(query)
                .catch { [weak self] error -> Empty<ResultType, Never> in
                    self?.subject.loadingStatus.send(nil)
                    self?.subject.occurredError.send(error)
                    return Empty()
                }
                .eraseToAnyPublisher()
        }
        
        let updatePagingResult: (ResultType) -> Void = { [weak self] result in
            self?.subject.loadingStatus.send(nil)
            self?.subject.pagingResult.send(result)
        }
        
        self.subject.query
            .compactMap { $0 }
            .handleEvents(receiveOutput: updateIsLoading)
            .map(loadWithoutError)
            .switchToLatest()
            .sink(receiveValue: updatePagingResult)
            .store(in: &self.cancellables)
    }
}


extension PagingUsecase {
    
    public func refresh(_ query: Repository.QueryType) {
        self.subject.query.send(query)
    }
    
    public func loadMore() {
        guard let currentPage = self.subject.pagingResult.value,
              let nextQuery = currentPage.nextQuery()
        else { return }
        self.subject.query.send(nextQuery)
    }
}

extension PagingUsecase {
    
    public var isRefreshing: AnyPublisher<Bool, Never> {
        let transform: (LoadingStatus?) -> Bool = { status in
            guard status == .refreshing else { return false }
            return true
        }
        return self.subject.loadingStatus
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public var isLoadingMore: AnyPublisher<Bool, Never> {
        let transform: (LoadingStatus?) -> Bool = { status in
            guard status == .loadingMore else { return false }
            return true
        }
        return self.subject.loadingStatus
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public var occurredError: AnyPublisher<any Error, Never> {
        return self.subject.occurredError
            .eraseToAnyPublisher()
    }
    
    public var totalResult: AnyPublisher<Repository.ResultType?, Never> {
        
        let accumulatePagingIfNeed: (ResultType?, ResultType?) -> ResultType? = { accumulated, newPage in
            
            switch (accumulated, newPage) {
            case (.none, .none), (_, .none): return .none
            case let (.none, .some(new)): return new
            case let (.some(previous), .some(new)) where previous.query.shouldResetResult(compareWith: new.query):
                return new
            case let (.some(previous), .some(new)):
                return previous.append(new)
            }
        }
        
        return self.subject.pagingResult
            .scan(nil, accumulatePagingIfNeed)
            .eraseToAnyPublisher()
    }
}
