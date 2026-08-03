//
//  RemoteDateParser.swift
//  Repository
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// 서버 응답의 ISO8601 날짜 문자열 파싱. 상태가 없는 순수 유틸리티라 static 네임스페이스로 둔다
enum RemoteDateParser {

    // 밀리초는 엔드포인트·필드마다 붙기도 안 붙기도 해서 양쪽을 시도한다.
    // 한쪽만 받으면 서버가 포맷을 바꾸는 순간 날짜가 통째로 nil 이 된다
    static func parse(_ value: Any?) -> Date? {
        guard let iso = value as? String else { return nil }
        return self.date(from: iso, options: [.withInternetDateTime, .withFractionalSeconds])
            ?? self.date(from: iso, options: [.withInternetDateTime])
    }

    private static func date(
        from iso: String,
        options: ISO8601DateFormatter.Options
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter.date(from: iso)
    }
}
