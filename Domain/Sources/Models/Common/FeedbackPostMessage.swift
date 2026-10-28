//
//  FeedbackPostMessage.swift
//  Domain
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public struct FeedbackPostMessage {
    
    public let contactEmail: String
    public let message: String
    
    public init(
        contactEmail: String,
        message: String
    ) {
        self.contactEmail = contactEmail
        self.message = message
    }
}


public struct FeedbackMakeParams {
    
    public var userId: String?
    public let contactEmail: String
    public let message: String
    public var osVersion: String?
    public var appVersion: String?
    public var deviceModel: String?
    public var isIOSAppOnMac: Bool?
    
    public init(_ contact: String, _ message: String) {
        self.contactEmail = contact
        self.message = message
    }
}
