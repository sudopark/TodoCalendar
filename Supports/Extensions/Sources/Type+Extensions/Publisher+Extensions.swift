//
//  Publisher+extension.swift
//  Extensions
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Combine


extension Publisher {
    
    public func mapAsAnyError() -> Publishers.MapError<Self, any Error> {
        return self.mapError { error -> any Error in
            return error
        }
    }
    
    public func sink(
        receiveValue: @escaping (Output) -> Void,
        receiveError: ((Failure) -> Void)? = nil
    ) -> AnyCancellable {
        
        return self.sink(receiveCompletion: { completion in
            guard case let .failure(error) = completion else { return }
            receiveError?(error)
        }, receiveValue: receiveValue)
    }
    
    public func ignoreError() -> AnyPublisher<Output, Never> {
        return self.map { output -> Output? in
            return Optional<Output>.some(output)
        }
        .catch { _ in Just(nil) }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    public func mapAsOptional() -> AnyPublisher<Output?, Failure> {
        return self.map { o -> Output? in o }
            .eraseToAnyPublisher()
    }
}

extension Publisher where Failure == Never {
    
    public func mapNever() -> Publishers.MapError<Self, any Error> {
        return self.mapError { _ -> (any Error) in }
    }
    
    public func receiveOnIfPossible<S: Scheduler>(
        _ scheduler: S?
    ) -> AnyPublisher<Output, Failure> {
        guard let scheduler else { return self.eraseToAnyPublisher() }
        return self.receive(on: scheduler)
            .eraseToAnyPublisher()
    }
}
