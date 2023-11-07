//
//  StubEventDetailDataUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Combine
import Domain
import Extensions

open class StubEventDetailDataUsecase: EventDetailDataUsecase, @unchecked Sendable {
    
    public init() { } 
    
    public var stubDetail: EventDetailData?
    open func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, any Error> {
        guard let detail = self.stubDetail 
        else {
            return Empty().eraseToAnyPublisher()
        }
        return Just(detail).mapNever().eraseToAnyPublisher()
    }
    
    public var savedDetail: EventDetailData?
    public var shouldFailSaveDetail: Bool = false
    open func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData {
        self.savedDetail = detail
        guard self.shouldFailSaveDetail == false
        else {
            throw RuntimeError("failed")
        }
        return detail
    }
    
    open func removeDetail(_ id: String) async throws {
        
    }
}
