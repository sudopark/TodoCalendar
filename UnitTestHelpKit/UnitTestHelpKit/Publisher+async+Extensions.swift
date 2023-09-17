//
//  Publisher+async+Extensions.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 2023/08/11.
//

import Foundation
import Combine


extension Publisher {
    
    public func values(with timeoutMillis: Int) async throws -> AsyncThrowingPublisher<AnyPublisher<Output, Failure>> {
        
        return self.timeout(.milliseconds(timeoutMillis), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
            .values
    }
    
    public func firstValue(with timeoutMillis: Int) async throws -> Output? {
        return try await self.values(with: timeoutMillis)
            .first(where: { _ in true })
    }
}
