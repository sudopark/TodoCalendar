//
//  Result+extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Combine

extension Result {
    
    public func eraseToAnyPublisher() -> AnyPublisher<Success, Failure> {
        switch self {
        case .success(let success):
            return Just(success).mapError { _ -> Failure in }.eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}
