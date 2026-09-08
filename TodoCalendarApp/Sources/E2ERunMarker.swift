//
//  E2ERunMarker.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2026/09/09.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - E2ERunMarker

// 확장 프로세스는 실행 인자도 환경변수도 못 받아 공유 컨테이너의 파일만이 통로다
struct E2ERunMarker {
    
    private enum Constant {
        static let hostKey: String = "host"
        static let expiresAtKey: String = "expiresAt"
    }
    
    let host: String
    let expiresAt: Date
    
    init(host: String, expiresAt: Date) {
        self.host = host
        self.expiresAt = expiresAt
    }
    
    init?(data: Data) {
        guard let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let host = payload[Constant.hostKey] as? String,
              let expiresAt = payload[Constant.expiresAtKey] as? TimeInterval
        else { return nil }
        
        self.host = host
        self.expiresAt = Date(timeIntervalSince1970: expiresAt)
    }
    
    func encoded() throws -> Data {
        return try JSONSerialization.data(withJSONObject: [
            Constant.hostKey: self.host,
            Constant.expiresAtKey: self.expiresAt.timeIntervalSince1970
        ])
    }
    
    func isValid(at now: Date) -> Bool {
        return self.expiresAt > now
    }
}
