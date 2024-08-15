//
//  Feedback+Mapping.swift
//  Repository
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

extension FeedbackMakeParams {
    
    func asMessageJson() -> [String: Any] {
        var messagePayload: [String: Any] = [
            "fallback": "incomming cs from: <\(self.contactEmail)>",
            "pretext": "incomming cs from: <\(self.contactEmail)>",
            "color": "good"
        ]
        let feedbackMessagePayload: [String: Any] = [
            "title": "Message",
            "value": "\(self.message)",
            "short": false
        ]
        
        let fields = [feedbackMessagePayload]
            .appendInfoPayloadsIfExists("user id", self.userId ?? "null")
            .appendInfoPayloadsIfExists("os version", self.osVersion)
            .appendInfoPayloadsIfExists("app version", self.appVersion)
            .appendInfoPayloadsIfExists("device model", self.deviceModel)
            .appendInfoPayloadsIfExists("is ios app on Mac?", self.isIOSAppOnMac.map { "\($0)"})
        messagePayload["fields"] = fields
        
        return [
            "attachments": [messagePayload]
        ]
    }
}

private extension Array where Element == [String: Any] {
    
    func appendInfoPayloadsIfExists(_ key: String, _ value: String?) -> Array {
        guard let value = value else { return self }
        let new: [String: Any] = ["title": key, "value": value, "short": true]
        return self + [new]
    }
}
