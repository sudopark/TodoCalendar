//
//  PlaceSuggestUsecase.swift
//  Domain
//
//  Created by sudo.park on 11/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import CombineSchedulers
import Extensions


// MARK: - PlaceSuggestEngine

public protocol PlaceSuggestEngine: AnyObject {

    func prepare()
    func suggest(query: String) -> AnyPublisher<[Place], any Error>
}


// MARK: - PlaceSuggestUsecase

public protocol PlaceSuggestUsecase: AnyObject, Sendable {
    
    func prepare()
    func starSuggest(_ query: String)
    func stopSuggest()
    
    var suggestPlaces: AnyPublisher<[Place], Never> { get }
}

public final class PlaceSuggestUsecaseImple: PlaceSuggestUsecase, @unchecked Sendable {
    
    private let suggestEngine: any PlaceSuggestEngine
    private let throttleTime: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: AnySchedulerOf<DispatchQueue>
    public init(
        suggestEngine: any PlaceSuggestEngine,
        throttleTime: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(1200),
        scheduler: AnySchedulerOf<DispatchQueue> = .main
    ) {
        self.suggestEngine = suggestEngine
        self.throttleTime = throttleTime
        self.scheduler = scheduler
        self.bindSuggest()
    }
    
    private struct Subject {
        let query = CurrentValueSubject<String?, Never>(nil)
        let places = CurrentValueSubject<[Place], Never>([])
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}

extension PlaceSuggestUsecaseImple {
    
    public func prepare() {
        self.suggestEngine.prepare()
    }
    
    public func starSuggest(_ query: String) {
        self.subject.query.send(query)
    }
    
    public func stopSuggest() {
        self.subject.query.send(nil)
    }
    
    private func bindSuggest() {
        
        let suggestOrNot: (String?) -> AnyPublisher<[Place], Never>? = { [weak self] query in
            guard let self else { return nil }
            guard let query else {
                return Just([]).eraseToAnyPublisher()
            }
            return self.suggestEngine.suggest(query: query)
                .ignoreError()
        }
        
        self.subject.query
            .throttle(for: self.throttleTime, scheduler: self.scheduler, latest: true)
            .compactMap(suggestOrNot)
            .switchToLatest()
            .sink(receiveValue: { [weak self] places in
                self?.subject.places.send(places)
            })
            .store(in: &self.cancellables)
    }
}

extension PlaceSuggestUsecaseImple {
    
    public var suggestPlaces: AnyPublisher<[Place], Never> {
        return self.subject.places
            .eraseToAnyPublisher()
    }
}
