//
//  DDayCandidateRepository.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 동기 API인 이유 — 구현이 App Group UserDefaults 단독이다
/// (`CalendarSettingRepository.loadUserSelectedTImeZone()` 과 같은 계열).
/// 추가·제거가 갱신 후 전체 목록을 돌려주는 이유 — 병합을 저장소 안에 가둔다.
/// 밖에서 읽고 합쳐 통째로 덮어쓰면, 앱과 위젯이 같은 App Group suite를 보는 구조에서
/// 한쪽이 읽은 뒤 다른 쪽이 쓴 변경이 지워진다.
public protocol DDayCandidateRepository: Sendable {

    func loadCandidates() -> [DDayCandidate]
    func append(_ candidate: DDayCandidate) -> [DDayCandidate]
    func remove(_ candidate: DDayCandidate) -> [DDayCandidate]
}
