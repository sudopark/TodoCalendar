//
//  CancelBag.swift
//  Extensions
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


/// 구독 보관함. `Set<AnyCancellable>` 을 직접 두면 백그라운드 Task 에서 store 하는 순간
/// 메인 스레드 store 와 겹쳐 Set 저장소가 깨진다 — 잠금으로 그 경로 자체를 막는다.
public final class CancelBag: @unchecked Sendable {
    
    private let lock = NSLock()
    private var cancellables: Set<AnyCancellable> = []
    
    public init() { }
    
    public func insert(_ cancellable: AnyCancellable) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.cancellables.insert(cancellable)
    }
    
    public func cancelAll() {
        self.lock.lock()
        let stored = self.cancellables
        self.cancellables.removeAll()
        self.lock.unlock()
        stored.forEach { $0.cancel() }
    }
}


extension AnyCancellable {
    
    public func store(in bag: CancelBag) {
        bag.insert(self)
    }
}
