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
        return try await self.scheduleRepository.makeScheduleEvent(params)
    }
    
    public func refreshScheduleEvents(in period: Range<TimeStamp>) {
        // range에 매칭되는 이벤트들 조회해와야함
        // 그리고 조회 범위들 내에서 이벤트들의 반복타임 갱신해줘야함 => 퍼포먼스 적으로 이슈 있을 수 있음
            // 멤캐시된것들 -> 미리 계산된결과 활용필수적으로 해야함
    }
    
    public func scheduleEvents(in period: Range<TimeStamp>)  -> AnyPublisher<[ScheduleEvent], Never> {
        return Empty().eraseToAnyPublisher()
    }
}
