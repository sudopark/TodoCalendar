//
//  ScheduleEventUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - ScheduleEventUsecase

public protocol ScheduleEventUsecase {
    
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent
    func refreshScheduleEvents(in period: Range<TimeStamp>)
    func scheduleEvents(in period: Range<TimeStamp>) -> AnyPublisher<[ScheduleEvent], Never>
}


// MARK: - ScheduleEventUsecaseImple

public final class ScheduleEventUsecaseImple: ScheduleEventUsecase {
    
    private let scheduleRepository: ScheduleEventRepository
    private let sharedDataStore: SharedDataStore
    
    public init(
        scheduleRepository: ScheduleEventRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.scheduleRepository = scheduleRepository
        self.sharedDataStore = sharedDataStore
    }
    
    private var cancellables: Set<AnyCancellable> = []
}


extension ScheduleEventUsecaseImple {
    
    public func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent {
        guard params.isValidForMaking
        else {
            throw RuntimeError("invalid parameter for make Schedule Event")
        }
        let newEvent = try await self.scheduleRepository.makeScheduleEvent(params)
        let shareKey = ShareDataKeys.schedules.rawValue
        self.sharedDataStore.update(MemorizedScheduleEventsContainer.self, key: shareKey) {
            ( $0 ?? .init() ).append(newEvent)
        }
        return newEvent
    }
    
    public func refreshScheduleEvents(in period: Range<TimeStamp>) {

        let updateCache: ([ScheduleEvent]) -> Void = { [weak self] events in
            guard let self = self else { return }
            let key = ShareDataKeys.schedules
            self.sharedDataStore.update(MemorizedScheduleEventsContainer.self, key: key.rawValue) {
                return ($0 ?? .init()).refresh(events, in: period)
            }
        }

        self.scheduleRepository.loadScheduleEvents(in: period)
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(receiveCompletion: { _ in }, receiveValue: updateCache)
            .store(in: &self.cancellables)
    }
    
    public func scheduleEvents(in period: Range<TimeStamp>)  -> AnyPublisher<[ScheduleEvent], Never> {
        let key = ShareDataKeys.schedules
        return self.sharedDataStore
            .observe(MemorizedScheduleEventsContainer.self, key: key.rawValue)
            .map { $0?.scheduleEvents(in: period) ?? [] }
            .eraseToAnyPublisher()
    }
}
