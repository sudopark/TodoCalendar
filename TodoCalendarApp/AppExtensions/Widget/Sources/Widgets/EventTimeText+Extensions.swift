//
//  EventTimeText+Extensions.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/13/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import SwiftUI
import CalendarScenes

extension EventTimeText {
    
    func singleLineAttrText(fontSize: CGFloat = 12) -> AttributedString {
        var attrText = AttributedString(self.text)
        attrText.font = .systemFont(ofSize: fontSize)
        
        guard let pmOram = self.pmOram else { return attrText }
        
        var text = AttributedString()
        var prefix = AttributedString("\(pmOram) ")
        prefix.font = .systemFont(ofSize: fontSize-2)
        text.append(prefix)
        text.append(attrText)
        return text
    }
}
