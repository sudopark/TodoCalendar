//
//  GuideTodoRepository.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 동기 API인 이유 — 구현이 UserDefaults 단독이다
/// (`DDayCandidateRepository`와 같은 계열).
public protocol GuideTodoRepository: Sendable {

    func loadIsCompleted() -> Bool
    func markCompleted()
}
