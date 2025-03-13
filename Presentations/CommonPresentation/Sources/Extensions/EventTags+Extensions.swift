//
//  EventTags+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/2/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


extension Array where Element == any EventTag {
    
    public func sortDefaultTagsAtFirst(
        
    ) -> Array {
        let defaults = self.compactMap { $0 as? DefaultEventTag }
        let customs = self.filter { !($0 is DefaultEventTag)  }
        return defaults.sorted(by: { $0.sortPriority < $1.sortPriority }) + customs
    }
}

private extension DefaultEventTag {
    
    var sortPriority: Int {
        switch self {
        case .default: return 0
        case .holiday: return 1
        }
    }
}
