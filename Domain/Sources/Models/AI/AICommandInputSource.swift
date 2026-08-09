//
//  AICommandInputSource.swift
//  Domain
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// interpret 커맨드의 입력 출처. 서버가 이 값으로 해석 지시문을 갈아끼운다.
public enum AICommandInputSource: Sendable, Equatable {
    case text
    case imageOcr
}
