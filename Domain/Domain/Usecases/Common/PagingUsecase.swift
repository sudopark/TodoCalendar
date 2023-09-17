//
//  PagingUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/01.
//

import Foundation
import Combine
import AsyncFlatMap


public protocol PagingQueryType: Sendable {
    
    var isFirst: Bool { get }
    
    func isSameQuery(with other: Self) -> Bool
}

public protocol PagingResultType: Sendable {
    
    associatedtype Query = PagingQueryType
    
    var query: Query { get }
    
    func nextQuery() -> Query?
    func append(_ next: Self) -> Self
}


public struct PagingOption {
    public var loadThrottleIntervalMillis: Int = 500
    public init() {}
}

public final class PagingUsecase<QueryType: PagingQueryType, ResultType: PagingResultType>: @unchecked Sendable where ResultType.Query == QueryType {
    
    public typealias Loading = @Sendable (QueryType) async throws -> ResultType
    private let option: PagingOption
    
    public init(option: PagingOption = .init(), _ loading: @escaping Loading) {
        self.option = option
        self.internalBinding(loading)
    }
    
    private enum LoadingStatus {
        case refreshing
        case loadingMore
    }
    
    private struct Subject {
        let query = CurrentValueSubject<QueryType?, Never>(nil)
        let pagingResult = CurrentValueSubject<ResultType?, Never>(nil)
        let loadingStatus = CurrentValueSubject<LoadingStatus?, Never>(nil)
        let occurredError = PassthroughSubject<Error, Never>()
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    
    private func internalBinding(_ loading: @escaping Loading) {
        
        let updateIsLoading: (QueryType) -> Void = { [weak self] query in
            self?.subject.loadingStatus.send(query.isFirst ? .refreshing : .loadingMore)
        }
        
        let loadWithoutError: (QueryType) -> AnyPublisher<ResultType, Never> = { query in
            return Publishers.create(do: { [weak self] in
                do {
                    return try await loading(query)
                } catch {
                    self?.subject.loadingStatus.send(nil)
                    self?.subject.occurredError.send(error)
                    return nil
                }
            })
            .eraseToAnyPublisher()
        }
        
        let updatePagingResult: (ResultType) -> Void = { [weak self] result in
            self?.subject.loadingStatus.send(nil)
            self?.subject.pagingResult.send(result)
        }
        
        self.subject.query
            .compactMap { $0 }
            .throttle(
                for: .milliseconds(self.option.loadThrottleIntervalMillis),
                scheduler: RunLoop.main,
                latest: true
            )
            .handleEvents(receiveOutput: updateIsLoading)
            .map(loadWithoutError)
            .switchToLatest()
            .sink(receiveValue: updatePagingResult)
            .store(in: &self.cancellables)
    }
}


extension PagingUsecase {
    
    func refresh(_ query: QueryType) {
        self.subject.query.send(query)
    }
    
    func loadMore() {
        guard let currentPage = self.subject.pagingResult.value,
              let nextQuery = currentPage.nextQuery()
        else { return }
        self.subject.query.send(nextQuery)
    }
}

extension PagingUsecase {
    
    var isRefreshing: AnyPublisher<Bool, Never> {
        let transform: (LoadingStatus?) -> Bool = { status in
            guard status == .refreshing else { return false }
            return true
        }
        return self.subject.loadingStatus
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isLoadingMore: AnyPublisher<Bool, Never> {
        let transform: (LoadingStatus?) -> Bool = { status in
            guard status == .loadingMore else { return false }
            return true
        }
        return self.subject.loadingStatus
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var occurredError: AnyPublisher<Error, Never> {
        return self.subject.occurredError
            .eraseToAnyPublisher()
    }
    
    var totalResult: AnyPublisher<ResultType?, Never> {
        
        let accumulatePagingIfNeed: (ResultType?, ResultType?) -> ResultType? = { accumulated, newPage in
            
            switch (accumulated, newPage) {
            case (.none, .none), (_, .none): return .none
            case let (.none, .some(new)): return new
            case let (.some(previous), .some(new)):
                guard previous.query.isSameQuery(with: new.query)
                else {
                    return new
                }
                return previous.append(new)
            }
        }
        
        return self.subject.pagingResult
            .scan(nil, accumulatePagingIfNeed)
            .eraseToAnyPublisher()
    }
}
