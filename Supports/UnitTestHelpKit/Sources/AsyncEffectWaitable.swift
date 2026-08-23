//
//  AsyncEffectWaitable.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct AsyncEffectWaitTimeout: Error, CustomStringConvertible {
    
    public let timeoutMillis: Int
    public let description: String
    
    init(timeoutMillis: Int, description: String) {
        self.timeoutMillis = timeoutMillis
        self.description = description
    }
}


public protocol AsyncEffectWaitable: AnyObject { }

extension AsyncEffectWaitable {
    
    /// 고정 sleep 대신 조건이 참이 될 때까지 폴링한다. 병렬 실행 부하로 효과가 늦게 도착해도
    /// 기다리는 시간만 늘어날 뿐 판정이 흔들리지 않는다. 끝내 참이 되지 않으면 던져서
    /// 뒤따르는 단언이 엉뚱한 메시지로 실패하는 대신 대기 실패임을 드러낸다.
    public func waitEffect(
        _ description: String,
        timeoutMillis: Int = 3000,
        until condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutMillis) / 1000)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        guard condition() else {
            throw AsyncEffectWaitTimeout(
                timeoutMillis: timeoutMillis,
                description: "\(timeoutMillis)ms 안에 조건이 참이 되지 않았다 — \(description)"
            )
        }
    }
}
